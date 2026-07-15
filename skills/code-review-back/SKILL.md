---
name: code-review-back
description: Skill de revue backend qui analyse un diff et charge selectivement les references de regles backend.
---

# code-review-back

Mission: analyser le diff fourni et signaler uniquement les violations des regles chargees.

Les chemins `rules/...` ci-dessous sont relatifs a la racine du depot courant,
pas au repertoire de ce skill.

Chargement selectif obligatoire:

- Service applicatif, classe `*Service` ou `*Manager` -> charger `rules/services.rules.md`.
- Controleur avec logique metier directe dans une methode HTTP -> charger `rules/controller.rules.md`.
- Endpoint sensible d'administration, suppression, permission, authentification ou autorisation -> charger `rules/security.rules.md`.
- Entite JPA, `Entity`, table persistante -> charger `rules/entities.rules.md`.
- Mapper, `@Mapper`, conversion DTO -> charger `rules/mapstruct.rules.md`.
- Migration SQL, Flyway, fichier `V*.sql` -> charger `rules/flyway.rules.md`.
- Producteur/consommateur, Kafka, message, event -> charger `rules/producer-consumer.rules.md`.
- Test, spec, fixture -> charger `rules/testing.rules.md`.
- Donnee personnelle ou sensible dans une trace/log (`password`, `email`, DCP, RGPD) -> charger `rules/rgpd-trace-dcp.rules.md`.
- Frontiere de couche, dependance inter-module -> charger `rules/architecture.rules.md`.

Ne jamais charger deux fichiers de regles si un seul domaine est concerne.
Ne pas charger `rules/index.md` pendant une review sauf si le mapping d'ID est ambigu.
Si plusieurs domaines semblent possibles, choisis le domaine le plus specifique pour le risque principal du diff et charge un seul fichier de regle.

Format de sortie strict:

```text
- [<fichier>:L<ligne>] <probleme> -> <correctif>. (<RULE-ID>)
```

S'il n'y a aucun probleme, repondre exactement:

```text
AUCUN FINDING
```

Regle d'abstention: en cas de doute, ne pas signaler.

Ne produis aucun autre texte.
