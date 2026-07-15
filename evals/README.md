# Evals

Ce dossier contient le harnais local d'evaluation du skill `code-review-back`.

## Structure

- `cases/` : entrees et attendus YAML.
- `results/` : sorties brutes, metriques et verdicts.
- `runner/` : scripts du harnais.
- `judge.prompt.md` : prompt du juge.
- `judge.schema.json` : schema de sortie attendu.

## Contrats de gate

Chaque cas doit declarer `context_expectations`. Une absence de mesure de
selectivite est consideree comme un echec, pas comme un succes implicite.
Utilise `exact_files_read` pour les cas stricts et `allowed_files_read` pour les
vrais negatifs ou zero fichier de regle lu reste acceptable.

Le gate combine :

- `verdict.json` : verdict du juge LLM;
- `review-check.json` : validation deterministe des invariants mecaniques;
- `metrics.json` : tokens, skill active et fichiers lus.

## Lancer

Depuis la racine :

```sh
make eval
```

Pour un seul cas :

```sh
make case CASE=C1-services-violation
```

Pour une selection avancee :

```sh
make CASES="C1-services-violation C2-clean-service" eval
```
