# code-review-back

Squelette de skill de revue backend avec references de regles et harnais
d'evaluation local.

Le cadre existe pour une seule raison : faire evoluer un skill a references sans
regresser, en mesurant ce qu'il fait vraiment plutot que ce qu'on croit qu'il fait.

Il mesure six points :

1. Declenchement non interactif d'un skill precis via `copilot -p`.
2. Capture de la review, de la trace brute, des tokens et des fichiers lus quand le CLI les expose.
3. Justesse des findings : les invariants mecaniques par un check deterministe, la validite du contenu par un juge LLM.
4. Bruit : la review ne signale pas plus que ce que le cas autorise.
5. Selectivite du contexte : un cas service ne doit charger que `rules/services.rules.md`, et savoir discriminer entre les regles qu'il y trouve.
6. Controles negatifs : `C3-must-fail` prouve que le harnais detecte les regressions, `C10-faux-pass` prouve que le juge juge encore.

## Qui juge quoi

Deux oracles complementaires, sans recouvrement volontaire :

- `review-check.json` tranche le **mecanique** : le `rule_id`, le fichier et les
  fragments attendus sont-ils presents, le nombre de findings tient-il sous
  `max_findings` ? C'est un matcher de sous-chaines : deterministe et gratuit,
  mais aveugle au sens.
- `verdict.json` tranche le **semantique** : le finding affirme-t-il vraiment une
  violation, la justification correspond-elle a la `Detection` de la regle citee
  et non a une `Exclusion` ? Une review peut citer `SRV-001`, le bon fichier et
  le bon fragment tout en concluant « rien a signaler » : elle satisfait le
  mecanique et seul le juge peut la rejeter.

Le gate exige les deux. `C10-faux-pass` est le controle negatif du juge : il
rejoue une review mecaniquement irreprochable mais semantiquement fausse, et
vire au rouge si le juge la laisse passer.

## Commandes

```sh
make eval
make case CASE=C1-services-violation
make context
make clean
```

`make eval` est le chemin nominal : `setup`, `lint`, execution des cas, juge,
validation deterministe, puis gate. Les cas sont decouverts automatiquement sous
`evals/cases/`.

## Integrer un vrai skill

Le harnais suit les conventions de ce repo sans fichier de configuration :

- skill : `skills/code-review-back/SKILL.md`
- regles : `rules/*.rules.md`
- cas : `evals/cases/<case-id>/` (`input.diff` + `expected.yml`)
- resultats : `evals/results/`

Un cas peut fournir `trace.fixture.jsonl` : cette trace est alors rejouee au lieu
d'appeler le CLI, tout l'aval s'executant normalement. Ce mode sert aux cas qui
testent le harnais et non le modele, comme `C10-faux-pass`.

Pour un skill base sur references, place les documents sous le repertoire du
skill ou sous `rules/`, declare les cas sous `evals/cases/`, puis exprime les
attentes de contexte dans `expected.yml` avec
`context_expectations.exact_files_read`. Pour un vrai negatif ou le skill peut
legitimement lire zero ou un fichier de domaine, utilise `allowed_files_read`.

Un `expected.yml` tient en trois axes : `expected_findings` (justesse),
`max_findings` (bruit) et `context_expectations` (selectivite).

Un fichier de regles porte toutes les regles de son domaine : c'est lui que le
skill charge, donc deux regles qu'un meme diff peut declencher ensemble doivent y
vivre ensemble. `rules/services.rules.md` porte `SRV-001` et `SRV-002`;
`C11-services-deux-regles` verifie que les deux se declenchent,
`C12-services-une-regle` qu'une seule sort quand une seule s'applique.

`make lint` refuse une regle `Active` sans eval declaree, une regle absente de
l'index, un ID indexe qui n'existe dans aucun fichier, et une eval declaree
introuvable. Une regle non mesuree ne peut pas entrer.

Guide complet : `docs/INTEGRATION.md`.

Presentation equipe : ouvrir `docs/presentation.html` dans un navigateur.

## Sorties

Chaque cas produit dans `evals/results/<case-id>/` :

- `review.txt` : sortie texte du modele pour la review.
- `trace.raw` : trace brute disponible.
- `meta.json` : commande executee et surface de capture retenue.
- `metrics.json` : tokens, fichiers lus, skill active si ces champs existent dans la trace.
- `verdict.json` : verdict JSON du juge sur la validite semantique des findings.
- `review-check.json` : validation deterministe des invariants mecaniques
  (`rule_id`, fichier, fragments, `max_findings`).

Le gate exige, pour les cas non `should_fail`, que le juge, la validation
deterministe et la selectivite passent tous.

Le fichier `evals/results/FINDINGS.md` contient la calibration factuelle du dernier run reel documente.

## Limites connues

Les scripts capturent `copilot --help`, mais ne lancent pas `copilot -p --help`
car ce CLI l'interprete comme un prompt. Si aucun flux JSON ou journal
exploitable n'est observe, les mesures de tokens et fichiers lus restent `null`
avec une note explicite.
