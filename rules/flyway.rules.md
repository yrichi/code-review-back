## FLY-001 - Migration Flyway atomique
Statut: Candidate
Severite: MOYEN
Detection: migration qui melange changements de schema independants.
Exclusion: migration de bootstrap explicitement acceptee.
Risque: rollback et diagnostic plus difficiles.
Correctif: separer les changements en migrations atomiques.
Evals: (aucune pour l'instant)
