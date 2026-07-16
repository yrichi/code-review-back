# Changelog

Toutes les modifications notables de ce projet seront documentees ici.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/)
et le versionnement suit SemVer.

## [Non publie]

### Ajoute (cadre d'evaluation)

- `MODEL=<nom>` (defaut `claude-haiku-4.5`) : epingle le modele et le passe en
  `--model` a la review et au juge. `MODEL=` vide laisse le routage automatique.
  Requiert un plan Copilot Pro.
- `metrics.model` et `metrics.models_observed` : le modele reellement observe
  dans la trace. Le gate compare a `MODEL` et refuse la mesure en
  `ERROR: epinglage non effectif` si elle ne correspond pas, ou en
  `ERROR: epinglage non verifiable` si le modele n'est pas observable ou si
  plusieurs modeles apparaissent sur le meme run. C'est un `ERROR` et non un
  `FAIL`: un epinglage qui ne prend pas est un probleme de configuration, pas
  une regression du skill. Les cas de rejeu en sont exemptes: leur review est
  figee, elle ne mesure aucun modele.
- `extract-trace.sh` rapporte `run_error: cli_sans_trace` quand la trace est
  vide: le CLI n'a pas demarre (nom de modele refuse, auth). Sans cela, un
  `--model` rejete se lisait comme un echec du skill.

### Corrige (attribution des mesures)

- Le diagnostic « le skill ne charge ses regles que 4 fois sur 10 » etait une
  erreur d'attribution : les deux campagnes n'ont pas tourne sur le meme modele.
  Le run 1 a ete route vers `gpt-5-mini` (4 chargements sur 10, `C1` rendant
  `AUCUN FINDING`), le run 2 vers `claude-haiku-4.5` (3 chargements sur 3 des
  cas joues, `C1` trouvant `SRV-001`). Le modele domine la mesure. `FINDINGS.md`
  et la presentation portent le recoupement.

- `RUNS=<k>` (defaut 1) : joue chaque cas k fois via `evals/runner/run-case.sh`,
  qui consigne une ligne par iteration dans `runs.jsonl`. Le gate agrege en
  `k/N`; un cas n'est vert que si toutes les iterations mesurees passent, et les
  iterations en panne sont comptees a part. A `RUNS=1`, la sortie et les
  artefacts sont inchanges. Le modele etant stochastique, un PASS unique ne
  distingue pas un cas stable d'un cas qui passe une fois sur trois.
- `FINDINGS.md` documente l'enquete sur l'epinglage du modele : la selection
  manuelle est retiree des plans Free/Student depuis le 24 juin 2026, et les
  trois mecanismes (`--model`, `COPILOT_MODEL`, cle `model` de
  `~/.copilot/settings.json`) sont inertes sur ce compte. L'epinglage est un
  changement de plan, pas un chantier de code.

- Distinction entre un echec mesure (`FAIL`) et une panne (`ERROR: non mesure`).
  `extract-trace.sh` remonte `run_error` depuis `session.error` et
  `model.call_failure`, `run-judge.sh` distingue « le juge rejette » de « le juge
  n'a pas pu tourner », et `gate.sh` court-circuite le cas en `ERROR`. Sans cette
  separation, un quota epuise se lisait comme une regression du skill sur tous
  les cas, et un cas `should_fail` virait au vert : rien n'avait tourne, donc
  rien n'avait passe, donc l'echec attendu semblait observe. Un cas `ERROR` ne
  passe jamais le gate et ne satisfait jamais un `should_fail`.

- Regle `SRV-002` (injection par constructeur) dans `rules/services.rules.md` :
  un fichier de regles porte desormais plusieurs regles du meme domaine. C'est le
  fichier que le skill charge, donc deux regles qu'un meme diff peut declencher
  ensemble doivent y vivre ensemble.
- Cas `C11-services-deux-regles` : deux regles du meme referentiel se declenchent
  sur le meme fichier source, avec un seul fichier charge.
- Cas `C12-services-une-regle` : meme referentiel charge, une seule des deux
  regles doit se declencher. Mesure la discrimination entre regles voisines, et
  montre que `max_findings` borne le bruit sans enumerer d'interdits.
- `lint-rules.sh` decoupe les fichiers par titre `## ID - Titre` et linte chaque
  regle separement. Il verifie en plus qu'un ID indexe existe dans un fichier,
  qu'une regle est definie dans le fichier ou l'index la place, et qu'une eval
  declaree existe reellement.

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
