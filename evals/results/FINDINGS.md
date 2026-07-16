# Calibration - architecture cible code-review-back

> Calibration initiale realisee avec le CLI 1.0.70. Un run ulterieur en 1.0.71 a
> invalide une hypothese implicite de ce document : le modele n'est plus stable
> d'un run a l'autre. Voir « Run 2026-07-16 - CLI 1.0.71 » plus bas.

## Environnement
- Version du CLI : GitHub Copilot CLI 1.0.70.
- Skill cible : `code-review-back`.
- Point d'entree canonique : `skills/code-review-back/SKILL.md`.
- Repertoire enregistre par le CLI : `skills/`.
- Commande de declenchement qui marche :
  `copilot -C . -p "<prompt>" --output-format json --silent --no-custom-instructions --no-remote --disable-builtin-mcps --log-dir evals/results/logs`
- Garde-fous executes avant le gate :
  - `evals/runner/lint-rules.sh`
  - `evals/runner/validate-review.sh <case-id>`
- Commande nominale simplifiee : `make eval`.

## Surface de capture retenue
- Surface retenue : stdout JSONL via `--output-format json`.
- `copilot --help` expose les options utiles.
- Ecart conserve : `copilot -p --help` est interprete comme un prompt, pas comme une aide dediee.

## Declenchement du skill
- `code-review-back` est active.
- Preuve dans `trace.raw` :
  - `session.skills_loaded` contient `code-review-back`.
  - `tool.execution_start` contient `toolName: "skill"` et `arguments.skill: "code-review-back"`.
  - `tool.execution_complete` contient `restrictedProperties.skillName: "code-review-back"`.

## Tokens
- `output_tokens` trouves via `assistant.message.data.outputTokens`.
- `input_tokens` non trouves dans la surface observee.
- Mesures du dernier run Java medium :
  - C1-services-violation : input `null`, output `707`.
  - C2-clean-service : input `null`, output `634`.
  - C3-must-fail : input `null`, output `798`.
  - C4-controller-logic : input `null`, output `982`.
  - C5-security-missing-auth : input `null`, output `999`.
  - C6-dcp-log-sensitive : input `null`, output `704`.
  - C7-medium-controller-clean : input `null`, output `1238`.
  - C8-medium-security-admin : input `null`, output `1287`.
  - C9-medium-dcp-service : input `null`, output `1339`.

## Fichiers lus
- Fichiers lus extraits depuis `tool.execution_start` avec `toolName: "view"` et `data.arguments.path`.
- Les chemins absolus de la trace sont normalises en chemins relatifs.
- `files_read_all` conserve tous les chemins lus via `view`.
- `files_read` conserve le sous-ensemble exploitable pour les references de regles et le skill.
- Si la trace JSON est presente mais qu'aucun appel `view` n'apparait, `files_read` vaut maintenant `[]` au lieu de `null`.
- C1-services-violation a lu exactement :
  - `rules/services.rules.md`
- C1-services-violation a aussi lu le contexte de skill autorise :
  - `skills/code-review-back`
  - `skills/code-review-back/SKILL.md`
- Le fichier temoin interdit `rules/controller.rules.md` n'a pas ete lu dans C1.

## Selectivite
- C1-services-violation : `PASS`.
- C2-clean-service : `PASS`.
- C3-must-fail : `PASS`.
- C4-controller-logic : `PASS`.
- C5-security-missing-auth : `PASS`.
- C6-dcp-log-sensitive : `PASS`.
- C7-medium-controller-clean : `PASS`.
- C8-medium-security-admin : `PASS`.
- C9-medium-dcp-service : `PASS`.
- Le gate ignore les ouvertures de repertoire observees dans `files_read_all` et compare uniquement les fichiers reels.
- Le gate supporte `allowed_files_read` pour les vrais negatifs ou le skill peut legitimement lire zero ou un fichier de regle borne.
- Aucun fichier de regle interdit n'a ete observe dans le run courant.

## Gate
- C1-services-violation : verdict juge `PASS`.
- C2-clean-service : verdict juge `PASS`.
- C3-must-fail : verdict juge `FAIL`, `missed: ["SRV-999"]`.
- C4-controller-logic : verdict juge `PASS`.
- C5-security-missing-auth : verdict juge `PASS`.
- C6-dcp-log-sensitive : verdict juge `PASS`.
- C7-medium-controller-clean : verdict juge `PASS`.
- C8-medium-security-admin : verdict juge `PASS`.
- C9-medium-dcp-service : verdict juge `PASS`.
- Le gate applique correctement `should_fail: true` et rapporte `PASS: echec attendu observe`.
- Le gate combine maintenant verdict LLM + validation deterministe + selectivite.
- Resultat final observe :
  `make gate` retourne `0` avec les neuf cas en `PASS`.

