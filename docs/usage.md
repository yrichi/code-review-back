# Usage

## Modes

- `make eval` : chemin nominal complet.
- `make case CASE=<case-id>` : execute un seul cas et son gate.
- `make setup` : verifie le CLI et prepare `evals/results/`.
- `make lint` : verifie la coherence minimale des regles.
- `make run` : execute review, extraction de trace et juge pour chaque cas.
- `make gate` : lance les cas puis applique le gate.
- `make context` : affiche uniquement selectivite et tokens.
- `make clean` : vide `evals/results/`.

## Format d'une regle

Une regle vit dans `rules/*.rules.md` :

```md
## ID - Titre
Statut: Active|Candidate|Deprecated
Severite: MINEUR|MOYEN|ELEVE
Detection: condition observable.
Exclusion: cas a ne pas signaler.
Risque: impact objectivable.
Correctif: correction attendue.
Exemple a signaler: ...
Exemple a ne pas signaler: ...
Evals: ...
```

## Contribution

1. Ajouter ou modifier une regle dans `rules/`.
2. Mettre a jour `rules/index.md`.
3. Documenter la decision dans `decisions/ledger.md`.
4. Ajouter au moins un cas sous `evals/cases/`.
5. Lancer `make eval`.

## Garde-fous d'evaluation

Le gate combine trois signaux :

- verdict LLM dans `verdict.json`;
- validation deterministe dans `review-check.json`;
- selectivite de contexte dans `metrics.json`.

Un cas non `should_fail` doit passer les trois. Un cas `should_fail: true` doit
echouer en justesse pour prouver que le harnais detecte les regressions.
