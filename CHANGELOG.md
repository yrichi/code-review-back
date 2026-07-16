# Changelog

Toutes les modifications notables de ce projet seront documentees ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)
et le versionnement suit SemVer.

## [Non publie]

### Corrige

- `validate-review.sh` compare les fragments `message_contains` sans diacritiques.
  Le fragment `acces` ne pouvait jamais matcher la forme accentuee ecrite par le
  modele: `C5` et `C8` etaient structurellement condamnes. `C8` est un cas ou le
  skill faisait tout correctement et que l'eval rejetait a tort.
- `judge.prompt.md`: un `rule_id` absent de `REGLES` est desormais un FAIL sans
  exception, et `reasons` ne peut jamais etre vide. Le juge rejetait C5/C6/C9
  pour identifiant invente mais laissait passer C4 pour le meme defaut.

### Ajoute

- Rejeu de trace figee : un cas qui fournit `trace.fixture.jsonl` court-circuite
  l'appel CLI, tout l'aval s'executant normalement. Permet de tester le harnais
  lui-meme, un modele ne pouvant pas produire a la demande une review fausse.
- Cas `C10-faux-pass` : controle negatif du juge. Rejoue une review mecaniquement
  irreprochable mais semantiquement fausse (elle cite `SRV-001` et conclut a la
  conformite). La validation deterministe la laisse passer, donc seul le juge
  peut satisfaire son `should_fail`. Vire au rouge si le juge cesse de juger.
- `run-judge.sh` fournit au juge le texte des regles declarees dans
  `context_expectations`, sans quoi il ne peut pas distinguer une `Detection`
  d'une `Exclusion`.

### Modifie

- `evals/judge.prompt.md` recentre sur la validite **semantique** des findings.
  Le juge ne revalide plus les invariants mecaniques, deja tranches sans erreur
  possible par `validate-review.sh`; il juge desormais ce que lui seul peut voir:
  un finding mecaniquement present mais faux.
- `gate.sh` nomme le composant qui satisfait un `should_fail` (`via juge`,
  `via deterministe`) : sinon un `should_fail` satisfait par le mauvais composant
  masque la mort du composant vise.
- `FINDINGS.md`, `docs/usage.md`, `docs/INTEGRATION.md` et la presentation
  documentent la non-reproductibilite du modele: le CLI route seul
  (`session.auto_mode_resolved`) et `--model` rejette tous les noms testes, y
  compris celui que le routeur vient de choisir. Deux runs peuvent mesurer deux
  modeles differents.
- La presentation affiche les resultats reels du run 2026-07-16 (gate rouge,
  4 verts sur 10) au lieu d'une calibration verte devenue fausse.

### Supprime

- Champ `forbidden_files_read` de `context_expectations` : `exact_files_read`
  impose deja l'egalite stricte des fichiers lus et `allowed_files_read` les
  borne par le haut, donc aucun cas ne pouvait echouer par ce seul champ.
- Champ `forbidden_findings` de `expected.yml` : `expected_findings` combine a
  `max_findings` interdit deja tout finding en trop.
- Champ `schema_version` : jamais lu par aucun runner.
- Champ `case_id` : le nom du repertoire du cas fait foi.

### Modifie

- `expected.yml` se limite a trois axes : justesse (`expected_findings`), bruit
  (`max_findings`) et selectivite (`context_expectations`), plus `should_fail`
  pour le controle negatif.
- `evals/judge.prompt.md` et `evals/judge.schema.json` ne referencent plus
  `forbidden_findings` ni `forbidden_violated`.

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
