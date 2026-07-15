# code-review-back

Squelette de skill de revue backend avec references de regles et harnais
d'evaluation local.

Ce banc d'essai teste cinq points :

1. Declenchement non interactif d'un skill precis via `copilot -p`.
2. Capture de la review, de la trace brute, des tokens et des fichiers lus quand le CLI les expose.
3. Verdict LLM parsable via un juge appele lui aussi en `copilot -p`.
4. Selectivite du contexte : un cas service ne doit charger que `rules/services.rules.md`.
5. Gate negatif : `C3-must-fail` doit faire echouer le gate si le harnais mesure vraiment.

## Commandes

```sh
make -C eval-skeleton eval
make -C eval-skeleton case CASE=C1-services-violation
make -C eval-skeleton context
make -C eval-skeleton clean
```

`make eval` est le chemin nominal : `setup`, `lint`, execution des cas, juge,
validation deterministe, puis gate. Les cas sont decouverts automatiquement sous
`evals/cases/`.

## Integrer un vrai skill

Le harnais suit les conventions de ce repo sans fichier de configuration :

- skill : `skills/code-review-back/SKILL.md`
- regles : `rules/*.rules.md`
- cas : `evals/cases/<case-id>/`
- resultats : `evals/results/`

Pour un skill base sur references, place les documents sous le repertoire du
skill ou sous `rules/`, declare les cas sous `evals/cases/`, puis exprime les attentes de contexte dans
`expected.yml` avec `context_expectations.exact_files_read` et
`forbidden_files_read`. Pour un vrai negatif ou le skill peut legitimement lire
zero ou un fichier de domaine, utilise `allowed_files_read`.

Guide complet : `docs/INTEGRATION.md`.

## Sorties

Chaque cas produit dans `evals/results/<case-id>/` :

- `review.txt` : sortie texte du modele pour la review.
- `trace.raw` : trace brute disponible.
- `meta.json` : commande executee et surface de capture retenue.
- `metrics.json` : tokens, fichiers lus, skill active si ces champs existent dans la trace.
- `verdict.json` : verdict JSON du juge.
- `review-check.json` : validation deterministe des invariants mecaniques.

Le gate exige, pour les cas non `should_fail`, que le juge, la validation
deterministe et la selectivite passent tous.

Le fichier `evals/results/FINDINGS.md` contient la calibration factuelle du premier run reel.

## Limites connues

Les scripts capturent `copilot --help`, mais ne lancent pas `copilot -p --help`
car ce CLI l'interprete comme un prompt. Si aucun flux JSON ou journal
exploitable n'est observe, les mesures de tokens et fichiers lus restent `null`
avec une note explicite.
