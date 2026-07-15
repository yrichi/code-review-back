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

prompt_file="$out_dir/judge.prompt.txt"
cat > "$prompt_file" <<PROMPT
$(cat "$root/$judge_prompt_path")

CASE_ID:
$case_id

EXPECTED_YML:
\`\`\`yaml
$(cat "$case_dir/expected.yml")
\`\`\`

REVIEW:
\`\`\`text
$(cat "$out_dir/review.txt")
\`\`\`
PROMPT

run_judge() {
  local prompt="$1"
  copilot \
    -C "$root" \
    -p "$prompt" \
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

ruby -rjson -e '
  puts JSON.pretty_generate({
    case_id: ARGV[0],
    result: "FAIL",
    matched: [],
    missed: ["judge-json-invalid"],
    forbidden_violated: [],
    reasons: "Le juge n a pas produit de JSON parsable apres une tentative de reparation."
  })
' "$case_id" > "$out_dir/verdict.json"
