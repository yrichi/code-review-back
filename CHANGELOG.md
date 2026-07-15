# Changelog

Toutes les modifications notables de ce projet seront documentees ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)
et le versionnement suit SemVer.

## [0.1.0] - 2026-07-15

### Ajoute

- Architecture cible `rules/`, `decisions/`, `evals/`, `docs/`, `skills/`.
- Skill canonique `skills/code-review-back/SKILL.md`.
- Harnais d'evaluation local sous `evals/`.
- Cas de calibration service, clean et controle negatif.
- Cas Java reels `C4` a `C6` pour controller, securite et DCP.
- Cas Java medium `C7` a `C9` avec classes completes.
- Validation deterministe `review-check.json` en complement du juge LLM.
- Selectivite de contexte par `exact_files_read`, `allowed_files_read` et `forbidden_files_read`.

### Modifie

- `make gate` lit les artefacts existants sans relancer les reviews.
- Schema `expected.yml` simplifie: suppression de `mode` et des alias historiques de contexte.
