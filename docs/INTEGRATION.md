# Integrer un vrai skill avec references et juge

Ce harnais suit les conventions de l'architecture cible. L'exemple runnable
cible le skill canonique `code-review-back`.

## 1. Brancher le skill

Contrat attendu :

- `skills/` est le repertoire enregistre par `copilot skill add`.
- `skills/code-review-back/SKILL.md` est le point d'entree canonique.
- Le `SKILL.md` doit nommer explicitement les references a charger et les
  conditions de chargement selectif.

Pour ce repo cible, les references de regles vivent sous `rules/` :

```text
rules/
├── index.md
├── services.rules.md
├── controller.rules.md
└── ...
```

## 2. Ecrire les cas

Chaque cas reste un dossier sous `evals/cases/<case-id>/` :

```text
evals/cases/<case-id>/
├── input.diff
└── expected.yml
```

Le juge compare seulement la review avec `expected.yml`. Le gate compare aussi
les fichiers lus si `context_expectations` est present.
Dans ce harnais durci, chaque cas non archive doit declarer
`context_expectations`; sinon le gate echoue.

Schema pratique :

```yaml
schema_version: 1
case_id: R1-api-contract
mode: standard
expected_findings:
  - rule_id: API-001
    file: src/example.ts
    message_contains: ["contract"]
forbidden_findings:
  - rule_id: SEC-001
max_findings: 1
context_expectations:
  exact_files_read:
    - rules/services.rules.md
  forbidden_files_read:
    - rules/controller.rules.md
  allowed_context_files:
    - skills/code-review-back/SKILL.md
```

Champs de contexte supportes :

- `exact_files_read` : egalite stricte apres retrait de `allowed_context_files`.
- `allowed_files_read` : liste bornee de fichiers acceptes; le cas passe si les
  fichiers lus sont un sous-ensemble de cette liste. Utile pour les vrais
  negatifs ou le skill peut lire zero fichier ou seulement le fichier de domaine.
- `exact_reference_files` : alias de `exact_files_read`, utile si tu veux garder
  le vocabulaire "references".
- `allowed_reference_files` : alias de `allowed_files_read`.
- `exact_rule_files` : alias historique conserve pour le squelette demo.
- `forbidden_files_read` : fichiers qui ne doivent jamais etre lus.
- `forbidden_reference_files` : alias de `forbidden_files_read`.
- `allowed_context_files` : fichiers autorises en plus des references exactes.
  Par defaut, le gate autorise `skills/code-review-back` et
  `skills/code-review-back/SKILL.md`,
  car le CLI peut exposer ou consulter le point d'entree du skill sans que cela
  soit une reference metier chargee.

## 3. Ajouter un cas qui doit echouer

Garde toujours un controle negatif :

```yaml
should_fail: true
expected_findings:
  - rule_id: RULE-INEXISTANTE
    file: src/example.ts
    message_contains: ["inexistant"]
```

Si ce cas passe, le gate echoue globalement avec un message indiquant que le
harnais ne detecte pas les regressions.

## 4. Adapter le juge

Le juge vit dans `evals/judge.prompt.md`. Pour un vrai skill, ajoute les criteres
metier minimaux mais garde ces invariants :

- sortie uniquement JSON, meme si le runner tolere les fences Markdown;
- `PASS` seulement si tous les attendus sont satisfaits;
- ne jamais deduire un finding absent;
- verifier `forbidden_findings`;
- verifier `max_findings`.

Le schema de sortie reste dans `evals/judge.schema.json`. Le runner valide au
minimum `case_id`, `result` et `reasons`.

## 5. Lancer une campagne cible

Verifier d'abord la coherence des regles :

```sh
make lint
```

Pour lancer tous les cas presents sous `evals/cases/` :

```sh
make eval
```

Pour lancer un seul cas :

```sh
make case CASE=R1-api-contract
```

Pour lancer une selection avancee :

```sh
make CASES="R1-api-contract R2-clean R3-must-fail" eval
```

Pour experimenter temporairement avec un autre skill sans modifier les scripts :

```sh
make SKILL=other-skill CASES="R1-api-contract" eval
```

## 6. Ce que le harnais garantit

Le harnais garantit seulement ce qu'il mesure :

- activation explicite du skill si la trace contient l'appel outil `skill`;
- fichiers lus si la trace contient des appels `view`;
- conservation de tous les chemins lus dans `files_read_all`;
- output tokens si `assistant.message.data.outputTokens` existe;
- verdict juge parsable;
- validation deterministe des `rule_id`, fichiers, fragments, interdits et `max_findings`;
- gate negatif via `should_fail`.

Il ne garantit pas les input tokens avec la surface observee: ils restent
`null` tant qu'aucun champ fiable n'est expose par le CLI.
