## SRV-001 - Nom de service explicite
Statut: Active
Severite: MINEUR
Detection: classe de service applicatif ajoutee dont le nom se termine par `Manager` au lieu de `Service`.
Exclusion: classe non modifiee par le diff ; type technique qui n'est pas un service applicatif.
Risque: role applicatif moins lisible et conventions d'architecture plus difficiles a verifier.
Correctif: renommer en `*Service` si la classe porte une logique de service.
Exemple a signaler: `public class UserManager`
Exemple a ne pas signaler: `public class UserService`
Evals: C1-services-violation, C3-must-fail, C11-services-deux-regles

## SRV-002 - Injection par constructeur
Statut: Active
Severite: MOYEN
Detection: service applicatif ajoute dont une dependance est injectee sur un champ annote `@Autowired` au lieu de passer par le constructeur.
Exclusion: champ de configuration `@Value` ; classe de test.
Risque: dependances masquees, classe non instanciable sans conteneur, tests plus difficiles a ecrire.
Correctif: injecter la dependance via un constructeur et rendre le champ `final`.
Exemple a signaler: `@Autowired private UserRepository repository;`
Exemple a ne pas signaler: `public UserService(UserRepository repository) { this.repository = repository; }`
Evals: C11-services-deux-regles, C12-services-une-regle
