# Usage

## Modes

- `make eval` : chemin nominal complet.
- `make case CASE=<case-id>` : execute un seul cas et son gate.
- `make setup` : verifie le CLI et prepare `evals/results/`.
- `make lint` : verifie la coherence minimale des regles.
- `make run` : execute review, extraction de trace et juge pour chaque cas.
- `make gate` : applique le gate sur les artefacts deja produits.
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

## Format d'un expected.yml

```yaml
expected_findings:
  - rule_id: SRV-001
    file: src/main/java/demo/UserService.java
    message_contains: ["service"]
max_findings: 1
context_expectations:
  exact_files_read:
    - rules/services.rules.md
```

Le schema tient en trois axes, un champ par axe :

- `expected_findings` : la justesse, ce qui doit etre trouve.
- `max_findings` : le bruit, le plafond de findings tolere.
- `context_expectations` : la selectivite, les references chargees.

Le nom du repertoire du cas fait foi pour son identifiant; ne le redeclare pas
dans le fichier.

Pour un vrai negatif ou le skill peut lire zero ou un fichier de domaine, utiliser
`allowed_files_read` a la place de `exact_files_read`.

Il n'existe pas de liste de regles interdites. `exact_files_read` impose deja
l'egalite stricte des fichiers lus, et `max_findings` combine a
`expected_findings` interdit deja tout finding en trop : une liste d'interdits
ne pourrait faire echouer aucun cas que ces champs laissent passer.

## Garde-fous d'evaluation

Le gate combine trois signaux :

- verdict LLM dans `verdict.json` : validite **semantique** des findings;
- validation deterministe dans `review-check.json` : invariants **mecaniques**;
- selectivite de contexte dans `metrics.json`.

Les deux premiers ne se recouvrent pas. Le deterministe est un matcher de
sous-chaines : il verifie que le `rule_id`, le fichier et les fragments sont
presents, jamais qu'ils ont un rapport entre eux. Une review qui cite `SRV-001`
sur le bon fichier tout en concluant « rien a signaler » le satisfait. Seul le
juge peut la rejeter. Inversement, le juge ne recompte pas les findings : c'est
mecanique, donc deterministe.

Un cas non `should_fail` doit passer les trois. Un cas `should_fail: true` doit
echouer en justesse pour prouver que le harnais detecte les regressions; le gate
nomme le composant qui a produit cet echec (`via juge`, `via deterministe`).

## Cas de rejeu

Un cas qui contient `trace.fixture.jsonl` rejoue cette trace au lieu d'appeler le
CLI. Tout l'aval s'execute normalement : extraction, metriques, selectivite,
validation, juge.

Ce mode sert aux cas qui testent le **harnais** et non le modele : on ne peut pas
demander a un modele de produire a la demande une review volontairement fausse.
`C10-faux-pass` s'en sert pour prouver que le juge sert a quelque chose.