## Enseignements des diffs medium
- Les classes completes augmentent naturellement le nombre de findings sur une meme regle : C8 produit 4 findings `SEC-001`, C9 produit 2 findings `DCP-001`.
- Les fragments `message_contains` doivent viser le sens stable (`log`, `acces`, `service`) plutot qu'un mot exact que le modele peut traduire (`password` vs `mot de passe`).
- Un vrai negatif peut charger aucun fichier de regle ou seulement le fichier de domaine pour verifier l'abstention. `allowed_files_read` couvre ce cas sans autoriser de fichiers hors sujet.
- Un controller de type `OwnerController` avec POST/PUT a ete juge trop ambigu pour un vrai negatif: il declenche naturellement `SEC-001`. Le cas clean utilise donc un controller de catalogue public en lecture seule.

## Run 2026-07-16 - CLI 1.0.71 : routage automatique du modele

Premier `make eval` complet apres la simplification du schema et le recentrage du
juge sur la semantique. Resultat : gate rouge, 6 cas sur 10. Les echecs sont
reels et ne viennent pas du harnais.

### Le modele n'est plus choisi par nous
- La trace expose un evenement `session.auto_mode_resolved` :
  `chosenModel: gpt-5-mini`, `predictedLabel: "no_reasoning"`, `confidence: 0.64`,
  `candidateModels: ["gpt-5-mini", "claude-haiku-4.5"]`.
- Le CLI route donc la requete vers un modele qu'il choisit seul, par run.
- `--model` existe mais **rejette tous les noms testes**, y compris `gpt-5-mini`
  lui-meme (`Error: Model "gpt-5-mini" from --model flag is not available.`),
  avec et sans `--no-remote`. Sur ce compte, l'epinglage est impossible.
- Consequence directe : **les runs ne sont pas reproductibles**. Deux `make eval`
  successifs peuvent mesurer deux modeles differents. C'est la limite la plus
  serieuse du harnais aujourd'hui, et elle n'est pas dans son code.

### Ce que le run mesure reellement
- Le skill est active 10 fois sur 10 (`tool.execution_start` / `toolName: skill`).
- Le contenu de `SKILL.md` est bien remis au modele : `tool.execution_complete`
  contient le `detailedContent` avec les consignes `charger rules/...`.
- Le modele ne lit pourtant les regles que **4 fois sur 10** (`view`).
- Quand il ne les lit pas, il invente les identifiants (`SEC-ADMIN-01`,
  `RGPD-TRACE-DCP-01`, `controller.business-logic`) ou s'abstient : C1 rend
  `AUCUN FINDING` sur une violation `*Manager` evidente.
- C7 lit `rules/mapstruct.rules.md` au lieu de `rules/controller.rules.md`.
- Le chargement selectif de `SKILL.md` n'est donc pas suivi de facon fiable par
  le modele route. C'est exactement ce que l'eval doit detecter.

### Deux bugs du harnais trouves par ce run
- `message_contains: ["acces"]` ne pouvait **jamais** matcher : le modele ecrit
  « acces » avec un accent grave, et `acces` n'est pas une sous-chaine de la
  forme accentuee. C5 et C8 etaient structurellement condamnes. `C8` est un cas
  ou le skill faisait tout correctement et que l'eval rejetait a tort.
  Corrige : `validate-review.sh` compare desormais sans diacritiques des deux
  cotes. Un fragment ne doit pas dependre d'un accent.
- Le prompt du juge etait incoherent sur le `rule_id` : il rejetait C5/C6/C9 pour
  identifiant invente mais laissait passer C4 pour le meme defaut, avec un
  `reasons` vide. Corrige : un `rule_id` absent de `REGLES` est un FAIL sans
  exception, et `reasons` ne peut jamais etre vide.

