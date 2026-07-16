# Usage

## Modes

- `make eval` : chemin nominal complet.
- `make eval RUNS=<k>` : joue chaque cas `k` fois; le gate rapporte `k/N`. Defaut 1.
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

Un fichier peut porter plusieurs regles du meme domaine : `rules/services.rules.md`
declare `SRV-001` et `SRV-002`. Le decoupage se fait sur le titre `## ID - Titre`,
et chaque regle est lintee separement. Le domaine, pas la regle, decide du
fichier : c'est le fichier qui est charge par le skill, donc deux regles qu'un
meme diff peut declencher ensemble doivent vivre ensemble.

## Contribution

1. Ajouter ou modifier une regle dans `rules/`, dans le fichier de son domaine.
2. Mettre a jour `rules/index.md`.
3. Documenter la decision dans `decisions/ledger.md`.
4. Ajouter au moins un cas sous `evals/cases/` et le declarer dans `Evals:`.
5. Lancer `make eval`.

`make lint` refuse une regle `Active` sans eval declaree, une regle absente de
l'index, un ID indexe qui n'existe dans aucun fichier, et une eval declaree qui
n'existe pas. Une regle non mesuree ne peut donc pas entrer.

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

`should_fail: true` marque un cas qui doit echouer : c'est un controle du harnais
lui-meme, pas du skill.

### Plusieurs regles sur un meme cas

Un cas peut attendre plusieurs findings, y compris issus du meme fichier de
regles. `C11-services-deux-regles` attend `SRV-001` et `SRV-002` sur le meme
fichier source, avec un seul referentiel charge :

```yaml
expected_findings:
  - rule_id: SRV-001
    file: src/main/java/demo/UserManager.java
    message_contains: ["Service"]
  - rule_id: SRV-002
    file: src/main/java/demo/UserManager.java
    message_contains: ["Autowired"]
max_findings: 2
context_expectations:
  exact_files_read:
    - rules/services.rules.md
```

Le pendant est plus interessant : `C12-services-une-regle` charge le meme
referentiel, mais une seule de ses deux regles doit se declencher. La classe est
correctement nommee, seule l'injection est fautive :

```yaml
expected_findings:
  - rule_id: SRV-002
    file: src/main/java/demo/UserService.java
    message_contains: ["Autowired"]
max_findings: 1
```

`max_findings: 1` interdit a `SRV-001` de sortir en plus : un finding
supplementaire depasse le plafond et le cas echoue. C'est la paire
`expected_findings` + `max_findings` qui borne le bruit, sans qu'aucune liste de
regles interdites soit necessaire.

### Choisir un fragment `message_contains`

Un fragment est compare sans accents et sans casse. Viser un jeton stable :

- un jeton de code (`Autowired`, `@PreAuthorize`) est le plus sur;
- un mot de sens stable (`log`, `service`) tient bien;
- une tournure que le modele peut reformuler ou traduire ne tient pas.

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

### Une panne n'est pas une mesure

Quand le CLI ne repond pas — quota epuise (`HTTP 402`), auth, reseau — la trace
porte un `session.error` ou un `model.call_failure`. Le cas est alors rapporte
`ERROR: non mesure`, jamais `FAIL` :

```
C3-must-fail | ERROR: non mesure (quota_exceeded HTTP 402) | ERROR: non mesure
```

La distinction n'est pas cosmetique. Sans elle, une panne se lit comme une
regression du skill sur tous les cas, et un cas `should_fail` vire au **vert** :
rien n'a tourne, donc rien n'a passe, donc l'echec attendu semble observe. Le
controle negatif mentirait exactement quand on en a le plus besoin.

Un cas `ERROR` ne passe jamais le gate et ne satisfait jamais un `should_fail`.

## Reproductibilite : epingler le modele

Le CLI choisit seul le modele, par run. La trace expose l'arbitrage dans
`session.auto_mode_resolved` :

```json
{"chosenModel": "gpt-5-mini", "predictedLabel": "no_reasoning",
 "candidateModels": ["gpt-5-mini", "claude-haiku-4.5"]}
```

Epingler le modele est possible et documente, mais **depend du plan Copilot** :
GitHub a retire la selection manuelle de modele des plans **Free et Student** le
24 juin 2026. Sur ces plans, le mode `auto` est le seul disponible.

Trois mecanismes existent, par ordre de precedence decroissante :

| Mecanisme | Portee |
| --- | --- |
| `--model <nom>` | l'invocation |
| `COPILOT_MODEL=<nom>` | la session |
| cle `"model"` dans `~/.copilot/settings.json` | persistante |

Sur un plan sans selection manuelle, les trois sont inertes : `--model` echoue
avec `Error: Model "<nom>" from --model flag is not available.` pour **tout** nom,
y compris celui que le routeur vient de choisir; `COPILOT_MODEL` et la cle
`model` sont ignores silencieusement, l'auto-routeur se declenchant quand meme.

Consequence tant que le modele n'est pas epingle : deux `make eval` successifs
peuvent mesurer deux modeles differents. Un ecart entre deux runs n'est pas
forcement une regression du skill. Verifier `chosenModel` dans la trace avant
toute conclusion; le harnais mesure alors une photo, pas une tendance.

Pour verifier qu'un epinglage est effectif, ne pas se fier a la seule absence de
`session.auto_mode_resolved` : epingler un modele **different** de celui que
l'auto-routeur choisit, et lire `data.model` sur les evenements
`model.call_failure` ou `tool.execution_start`.

## Repetition : voir la variance

Le modele est stochastique : un `PASS` unique ne dit pas si un cas passe toujours
ou une fois sur trois. `RUNS` joue chaque cas plusieurs fois.

```sh
make eval             # RUNS=1 par defaut
make eval RUNS=5      # chaque cas joue 5 fois
make case CASE=C1-services-violation RUNS=3
```

Par defaut `RUNS=1` : le comportement et la sortie sont ceux d'un run simple, un
ratio `1/1` n'apprendrait rien. Au-dela, le gate rapporte `k/N` :

```
C1-services-violation | 2/3 FAIL: judge: AUCUN FINDING | 2/3 FAIL: attendu [...], observe []
```

Un cas n'est vert que si **toutes** les iterations mesurees passent : un cas
instable doit se voir, `2/3` est une information et non un `PASS`. Les iterations
non mesurees (panne) sont comptees a part et ne sont jamais comptees comme des
succes.

`evals/results/<case-id>/runs.jsonl` porte une ligne par iteration. Les autres
artefacts du repertoire restent ceux de la derniere iteration : ils servent au
diagnostic, pas au comptage.

La repetition multiplie le cout en appels modele. Elle se cible :

```sh
make CASES="C1-services-violation C4-controller-logic" RUNS=5 eval
```

## Cas de rejeu

Un cas qui contient `trace.fixture.jsonl` rejoue cette trace au lieu d'appeler le
CLI. Tout l'aval s'execute normalement : extraction, metriques, selectivite,
validation, juge.

Ce mode sert aux cas qui testent le **harnais** et non le modele : on ne peut pas
demander a un modele de produire a la demande une review volontairement fausse.
`C10-faux-pass` s'en sert pour prouver que le juge sert a quelque chose.
