#!/usr/bin/env bash
set -euo pipefail

# Validation deterministe minimale de review.txt.
# Le juge LLM reste utile pour le wording, mais les invariants mecaniques
# (rule_id, fichier, fragments, interdits, max_findings) ne dependent pas de lui.

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
  normalized_findings = finding_text.downcase
  expected_findings = expected["expected_findings"] || []
  forbidden_findings = expected["forbidden_findings"] || []
  max_findings = expected["max_findings"]

  matched = []
  missed = []
  forbidden_violated = []

  expected_findings.each do |finding|
    rule_id = finding["rule_id"].to_s
    file = finding["file"].to_s
    fragments = finding["message_contains"] || []
    rule_ok = finding_text.include?(rule_id)
    basename = File.basename(file)
    file_ok = file.empty? || finding_text.include?(file) || (!basename.empty? && finding_text.include?(basename))
    fragments_ok = fragments.all? { |frag| normalized_findings.include?(frag.to_s.downcase) }
    if rule_ok && file_ok && fragments_ok
      matched << rule_id
    else
      missed << rule_id
    end
  end

  forbidden_findings.each do |finding|
    rule_id = finding["rule_id"].to_s
    forbidden_violated << rule_id if !rule_id.empty? && finding_text.include?(rule_id)
  end

  reasons = []
  if expected_findings.empty?
    if review.strip == "AUCUN FINDING" || finding_lines.empty?
      matched << "AUCUN FINDING" if review.strip == "AUCUN FINDING"
    else
      reasons << "expected_findings vide mais #{finding_lines.length} finding(s) detecte(s)"
    end
  end

  if max_findings && finding_lines.length > max_findings.to_i
    reasons << "max_findings depasse: #{finding_lines.length} > #{max_findings}"
  end
  reasons << "missing: #{missed.join(", ")}" unless missed.empty?
  reasons << "forbidden: #{forbidden_violated.join(", ")}" unless forbidden_violated.empty?

  result = reasons.empty? ? "PASS" : "FAIL"
  puts JSON.pretty_generate({
    case_id: expected["case_id"] || ARGV[2],
    result: result,
    matched: matched.uniq,
    missed: missed.uniq,
    forbidden_violated: forbidden_violated.uniq,
    finding_count: finding_lines.length,
    reasons: result == "PASS" ? "Validation deterministe satisfaite." : reasons.join(" ; ")
  })
' "$expected_path" "$review_path" "$case_id" > "$out_path"
