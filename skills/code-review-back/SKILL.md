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
- Controleur, endpoint HTTP, `Controller`, `RestController` -> charger `rules/controller.rules.md`.
- Entite JPA, `Entity`, table persistante -> charger `rules/entities.rules.md`.
- Mapper, `@Mapper`, conversion DTO -> charger `rules/mapstruct.rules.md`.
- Migration SQL, Flyway, fichier `V*.sql` -> charger `rules/flyway.rules.md`.
- Producteur/consommateur, Kafka, message, event -> charger `rules/producer-consumer.rules.md`.
- Test, spec, fixture -> charger `rules/testing.rules.md`.
- Authentification, autorisation, secret, permission -> charger `rules/security.rules.md`.
- Donnee personnelle, trace, DCP, RGPD -> charger `rules/rgpd-trace-dcp.rules.md`.
- Frontiere de couche, dependance inter-module -> charger `rules/architecture.rules.md`.

Ne jamais charger deux fichiers de regles si un seul domaine est concerne.
Ne pas charger `rules/index.md` pendant une review sauf si le mapping d'ID est ambigu.

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
