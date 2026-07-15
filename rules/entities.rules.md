## ENT-001 - Entite persistante minimale
Statut: Candidate
Severite: MOYEN
Detection: entite JPA ajoutee sans identifiant ou avec logique externe au modele de persistance.
Exclusion: DTO, projection, classe non persistante.
Risque: modele de donnees ambigu ou fragile.
Correctif: expliciter l'identifiant et isoler les responsabilites.
Evals: (aucune pour l'instant)
