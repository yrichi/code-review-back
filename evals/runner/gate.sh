#!/usr/bin/env bash
set -euo pipefail

# Agrege les verdicts et les metriques. La selectivite ne passe jamais si les
# fichiers lus ne sont pas mesurables: elle devient NOT_RUN.

mode="${1:-}"
root="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ "$mode" == "--context-only" ]]; then
  shift || true
else
  mode=""
fi

skill_dir="${SKILL_DIR:-skills/${SKILL_NAME:-code-review-back}}"
cases_dir="${CASES_DIR:-evals/cases}"
results_dir="${RESULTS_DIR:-evals/results}"

if [[ "$#" -gt 0 ]]; then
  cases=("$@")
elif [[ -f "$root/$results_dir/cases.list" ]]; then
  # shellcheck disable=SC2207
  cases=($(cat "$root/$results_dir/cases.list"))
else
  cases=(C1-services-violation C2-clean-service C3-must-fail)
fi

ruby -rjson -ryaml -e '
  root = ARGV[0]
  context_only = ARGV[1] == "--context-only"
  skill_dir = ARGV[2].sub(%r{/\z}, "")
  cases_dir = ARGV[3]
  results_dir = ARGV[4]
  cases = ARGV[5..]
  rows = []
  global_ok = true

  cases.each do |case_id|
    expected_path = File.join(root, cases_dir, case_id, "expected.yml")
    verdict_path = File.join(root, results_dir, case_id, "verdict.json")
    metrics_path = File.join(root, results_dir, case_id, "metrics.json")
    expected = YAML.load_file(expected_path)
    review_check_path = File.join(root, results_dir, case_id, "review-check.json")
    verdict = File.exist?(verdict_path) ? JSON.parse(File.read(verdict_path)) : {"result" => "FAIL", "reasons" => "verdict absent"}
    review_check = File.exist?(review_check_path) ? JSON.parse(File.read(review_check_path)) : {"result" => "FAIL", "reasons" => "review-check absent"}
    metrics = File.exist?(metrics_path) ? JSON.parse(File.read(metrics_path)) : {"files_read" => nil, "notes" => {"files_read" => "metrics absent"}}

    should_fail = expected["should_fail"] == true
    raw_pass = verdict["result"] == "PASS" && review_check["result"] == "PASS"

    # Une panne dinfrastructure nest pas une mesure. Sans ce court-circuit, un
    # quota epuise ferait passer les cas should_fail au vert (rien na tourne,
    # donc rien na passe) et ferait passer les autres pour des regressions du
    # skill. Un cas non mesure est ERROR, jamais PASS ni FAIL.
    run_error = metrics["run_error"] || verdict["run_error"]
    if run_error
      code = run_error["code"] || "inconnu"
      status = run_error["status"]
      rows << [case_id, "ERROR: non mesure (#{code}#{status ? " HTTP #{status}" : ""})", "ERROR: non mesure", "in=null out=null"]
      global_ok = false
      next
    end

    if should_fail
      # Nommer qui a fait echouer le cas: un should_fail satisfait par le mauvais
      # composant masquerait la mort du composant vise.
      failed_by = []
      failed_by << "juge" unless verdict["result"] == "PASS"
      failed_by << "deterministe" unless review_check["result"] == "PASS"
      correctness = raw_pass ? "FAIL: should_fail a passe; le harnais ne detecte pas les regressions" : "PASS: echec attendu observe (via #{failed_by.join(" + ")})"
      global_ok &&= !raw_pass
    else
      reasons = [verdict["result"] == "PASS" ? nil : "judge: #{verdict["reasons"]}", review_check["result"] == "PASS" ? nil : "deterministe: #{review_check["reasons"]}"].compact.join(" ; ")
      correctness = raw_pass ? "PASS" : "FAIL: #{reasons}"
      global_ok &&= raw_pass
    end

    selectivity = "FAIL: context_expectations absent"
    ctx_node = expected["context_expectations"] || {}
    ctx = ctx_node["exact_files_read"]
    allowed_files = ctx_node["allowed_files_read"]
    allowed_context = ["#{skill_dir}", "#{skill_dir}/SKILL.md"]
    if ctx || allowed_files
      files = metrics["files_read_all"] || metrics["files_read"]
      if files.is_a?(Array)
        normalized = files.map { |f| f.sub(%r{^.*#{Regexp.escape(skill_dir)}/}, "#{skill_dir}/") }.uniq.sort
        comparable = normalized.reject { |f| allowed_context.include?(f) || File.directory?(File.join(root, f)) }.sort
        if ctx
          want = ctx.sort
          selectivity = (comparable == want) ? "PASS" : "FAIL: attendu #{want.inspect}, observe #{comparable.inspect}"
        else
          allowed = allowed_files.sort
          extra = comparable - allowed
          selectivity = extra.empty? ? "PASS" : "FAIL: autorise #{allowed.inspect}, observe #{comparable.inspect}, extra #{extra.inspect}"
        end
      else
        selectivity = "FAIL: #{metrics.dig("notes", "files_read_all") || metrics.dig("notes", "files_read") || "files_read null"}"
      end
    end
    global_ok &&= (selectivity == "PASS")

    tokens = "in=#{metrics["input_tokens"] || "null"} out=#{metrics["output_tokens"] || "null"}"
    rows << [case_id, correctness, selectivity, tokens]
  end

  unless context_only
    puts "case | justesse | selectivite | tokens"
    puts "--- | --- | --- | ---"
    rows.each { |r| puts r.join(" | ") }
  else
    puts "case | selectivite | tokens"
    puts "--- | --- | ---"
    rows.each { |r| puts [r[0], r[2], r[3]].join(" | ") }
  end

  exit(global_ok ? 0 : 1)
' "$root" "$mode" "$skill_dir" "$cases_dir" "$results_dir" "${cases[@]}"
