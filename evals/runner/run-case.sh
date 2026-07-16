#!/usr/bin/env bash
set -euo pipefail

# Joue un cas RUNS fois et consigne le resultat de chaque iteration.
#
# Par defaut RUNS=1: le comportement et les artefacts sont identiques a un run
# simple. Au-dela, le modele etant stochastique, un PASS/FAIL unique ne dit pas
# si un cas passe toujours ou une fois sur trois. runs.jsonl porte une ligne par
# iteration, et le gate en tire un ratio.
#
# Les artefacts du repertoire du cas (review.txt, trace.raw, metrics.json...)
# restent ceux de la DERNIERE iteration: ils servent au diagnostic, pas au
# comptage.

case_id="${1:-}"
if [[ -z "$case_id" ]]; then
  echo "usage: evals/runner/run-case.sh <case-id>" >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"
runner_dir="$(cd "$(dirname "$0")" && pwd)"
results_dir="${RESULTS_DIR:-evals/results}"
runs="${RUNS:-1}"

if ! [[ "$runs" =~ ^[0-9]+$ ]] || [[ "$runs" -lt 1 ]]; then
  echo "RUNS doit etre un entier >= 1 (recu: $runs)" >&2
  exit 2
fi

out_dir="$root/$results_dir/$case_id"
mkdir -p "$out_dir"
runs_path="$out_dir/runs.jsonl"
: > "$runs_path"

for i in $(seq 1 "$runs"); do
  [[ "$runs" -gt 1 ]] && echo "  $case_id: iteration $i/$runs"
  "$runner_dir/run-review.sh" "$case_id"
  "$runner_dir/extract-trace.sh" "$case_id"
  "$runner_dir/validate-review.sh" "$case_id"
  "$runner_dir/run-judge.sh" "$case_id"

  ruby -rjson -e '
    dir = ARGV[0]
    read = lambda do |name|
      path = File.join(dir, name)
      return nil unless File.exist?(path)
      begin
        JSON.parse(File.read(path))
      rescue JSON::ParserError
        nil
      end
    end
    line = {
      "iter" => ARGV[1].to_i,
      "verdict" => read.call("verdict.json"),
      "review_check" => read.call("review-check.json"),
      "metrics" => read.call("metrics.json")
    }
    File.open(ARGV[2], "a") { |f| f.puts(JSON.generate(line)) }
  ' "$out_dir" "$i" "$runs_path"
done
