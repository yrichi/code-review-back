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
expected_findings:
  - rule_id: API-001
    file: src/example.ts
    message_contains: ["contract"]
max_findings: 1
context_expectations:
  exact_files_read:
    - rules/services.rules.md
```

L'identifiant du cas est le nom de son repertoire : il n'est pas redeclare dans
le fichier.

Le schema tient en trois axes, un champ par axe :

| Axe | Champ | Question posee |
| --- | --- | --- |
| Justesse | `expected_findings` | Ce qui doit etre trouve l'a-t-il ete ? |
| Bruit | `max_findings` | Combien de findings au maximum ? |
| Selectivite | `context_expectations` | Quelles references ont ete chargees ? |

Chaque axe peut faire echouer un cas que les deux autres laisseraient passer.
`should_fail: true` s'y ajoute pour les controles du harnais lui-meme.

Champs de contexte supportes, exclusifs l'un de l'autre :

- `exact_files_read` : egalite stricte des fichiers de references lus. C'est le
  choix par defaut; tout fichier en trop ou manquant fait echouer la selectivite.
- `allowed_files_read` : liste bornee de fichiers acceptes; le cas passe si les
  fichiers lus sont un sous-ensemble de cette liste. Utile pour les vrais
  negatifs ou le skill peut lire zero fichier ou seulement le fichier de domaine.

Ces deux champs bornent l'ensemble des lectures par le haut, et
`expected_findings` combine a `max_findings` borne les findings : le bruit et le
contexte sont donc contraints sans avoir a enumerer d'interdits.

### Plusieurs regles par fichier, plusieurs findings par cas

Un fichier de regles porte toutes les regles de son domaine. C'est le fichier que
le skill charge, donc deux regles qu'un meme diff peut declencher ensemble
doivent y vivre ensemble. `rules/services.rules.md` porte `SRV-001` et `SRV-002`.

Deux cas cadrent ce couple :

- `C11-services-deux-regles` : les deux regles se declenchent sur le meme fichier
  source, avec un seul referentiel charge. `max_findings: 2`.
- `C12-services-une-regle` : le meme referentiel est charge, mais une seule regle
  doit se declencher. `max_findings: 1` interdit a l'autre de sortir.

Le second est le plus utile : il mesure la capacite du skill a discriminer entre
deux regles voisines qu'il a lues dans le meme fichier.

Le gate autorise toujours le point d'entree du skill (`skills/code-review-back`
et `skills/code-review-back/SKILL.md`) comme contexte technique. Ces chemins ne
sont pas consideres comme des references metier chargees.

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
harnais ne detecte pas les regressions. Le gate nomme le composant qui a produit
l'echec attendu (`via juge`, `via deterministe`) : un `should_fail` satisfait par
le mauvais composant masquerait la mort du composant vise.

### Cas de rejeu

Un cas peut fournir `trace.fixture.jsonl` : cette trace est alors rejouee au lieu
d'appeler le CLI, et tout l'aval s'execute normalement.

```text
evals/cases/<case-id>/
├── input.diff
├── trace.fixture.jsonl   # optionnel: rejeu, aucun appel modele
└── expected.yml
```

La trace suit le format JSONL du CLI. Le minimum utile :

```jsonl
{"type":"tool.execution_start","data":{"toolName":"skill","arguments":{"skill":"code-review-back"}}}
{"type":"tool.execution_start","data":{"toolName":"view","arguments":{"path":"rules/services.rules.md"}}}
{"type":"assistant.message","data":{"content":"- [SRV-001] ...","inputTokens":1200,"outputTokens":40}}
```

Ce mode existe pour les cas qui testent le **harnais** et non le modele : on ne
peut pas demander a un modele de produire a la demande une review volontairement
fausse. `C10-faux-pass` s'en sert pour prouver que le juge sert a quelque chose :
il rejoue une review mecaniquement irreprochable mais semantiquement fausse. Le
deterministe la laisse passer, donc seul le juge peut satisfaire son
`should_fail`. Si le juge cesse de juger, C10 vire au rouge.

## 4. Adapter le juge

Le juge vit dans `evals/judge.prompt.md`. Il ne juge que la **semantique**. Le
mecanique — presence du `rule_id`, du fichier, des fragments, respect de
`max_findings` — est tranche par `validate-review.sh`, sans appel modele et sans
erreur possible.

Cette repartition tient a une propriete du deterministe : c'est un matcher de
sous-chaines. Il verifie que les elements attendus sont presents, jamais qu'ils
ont un rapport entre eux. Une review qui cite `SRV-001`, le bon fichier et le bon
fragment tout en concluant « rien a signaler » le satisfait. Seul le juge la
rejette. Symetriquement, le juge ne recompte pas les findings : ce serait payer un
appel modele pour un resultat deja acquis.

`run-judge.sh` fournit au juge le texte des regles declarees dans
`context_expectations` : sans lui, il ne peut pas distinguer une `Detection`
d'une `Exclusion`, ni voir qu'un `rule_id` a ete invente.

Pour un vrai skill, ajoute les criteres metier mais garde ces invariants :

- sortie uniquement JSON, meme si le runner tolere les fences Markdown;
- ne jamais revalider ce que le deterministe tranche deja;
- ne jamais deduire un finding absent;
- un `rule_id` absent des regles fournies est un FAIL, meme si l'analyse est juste;
- FAIL des qu'un finding est mecaniquement present mais semantiquement faux.

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
- validation deterministe des `rule_id`, fichiers, fragments et `max_findings`;
- gate negatif via `should_fail`, avec le composant responsable nomme;
- controle negatif du juge via `C10-faux-pass` et le rejeu de trace figee;
- separation entre un echec mesure (`FAIL`) et une panne (`ERROR: non mesure`),
  pour qu'une indisponibilite du CLI ne se lise jamais comme une regression du
  skill ni ne fasse verdir un `should_fail`.

Il ne garantit pas les input tokens avec la surface observee: ils restent
`null` tant qu'aucun champ fiable n'est expose par le CLI.

Il ne garantit pas non plus la stabilite du verdict semantique: le juge est un
LLM, donc non-deterministe. Il peut produire des faux FAIL. C'est le prix du seul
controle qui voit autre chose que des sous-chaines.

Il ne garantit surtout pas la reproductibilite: le CLI route la requete vers un
modele qu'il choisit seul (`session.auto_mode_resolved`), et `--model` rejette
tous les noms testes, y compris celui que le routeur vient de choisir. Deux runs
peuvent mesurer deux modeles differents. Avant de conclure a une regression,
verifier `chosenModel` dans la trace.
