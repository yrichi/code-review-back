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

  read_json = lambda do |path, fallback|
    return fallback unless File.exist?(path)
    begin
      JSON.parse(File.read(path))
    rescue JSON::ParserError
      fallback
    end
  end

  cases.each do |case_id|
    expected_path = File.join(root, cases_dir, case_id, "expected.yml")
    case_results = File.join(root, results_dir, case_id)
    expected = YAML.load_file(expected_path)

    # Un cas peut avoir ete joue plusieurs fois (RUNS>1). runs.jsonl porte alors
    # une ligne par iteration. A defaut, on lit les artefacts plats du run unique.
    runs_path = File.join(case_results, "runs.jsonl")
    iterations = []
    if File.exist?(runs_path)
      File.readlines(runs_path).each do |line|
        begin
          iterations << JSON.parse(line)
        rescue JSON::ParserError
        end
      end
    end
    if iterations.empty?
      iterations = [{
        "verdict" => read_json.call(File.join(case_results, "verdict.json"), {"result" => "FAIL", "reasons" => "verdict absent"}),
        "review_check" => read_json.call(File.join(case_results, "review-check.json"), {"result" => "FAIL", "reasons" => "review-check absent"}),
        "metrics" => read_json.call(File.join(case_results, "metrics.json"), {"files_read" => nil, "notes" => {"files_read" => "metrics absent"}})
      }]
    end

    should_fail = expected["should_fail"] == true

    # Evalue une iteration et rend son verdict brut. La logique est identique
    # quel que soit le nombre diterations: cest lagregation qui change.
    evaluate = lambda do |iteration|
      verdict = iteration["verdict"] || {"result" => "FAIL", "reasons" => "verdict absent"}
      review_check = iteration["review_check"] || {"result" => "FAIL", "reasons" => "review-check absent"}
      metrics = iteration["metrics"] || {"files_read" => nil, "notes" => {"files_read" => "metrics absent"}}

      # Une panne dinfrastructure nest pas une mesure. Sans ce court-circuit, un
      # quota epuise ferait passer les cas should_fail au vert (rien na tourne,
      # donc rien na passe) et ferait passer les autres pour des regressions du
      # skill. Une iteration non mesuree est ERROR, jamais PASS ni FAIL.
      run_error = metrics["run_error"] || verdict["run_error"]
      if run_error
        code = run_error["code"] || "inconnu"
        status = run_error["status"]
        next {"error" => "#{code}#{status ? " HTTP #{status}" : ""}"}
      end

      raw_pass = verdict["result"] == "PASS" && review_check["result"] == "PASS"
      if should_fail
        # Nommer qui a fait echouer le cas: un should_fail satisfait par le mauvais
        # composant masquerait la mort du composant vise.
        failed_by = []
        failed_by << "juge" unless verdict["result"] == "PASS"
        failed_by << "deterministe" unless review_check["result"] == "PASS"
        correctness_ok = !raw_pass
        correctness = raw_pass ? "FAIL: should_fail a passe; le harnais ne detecte pas les regressions" : "PASS: echec attendu observe (via #{failed_by.join(" + ")})"
      else
        reasons = [verdict["result"] == "PASS" ? nil : "judge: #{verdict["reasons"]}", review_check["result"] == "PASS" ? nil : "deterministe: #{review_check["reasons"]}"].compact.join(" ; ")
        correctness_ok = raw_pass
        correctness = raw_pass ? "PASS" : "FAIL: #{reasons}"
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

      {
        "correctness_ok" => correctness_ok,
        "correctness" => correctness,
        "selectivity_ok" => selectivity == "PASS",
        "selectivity" => selectivity,
        "tokens" => "in=#{metrics["input_tokens"] || "null"} out=#{metrics["output_tokens"] || "null"}"
      }
    end

    results = iterations.map { |iteration| evaluate.call(iteration) }
    errors = results.select { |r| r["error"] }
    measured = results.reject { |r| r["error"] }

    if measured.empty?
      rows << [case_id, "ERROR: non mesure (#{errors.first["error"]})", "ERROR: non mesure", "in=null out=null"]
      global_ok = false
      next
    end

    total = measured.length
    correctness_ok = measured.count { |r| r["correctness_ok"] }
    selectivity_ok = measured.count { |r| r["selectivity_ok"] }
    suffix = errors.empty? ? "" : " (#{errors.length} non mesuree#{errors.length > 1 ? "s" : ""})"

    if total == 1 && errors.empty?
      # Iteration unique: on garde la sortie historique, un ratio 1/1 najoute rien.
      correctness = measured.first["correctness"]
      selectivity = measured.first["selectivity"]
    else
      # Un cas nest vert que si TOUTES les iterations mesurees passent. Un cas
      # instable doit se voir: 2/3 est une information, pas un PASS.
      first_bad_correctness = measured.find { |r| !r["correctness_ok"] }
      first_bad_selectivity = measured.find { |r| !r["selectivity_ok"] }
      correctness = "#{correctness_ok}/#{total}#{suffix}"
      correctness += " #{first_bad_correctness["correctness"]}" if first_bad_correctness
      selectivity = "#{selectivity_ok}/#{total}#{suffix}"
      selectivity += " #{first_bad_selectivity["selectivity"]}" if first_bad_selectivity
    end

    global_ok &&= (correctness_ok == total && selectivity_ok == total && errors.empty?)
    rows << [case_id, correctness, selectivity, measured.last["tokens"]]
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
