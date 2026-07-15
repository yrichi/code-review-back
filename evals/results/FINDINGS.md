# Calibration - architecture cible code-review-back

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

## Consequences pour le vrai harnais
- Transposable tel quel : structure `rules/`, point d'entree `skills/code-review-back/SKILL.md`, cas sous `evals/cases/`, traces sous `evals/results/`.
- Transposable tel quel : selectivite par `context_expectations.exact_files_read`, `allowed_files_read` et `forbidden_files_read`.
- Transposable tel quel : validation deterministe des invariants mecaniques de review.
- Transposable tel quel : lint de coherence minimal `rules/index.md` -> fichiers -> evals actifs.
- A adapter : enrichir `rules/*.rules.md` avec les vraies regles et completer `rules/index.md`.
- A adapter : durcir `evals/judge.prompt.md` pour les criteres metier reels.
- Limite actuelle : input tokens indisponibles avec la surface CLI observee.
