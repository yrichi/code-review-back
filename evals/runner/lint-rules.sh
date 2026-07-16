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

  # Un fichier de regles peut en porter plusieurs: on decoupe par titre et on
  # valide chaque regle separement. Sans ce decoupage, seule la premiere regle
  # dun fichier serait controlee.
  declared = []
  Dir.glob(File.join(root, "rules", "*.rules.md")).sort.each do |file|
    content = File.read(file)
    rel = file.sub(root + "/", "")
    sections = content.split(/^(?=##\s+[A-Z]+-\d+\b)/).reject { |s| s.strip.empty? }
    sections = sections.select { |s| s.match?(/\A##\s+[A-Z]+-\d+\b/) }
    if sections.empty?
      errors << "#{rel}: aucun ID de regle trouve dans les titres"
      next
    end
    sections.each do |section|
      id = section[/\A##\s+([A-Z]+-\d+)\b/, 1]
      declared << id
      errors << "#{rel}: #{id} absent de rules/index.md" unless indexed.key?(id)
      if indexed.key?(id) && indexed[id]["path"] != rel
        errors << "#{rel}: #{id} indexe sur #{indexed[id]["path"]} mais defini ici"
      end
      next unless section.match?(/^Statut:\s*Active\b/)
      evals = section[/^Evals:\s*(.+)$/i, 1].to_s.strip
      if evals.empty? || evals.match?(/\(aucune|none|n\/a/i)
        errors << "#{rel}: #{id} Active sans eval declaree"
      end
      evals.split(/[,;]/).map(&:strip).reject(&:empty?).each do |case_id|
        unless Dir.exist?(File.join(root, "evals", "cases", case_id))
          errors << "#{rel}: #{id} declare une eval inexistante: #{case_id}"
        end
      end
    end
  end

  (indexed.keys - declared).each do |orphan|
    errors << "rules/index.md: #{orphan} indexe mais defini dans aucun fichier de regles"
  end

  if errors.empty?
    puts "lint-rules: PASS"
  else
    warn "lint-rules: FAIL"
    errors.each { |e| warn "- #{e}" }
    exit 1
  end
' "$root"
