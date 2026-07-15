## CTL-001 - Controleur sans logique metier directe
Statut: Candidate
Severite: MOYEN
Detection: controleur ajoutant de la logique metier substantielle au lieu de deleguer a un service.
Exclusion: mapping HTTP, validation d'entree, assemblage DTO minimal.
Risque: couplage presentation/metier et tests plus fragiles.
Correctif: deplacer la logique dans un service applicatif.
Evals: (aucune pour l'instant)
