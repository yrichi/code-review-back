## DCP-001 - Trace DCP/RGPD minimisee
Statut: Active
Severite: ELEVE
Detection: trace ajoutant une donnee personnelle ou sensible brute.
Exclusion: identifiant technique non personnel, donnee masquee.
Risque: fuite de donnees dans les journaux.
Correctif: masquer, pseudonymiser ou supprimer la donnee tracee.
Exemple a signaler: `log.info("password={}", password)` ou `log.info("email={}", email)`.
Exemple a ne pas signaler: `log.info("userId={}", userId)` si `userId` est un identifiant technique non personnel.
Evals: C6-dcp-log-sensitive
