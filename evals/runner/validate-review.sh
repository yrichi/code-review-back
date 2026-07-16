#!/usr/bin/env bash
set -euo pipefail

# Validation deterministe minimale de review.txt.
# Les invariants mecaniques (rule_id, fichier, fragments, max_findings) sont
# tranches ici, sans dependre du juge LLM.

case_id="${1:-}"
if [[ -z "$case_id" ]]; then
  echo "usage: evals/runner/validate-review.sh <case-id>" >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"

cases_dir="${CASES_DIR:-evals/cases}"
results_dir="${RESULTS_DIR:-evals/results}"
expected_path="$root/$cases_dir/$case_id/expected.yml"
review_path="$root/$results_dir/$case_id/review.txt"
out_path="$root/$results_dir/$case_id/review-check.json"

ruby -rjson -ryaml -e '
  expected = YAML.load_file(ARGV[0])
  review = File.exist?(ARGV[1]) ? File.read(ARGV[1]) : ""
  finding_lines = review.lines.select { |l| l.strip.start_with?("- [") }
  finding_text = finding_lines.join
  # Le modele ecrit "acces" ou "acces" accentue selon son humeur: un fragment ne
  # doit pas dependre dun diacritique. On compare sans accents des deux cotes.
  deaccent = lambda { |s| s.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase }
  normalized_findings = deaccent.call(finding_text)
  expected_findings = expected["expected_findings"] || []
  max_findings = expected["max_findings"]

  matched = []
  missed = []

  expected_findings.each do |finding|
    rule_id = finding["rule_id"].to_s
    file = finding["file"].to_s
    fragments = finding["message_contains"] || []
    rule_ok = finding_text.include?(rule_id)
    basename = File.basename(file)
    file_ok = file.empty? || finding_text.include?(file) || (!basename.empty? && finding_text.include?(basename))
    fragments_ok = fragments.all? { |frag| normalized_findings.include?(deaccent.call(frag)) }
    if rule_ok && file_ok && fragments_ok
      matched << rule_id
    else
      missed << rule_id
    end
  end

  matched << "AUCUN FINDING" if expected_findings.empty? && review.strip == "AUCUN FINDING"

  reasons = []
  if max_findings && finding_lines.length > max_findings.to_i
    reasons << "max_findings depasse: #{finding_lines.length} > #{max_findings}"
  end
  reasons << "missing: #{missed.join(", ")}" unless missed.empty?

  result = reasons.empty? ? "PASS" : "FAIL"
  puts JSON.pretty_generate({
    case_id: ARGV[2],
    result: result,
    matched: matched.uniq,
    missed: missed.uniq,
    finding_count: finding_lines.length,
    reasons: result == "PASS" ? "Validation deterministe satisfaite." : reasons.join(" ; ")
  })
' "$expected_path" "$review_path" "$case_id" > "$out_path"
