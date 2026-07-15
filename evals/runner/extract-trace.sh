#!/usr/bin/env bash
set -euo pipefail

# Extrait uniquement les champs observables dans trace.raw.
# Aucune inference: les valeurs absentes restent null avec une note.

case_id="${1:-}"
if [[ -z "$case_id" ]]; then
  echo "usage: runner/extract-trace.sh <case-id>" >&2
  exit 2
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"

skill_name="${SKILL_NAME:-code-review-back}"
skill_dir="${SKILL_DIR:-skills/$skill_name}"
results_dir="${RESULTS_DIR:-evals/results}"
out_dir="$root/$results_dir/$case_id"
trace="$out_dir/trace.raw"

if [[ ! -f "$trace" ]]; then
  echo "trace introuvable: $trace" >&2
  exit 2
fi

ruby -rjson -e '
  trace_path = ARGV[0]
  root = File.expand_path(ARGV[1])
  expected_skill_name = ARGV[2]
  expected_skill_dir = ARGV[3].sub(%r{/\z}, "")
  text = File.read(trace_path)
  events = []
  text.each_line do |line|
    begin
      events << JSON.parse(line)
    rescue JSON::ParserError
    end
  end

  def walk(obj, path = [], &block)
    yield(obj, path)
    case obj
    when Hash
      obj.each { |k, v| walk(v, path + [k.to_s], &block) }
    when Array
      obj.each_with_index { |v, i| walk(v, path + [i.to_s], &block) }
    end
  end

  input_tokens = nil
  output_tokens = nil
  output_token_parts = []
  token_sources = []
  files_all = []
  skill = nil

  events.each do |event|
    if event["type"] == "assistant.message"
      out = event.dig("data", "outputTokens")
      if out.is_a?(Integer)
        output_token_parts << out
        token_sources << "assistant.message.data.outputTokens"
      end
    end
    if event["type"] == "tool.execution_start"
      tool = event.dig("data", "toolName")
      args = event.dig("data", "arguments") || {}
      if tool == "view" && args["path"].is_a?(String)
        files_all << args["path"]
      elsif tool == "skill" && args["skill"] == expected_skill_name
        skill = expected_skill_name
      end
    end
    if event["type"] == "tool.execution_complete"
      skill = expected_skill_name if event.dig("data", "toolTelemetry", "restrictedProperties", "skillName") == expected_skill_name
    end
    walk(event) do |v, path|
      key = path.last.to_s.downcase
      joined = path.join(".")
      next unless v.is_a?(Integer) || v.is_a?(Float)
      if key.match?(/input.*tokens|prompt.*tokens/)
        input_tokens ||= v.to_i
        token_sources << joined
      end
    end
  end

  output_tokens = output_token_parts.empty? ? nil : output_token_parts.sum
  normalize = lambda do |f|
    f = f.sub(root + "/", "")
    f.gsub(/[",\]}].*$/, "")
  end
  files_all = files_all.map { |f| normalize.call(f) }.uniq.sort
  files_reference = files_all.select { |f|
    f.start_with?(expected_skill_dir + "/") ||
      f.match?(%r{(^|/)rules/.*\.rules\.md$}) ||
      f.end_with?("SKILL.md")
  }.uniq.sort

  metrics = {
    input_tokens: input_tokens,
    output_tokens: output_tokens,
    files_read: files_reference.empty? ? nil : files_reference,
    files_read_all: files_all.empty? ? nil : files_all,
    skill_activated: skill,
    notes: {
      input_tokens: input_tokens.nil? ? "NOT_FOUND: aucun champ input/prompt tokens observe dans trace.raw" : "observe dans #{token_sources.uniq.join(", ")}",
      output_tokens: output_tokens.nil? ? "NOT_FOUND: aucun champ output/completion tokens observe dans trace.raw" : "somme des assistant.message.data.outputTokens observes",
      files_read: files_reference.empty? ? "NOT_FOUND: aucun fichier de reference exploitable observe dans les appels view" : "fichiers de reference derives depuis files_read_all",
      files_read_all: files_all.empty? ? "NOT_FOUND: aucun tool.execution_start view avec arguments.path observe dans trace.raw" : "tous les chemins lus via tool.execution_start view arguments.path",
      skill_activated: skill.nil? ? "NOT_FOUND: aucune activation explicite de skill observee; presence textuelle non suffisante hors champs skill/tool/message" : "#{expected_skill_name} observe dans trace.raw"
    }
  }
  puts JSON.pretty_generate(metrics)
' "$trace" "$root" "$skill_name" "$skill_dir" > "$out_dir/metrics.json"