### Le juge a prouve son utilite sur ce run
- `C8` : le juge a rendu PASS quand la validation deterministe rendait FAIL. Le
  juge avait raison, le deterministe se trompait (bug d'accent ci-dessus). C'est
  un faux FAIL du deterministe rattrape par le juge, en conditions reelles.
- `C5`/`C6`/`C9` : le deterministe dit `missing: SEC-001`. Le juge dit « le
  finding decrit correctement la violation mais cite `SEC-ADMIN-01` au lieu de
  `SEC-001` ». Le second diagnostic est actionnable, le premier non.
- `C10-faux-pass` : le juge a rejete la fausse conformite en citant le texte de
  la regle injectee et en distinguant explicitement `Detection` et `Exclusion`.

## Run 2026-07-16 (2) - quota epuise : une panne n'est pas une mesure

Campagne a 12 cas lancee apres l'ajout de `SRV-002`, `C11` et `C12`. Le quota
mensuel Copilot s'est epuise en cours de route, apres `C10`, `C11`, `C12` et la
review de `C1`.

- Signature exacte : `session.error` avec `errorCode: quota_exceeded`,
  `statusCode: 402`, `message: "You have exceeded your monthly quota"`; et
  `model.call_failure` avec le meme statut. `result.usage.totalApiDurationMs`
  vaut `0` : la requete n'a jamais atteint le modele.
- Le harnais rapportait alors `FAIL` sur les 8 cas non joues. Une panne
  d'infrastructure se lisait donc comme une regression du skill.
- Pire : `C3-must-fail` est passe **au vert** (`PASS: echec attendu observe`).
  Rien n'avait tourne, donc rien n'avait passe, donc l'echec attendu semblait
  observe. Le controle negatif mentait exactement quand il fallait s'y fier.

Corrige : `extract-trace.sh` remonte `run_error` depuis `session.error` et
`model.call_failure`; `run-judge.sh` distingue « le juge rejette » de « le juge
n'a pas pu tourner »; `gate.sh` court-circuite le cas en `ERROR: non mesure`. Un
cas `ERROR` ne passe jamais le gate et ne satisfait jamais un `should_fail`.
Verifie en rejouant les traces de quota reelles de ce run : `C3` passe de vert a
`ERROR`.

Mesures valides de ce run, avant epuisement :

- `C11-services-deux-regles` : PASS / PASS. Les deux regles de
  `rules/services.rules.md` se declenchent sur le meme fichier source, un seul
  referentiel charge.
- `C12-services-une-regle` : PASS / PASS. Meme referentiel charge, seule
  `SRV-002` se declenche; `SRV-001` s'abstient correctement sur une classe bien
  nommee. `max_findings: 1` aurait fait echouer le cas si elle etait sortie.
- `C10-faux-pass` : echec attendu observe via le juge.

## Le modele etait la variable explicative, pas le skill

Recoupement des deux campagnes apres coup, en lisant `data.model` dans les traces
conservees. Les deux runs n'ont pas tourne sur le meme modele, et c'est
l'auto-routeur qui en a decide seul :

| Campagne | Modele route | Regles chargees | C1 |
| --- | --- | --- | --- |
| Run 1 | `gpt-5-mini` | 4 cas sur 10 | `AUCUN FINDING`, violation `*Manager` ratee |
| Run 2 | `claude-haiku-4.5` | 3 sur 3 des cas joues avant le quota | `SRV-001` trouvee |

La conclusion « le skill ne charge ses regles que 4 fois sur 10 » etait donc une
propriete de `gpt-5-mini`, pas du skill. Sous `claude-haiku-4.5`, les trois cas
reels joues (`C1`, `C11`, `C12`) ont charge le bon referentiel et passe la
validation deterministe.

Portee a ne pas surestimer : le run 2 n'a mesure que 3 cas avant l'epuisement du
quota, et rien sur les domaines controller, securite et DCP. Le contraste est net
mais l'echantillon est petit. Ce qui est etabli, c'est que **le modele domine la
mesure** : attribuer un ecart au skill sans lire `data.model` dans la trace est
une erreur d'attribution.

C'est pour cela que le harnais epingle desormais le modele (`MODEL`), consigne
celui qui a reellement tourne (`metrics.model`) et refuse la mesure en `ERROR`
quand l'epinglage ne prend pas.

## Epinglage du modele : possible, mais pas sur un plan Free

Enquete menee apres le run 2, CLI 1.0.71.

Ce qui est documente par GitHub :

- La selection manuelle de modele a ete **retiree des plans Free et Student** le
  24 juin 2026. Sur ces plans, `auto` est le seul mode disponible.
  <https://github.blog/changelog/2026-06-24-changes-to-model-selection-for-free-and-student-plans/>
- Sur Pro et au-dessus, trois mecanismes existent, par precedence decroissante :
  `--model <nom>`, la variable `COPILOT_MODEL`, puis la cle `"model"` de
  `~/.copilot/settings.json`.
  <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference>
- En Business/Enterprise, un admin peut desactiver des modeles au niveau
  organisation, ce qui reproduit le meme blocage.
  <https://docs.github.com/en/copilot/how-tos/copilot-cli/administer-copilot-cli-for-your-enterprise>
- La liste des noms valides n'est pas publiee. La doc renvoie vers `copilot help`
  et vers `/model` en interactif. Verifie : sur 1.0.71, `copilot help` ne liste
  aucun nom, il affiche seulement `--model <model>  Set the AI model to use`.

Ce qui est observe sur ce compte, les trois mecanismes etant inertes :

- `--model <nom>` echoue avec `Error: Model "<nom>" from --model flag is not
  available.` pour **tout** nom essaye (`gpt-5.4`, `gpt-5`, `gpt-5.1`,
  `gpt-5-mini`, `gpt-5-codex`, `claude-sonnet-4`, `claude-sonnet-4.5`,
  `claude-sonnet-4.6`, `claude-haiku-4.5`), avec et sans `--no-remote` — y
  compris `gpt-5-mini`, que l'auto-routeur choisit a chaque run.
- `COPILOT_MODEL=<nom>` est ignore silencieusement : meme une valeur invalide ne
  produit aucune erreur et `session.auto_mode_resolved` se declenche quand meme.
- La cle `"model"` de `~/.copilot/settings.json` est ignoree : avec
  `"model": "claude-haiku-4.5"`, l'auto-routeur se declenche et resout vers
  `gpt-5-mini`, et `model.call_failure` confirme que `gpt-5-mini` est bien le
  modele appele.

Ce n'est pas le quota qui cause ce rejet : `--model` echouait deja alors que le
quota etait sain (le run 1 complet et les cas C11/C12 ont tourne apres ces
tests). Le faisceau — rejet de tout nom + `402 quota_exceeded` — pointe vers un
plan Free.

Piege de methode rencontre : un premier test a montre `session.auto_mode_resolved`
absent avec une cle `model` posee, ce qui ressemblait a un epinglage reussi.
C'etait un faux positif d'un tirage unique. Pour conclure, il faut epingler un
modele **different** de celui que l'auto-routeur choisit, et lire `data.model` sur
`model.call_failure` — pas se fier a l'absence d'un evenement.

Consequence : l'epinglage n'est pas un chantier de code cote harnais, c'est un
changement de plan. Le harnais est pret : `MODEL` (defaut `claude-haiku-4.5`) est
passe en `--model` a la review et au juge, `metrics.model` consigne le modele
reellement observe, et le gate refuse la mesure en `ERROR` si l'epinglage ne
prend pas. Sur un plan Free, ce garde-fou fera sortir tous les cas en
`ERROR: non mesure (cli_sans_trace)` plutot que de mesurer silencieusement autre
chose que ce qui est demande.

Reste a faire sur Pro : confirmer les noms valides avec `/model` en interactif,
puis re-etalonner. Les mesures d'avant l'epinglage ne sont pas comparables entre
elles.

## Consequences pour le vrai harnais
- Transposable tel quel : structure `rules/`, point d'entree `skills/code-review-back/SKILL.md`, cas sous `evals/cases/`, traces sous `evals/results/`.
- Transposable tel quel : selectivite par `context_expectations.exact_files_read` ou `allowed_files_read`.
- Transposable tel quel : validation deterministe des invariants mecaniques de review.
- Transposable tel quel : lint de coherence minimal `rules/index.md` -> fichiers -> evals actifs.
- A adapter : enrichir `rules/*.rules.md` avec les vraies regles et completer `rules/index.md`.
- A adapter : durcir `evals/judge.prompt.md` pour les criteres metier reels.
- A resoudre en priorite : epingler le modele. Tant que le CLI route seul, le
  harnais compare des runs qui n'ont pas mesure le meme systeme. Aucune
  conclusion de tendance n'est solide avant ca. Ce n'est pas un chantier de
  code : la selection manuelle est retiree des plans Free/Student depuis le
  24 juin 2026. Voir « Epinglage du modele » plus haut.
- En attendant, `RUNS=<k>` rend la variance visible : un cas instable sort en
  `2/3` au lieu de se presenter comme un `PASS` ou un `FAIL` franc. C'est un
  palliatif, pas un substitut a l'epinglage : ca mesure la dispersion sans
  garantir qu'on mesure le meme modele d'un run a l'autre.
- Limite actuelle : input tokens indisponibles avec la surface CLI observee.
