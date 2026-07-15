## MAP-001 - Mapper MapStruct explicite
Statut: Candidate
Severite: MINEUR
Detection: mapper MapStruct ajoutant des conversions implicites non documentees.
Exclusion: mappings directs champ-a-champ.
Risque: transformations silencieuses difficiles a auditer.
Correctif: declarer les mappings non triviaux.
Evals: (aucune pour l'instant)
