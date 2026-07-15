## CTL-001 - Controleur sans logique metier directe
Statut: Active
Severite: MOYEN
Detection: controleur ajoutant de la logique metier substantielle au lieu de deleguer a un service.
Exclusion: mapping HTTP, validation d'entree, assemblage DTO minimal.
Risque: couplage presentation/metier et tests plus fragiles.
Correctif: deplacer la logique dans un service applicatif.
Exemple a signaler: `@PostMapping` puis calcul ou mutation metier directement dans le controller.
Exemple a ne pas signaler: controller qui delegue a un service.
Evals: C4-controller-logic, C7-medium-controller-clean
