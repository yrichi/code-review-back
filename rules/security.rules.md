## SEC-001 - Controle d'acces explicite
Statut: Active
Severite: ELEVE
Detection: nouveau point d'entree sensible modifiant ou exposant une ressource sans controle d'acces visible (`@PreAuthorize`, `@Secured`, configuration equivalente ou justification explicite).
Exclusion: endpoint public explicitement documente.
Risque: exposition non autorisee.
Correctif: ajouter ou documenter le controle d'acces.
Exemple a signaler: `@DeleteMapping("/users/{id}")` sans annotation de securite.
Exemple a ne pas signaler: `@PreAuthorize("hasRole('ADMIN')")` sur le endpoint.
Evals: C5-security-missing-auth, C8-medium-security-admin
