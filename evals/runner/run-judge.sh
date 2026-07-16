#!/usr/bin/env bash
set -euo pipefail

# Appelle un juge LLM en non-interactif et exige un JSON parsable.
# Une seule tentative de reparation est autorisee si la premiere sortie est invalide.

case_id="${1:-}"
if [[ -z "$case_id" ]]; then
  echo "usage: runner/run-judge.sh <case-id>" >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"

cases_dir="${CASES_DIR:-evals/cases}"
results_dir="${RESULTS_DIR:-evals/results}"
judge_prompt_path="${JUDGE_PROMPT:-evals/judge.prompt.md}"
case_dir="$root/$cases_dir/$case_id"
out_dir="$root/$results_dir/$case_id"
mkdir -p "$out_dir"

# Le juge ne peut pas distinguer une Detection d'une Exclusion sans le texte de
# la regle. On lui fournit les references que le cas declare attendre.
rules_block="$(ruby -ryaml -e '
  expected = YAML.load_file(ARGV[0])
  ctx = expected["context_expectations"] || {}
  files = ctx["exact_files_read"] || ctx["allowed_files_read"] || []
  files.each do |rel|
    path = File.join(ARGV[1], rel)
    next unless File.file?(path)
    puts "--- #{rel} ---"
    puts File.read(path)
    puts
  end
' "$case_dir/expected.yml" "$root")"

if [[ -z "${rules_block//[[:space:]]/}" ]]; then
  rules_block="(aucune regle declaree dans context_expectations pour ce cas)"
fi

prompt_file="$out_dir/judge.prompt.txt"
cat > "$prompt_file" <<PROMPT
$(cat "$root/$judge_prompt_path")

CASE_ID:
$case_id

EXPECTED_YML:
\`\`\`yaml
$(cat "$case_dir/expected.yml")
\`\`\`

REGLES:
\`\`\`md
$rules_block
\`\`\`

REVIEW:
\`\`\`text
$(cat "$out_dir/review.txt")
\`\`\`
PROMPT

# Le juge est epingle par le meme MODEL que la review: un juge qui change de
# modele rend ses verdicts incomparables dun run a lautre.
judge_model_args=()
[[ -n "${MODEL:-}" ]] && judge_model_args=(--model "$MODEL")

run_judge() {
  local prompt="$1"
  copilot \
    -C "$root" \
    -p "$prompt" \
    "${judge_model_args[@]}" \
    --output-format json \
    --silent \
    --no-custom-instructions \
    --no-remote \
    --disable-builtin-mcps \
    --log-dir "$root/$results_dir/logs"
}

set +e
raw="$(run_judge "$(cat "$prompt_file")" 2> "$out_dir/judge.stderr.raw")"
status=$?
set -e
printf '%s\n' "$raw" > "$out_dir/judge.trace.raw"

extract_json='
  require "json"
  text = STDIN.read
  candidates = []
  text.each_line do |line|
    begin
      obj = JSON.parse(line)
      if obj["type"] == "assistant.message"
        content = obj.dig("data", "content")
        candidates << content if content.is_a?(String) && !content.empty?
      end
    rescue JSON::ParserError
      candidates << line
    end
  end
  candidates << text
  candidates.reverse_each do |candidate|
    s = candidate.to_s.strip
    s = s.sub(/\A```(?:json)?\s*/m, "").sub(/\s*```\z/m, "").strip
    starts = s.index("{")
    finishes = s.rindex("}")
    if starts && finishes && finishes >= starts
      begin
        parsed = JSON.parse(s[starts..finishes])
        required = %w[case_id result reasons]
        next unless required.all? { |k| parsed.key?(k) }
        next unless %w[PASS FAIL].include?(parsed["result"])
        puts JSON.pretty_generate(parsed)
        exit 0
      rescue JSON::ParserError
      end
    end
  end
  exit 1
'

if [[ $status -eq 0 ]] && printf '%s\n' "$raw" | ruby -e "$extract_json" > "$out_dir/verdict.json"; then
  exit 0
fi

repair_prompt="$(
  cat <<PROMPT
La sortie precedente etait invalide: pas un JSON valide conforme au schema.
Erreur: parsing impossible ou champs requis absents.

Retourne uniquement le JSON corrige, sans texte autour.

SORTIE_PRECEDENTE:
\`\`\`text
$raw
\`\`\`

$(cat "$prompt_file")
PROMPT
)"

set +e
raw2="$(run_judge "$repair_prompt" 2>> "$out_dir/judge.stderr.raw")"
status2=$?
set -e
printf '%s\n' "$raw2" >> "$out_dir/judge.trace.raw"

if [[ $status2 -eq 0 ]] && printf '%s\n' "$raw2" | ruby -e "$extract_json" > "$out_dir/verdict.json"; then
  exit 0
fi

# Distinguer "le juge a juge et rejette" de "le juge n a pas pu tourner". Une
# panne dinfrastructure remonte en ERROR: la confondre avec un FAIL ferait passer
# une panne pour une regression du skill.
ruby -rjson -e '
  trace = ARGV[1]
  run_error = nil
  if File.exist?(trace)
    File.readlines(trace).each do |line|
      begin
        event = JSON.parse(line)
      rescue JSON::ParserError
        next
      end
      next unless %w[session.error model.call_failure].include?(event["type"])
      run_error = {
        "code" => event.dig("data", "errorCode") || event.dig("data", "errorType") || "model_call_failure",
        "status" => event.dig("data", "statusCode"),
        "message" => (event.dig("data", "message") || event.dig("data", "errorMessage")).to_s[0, 200]
      }
      break
    end
  end
  if run_error
    puts JSON.pretty_generate({
      case_id: ARGV[0],
      result: "ERROR",
      matched: [],
      missed: [],
      run_error: run_error,
      reasons: "Le juge n a pas pu tourner: #{run_error["code"]} (HTTP #{run_error["status"]}). #{run_error["message"]}"
    })
  else
    puts JSON.pretty_generate({
      case_id: ARGV[0],
      result: "FAIL",
      matched: [],
      missed: ["judge-json-invalid"],
      reasons: "Le juge n a pas produit de JSON parsable apres une tentative de reparation."
    })
  end
' "$case_id" "$out_dir/judge.trace.raw" > "$out_dir/verdict.json"
