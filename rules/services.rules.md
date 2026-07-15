## SRV-001 - Nom de service explicite
Statut: Active
Severite: MINEUR
Detection: classe de service applicatif ajoutee dont le nom se termine par `Manager` au lieu de `Service`.
Exclusion: classe non modifiee par le diff ; type technique qui n'est pas un service applicatif.
Risque: role applicatif moins lisible et conventions d'architecture plus difficiles a verifier.
Correctif: renommer en `*Service` si la classe porte une logique de service.
Exemple a signaler: `public class UserManager`
Exemple a ne pas signaler: `public class UserService`
Evals: C1-services-violation, C3-must-fail
