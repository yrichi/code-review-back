#!/usr/bin/env bash
set -euo pipefail

# Lint minimal de coherence des regles.
# Objectif: rendre l'ajout d'une regle active difficile a oublier dans l'index
# ou sans eval de couverture.

root="$(cd "$(dirname "$0")/../.." && pwd)"

ruby -e '
  root = ARGV[0]
  index_path = File.join(root, "rules", "index.md")
  abort("rules/index.md introuvable") unless File.exist?(index_path)

  index = File.read(index_path)
  indexed = {}
  index.scan(/\|\s*([A-Z]+-\d+)\s*\|[^|]*\|\s*`([^`]+)`\s*\|\s*([^|]+)\|/) do |id, path, status|
    indexed[id] = {"path" => path, "status" => status.strip}
  end

  errors = []
  indexed.each do |id, row|
    full = File.join(root, row["path"])
    errors << "#{id}: fichier indexe introuvable #{row["path"]}" unless File.exist?(full)
  end

  Dir.glob(File.join(root, "rules", "*.rules.md")).sort.each do |file|
    content = File.read(file)
    id = content[/^##\s+([A-Z]+-\d+)\b/, 1]
    rel = file.sub(root + "/", "")
    if id.nil?
      errors << "#{rel}: ID de regle introuvable dans le titre"
      next
    end
    errors << "#{rel}: #{id} absent de rules/index.md" unless indexed.key?(id)
    if content.match?(/^Statut:\s*Active\b/)
      evals = content[/^Evals:\s*(.+)$/i, 1].to_s.strip
      if evals.empty? || evals.match?(/\(aucune|none|n\/a/i)
        errors << "#{rel}: regle Active sans eval declaree"
      end
    end
  end

  if errors.empty?
    puts "lint-rules: PASS"
  else
    warn "lint-rules: FAIL"
    errors.each { |e| warn "- #{e}" }
    exit 1
  end
' "$root"
