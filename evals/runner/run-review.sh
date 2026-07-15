#!/usr/bin/env bash
set -euo pipefail

# Lance le skill configure sur un cas et conserve toutes les sorties brutes.
# Le script privilegie la surface JSONL du CLI quand elle existe, puis documente
# explicitement les degradations dans meta.json.

case_id="${1:-}"
if [[ -z "$case_id" ]]; then
  echo "usage: runner/run-review.sh <case-id>" >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"

skill_name="${SKILL_NAME:-code-review-back}"
skill_root="${SKILL_ROOT:-skills}"
skill_dir="${SKILL_DIR:-skills/$skill_name}"
input_file="${INPUT_FILE:-input.diff}"
cases_dir="${CASES_DIR:-evals/cases}"
results_dir="${RESULTS_DIR:-evals/results}"
review_instructions="${REVIEW_INSTRUCTIONS:-Analyse uniquement l'entree ci-dessous. N'ecris aucun fichier. Ne lance aucune commande shell.}"

case_dir="$root/$cases_dir/$case_id"
out_dir="$root/$results_dir/$case_id"
input_path="$case_dir/$input_file"

if [[ ! -f "$input_path" ]]; then
  echo "entree introuvable: $input_path" >&2
  exit 2
fi

mkdir -p "$out_dir" "$root/$results_dir/logs"

copilot --help > "$root/$results_dir/copilot-help.txt" 2>&1 || true
# Important: avec ce CLI, `copilot -p --help` est interprete comme un prompt.
printf '%s\n' 'OBSERVED: copilot -p --help is parsed as a prompt, not as help. See copilot --help for -p options.' > "$root/$results_dir/copilot-p-help.txt"
copilot skill list --json > "$root/$results_dir/skill-list.before.json" 2>&1 || true
copilot skill list --json > "$root/$results_dir/skill-list.after.json" 2>&1 || true

prompt_file="$out_dir/review.prompt.txt"
cat > "$prompt_file" <<PROMPT
Utilise le skill $skill_name.

Preuve attendue: active explicitement le skill $skill_name si le CLI le propose, lis ses instructions depuis $skill_dir/SKILL.md, puis respecte son chargement selectif.

$review_instructions

ENTREE:
\`\`\`text
$(cat "$input_path")
\`\`\`
PROMPT

cmd_desc="copilot -p @prompt --output-format json --silent --no-custom-instructions --no-remote --disable-builtin-mcps --log-dir $results_dir/logs"

set +e
copilot \
  -C "$root" \
  -p "$(cat "$prompt_file")" \
  --output-format json \
  --silent \
  --no-custom-instructions \
  --no-remote \
  --disable-builtin-mcps \
  --log-dir "$root/$results_dir/logs" \
  > "$out_dir/trace.raw" 2> "$out_dir/stderr.raw"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  cp "$out_dir/stderr.raw" "$out_dir/review.txt"
  surface="stdout_json_failed"
  note="copilot a retourne $status; review.txt contient stderr"
else
  surface="stdout_json"
  note="sortie capturee avec --output-format json"
  ruby -rjson -e '
    final = nil
    STDIN.each_line do |line|
      begin
        obj = JSON.parse(line)
      rescue JSON::ParserError
        next
      end
      if obj["type"] == "assistant.message"
        content = obj.dig("data", "content")
        final = content if content.is_a?(String) && !content.empty?
      end
    end
    puts(final || File.read(ARGV[0]))
  ' "$out_dir/trace.raw" < "$out_dir/trace.raw" > "$out_dir/review.txt"
fi

ruby -rjson -e '
  meta = {
    case_id: ARGV[0],
    command: ARGV[1],
    exit_status: ARGV[2].to_i,
    capture_surface: ARGV[3],
    note: ARGV[4],
    skill_name: ARGV[5],
    skill_root: ARGV[6],
    skill_dir: ARGV[7],
    input_file: ARGV[8],
    help_files: [File.join(ARGV[9], "copilot-help.txt"), File.join(ARGV[9], "copilot-p-help.txt")],
    skill_registration_log: File.join(ARGV[9], "skill-add.log")
  }
  puts JSON.pretty_generate(meta)
' "$case_id" "$cmd_desc" "$status" "$surface" "$note" "$skill_name" "$skill_root" "$skill_dir" "$input_file" "$results_dir" > "$out_dir/meta.json"

exit 0
