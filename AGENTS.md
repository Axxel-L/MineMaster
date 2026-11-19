# AGENTS.md — MineMaster

Instructions obligatoires pour toute IA ou agent qui travaille sur ce dépôt.
Elles priment sur les habitudes générales de l'outil. Le non-respect d'une règle
bloquante doit être signalé avant toute modification.

## 0. Lecture obligatoire

Avant de répondre ou de modifier quoi que ce soit :

1. Lire et appliquer `.kilo/skills/caveman/SKILL.md` à chaque réponse.
   La voix caveman est le mode de communication par défaut, sans exception,
   jusqu'à ce que l'utilisateur écrive « stop caveman » ou « normal mode ».
2. Lire `README.md` pour la stack et l'architecture.
3. Lire `docs/CAHIER_DES_CHARGES.md` si la demande touche une fonctionnalité,
   une règle de jeu, la sécurité ou les données.
4. Lire les fichiers concernés avant de les modifier.

Deux publics, deux documents :

- Documentation du code : pour les humains. En français, dans le code, avec
  les commentaires de documentation Swift (`///`).
- Documentation projet : pour les IA et agents. Dans `AGENTS.md`, `README.md`
  et `docs/`. Elle décrit les règles, les invariants et les procédures.

## 1. Priorités

Dans l'ordre, en cas de conflit :

1. Sécurité.
2. Exactitude fonctionnelle.
3. Fluidité et performance.
4. Compacité du code.
5. Vitesse d'écriture.

Le code doit être optimisé, fluide, compact et surtout sécurisé. Une ligne en
moins ne justifie jamais une faille, une course, une perte de données ou un
résultat faux.

## 2. Règles de code

- Swift 6, concurrence stricte, isolation `MainActor` par défaut.
- SwiftUI, SwiftData, `URLSession`. Aucune dépendance tierce.
- Pas de code mort, pas de duplication, pas d'abstraction sans usage réel.
- Pas de `try?` qui masque une erreur métier. Une erreur attendue est modélisée
  par `AppError`, jamais avalée.
- Pas de force unwrap sur une donnée réseau, utilisateur ou persistée.
  Les `!` existants sur les constantes littérales vérifiées sont tolérés.
- Pas de `@unchecked Sendable`, pas de `nonisolated(unsafe)` sans justification
  écrite dans la revue.
- Toute entrée externe est validée : schéma, hôte, chemin, type MIME, taille.
- Aucun secret, jeton ou donnée personnelle dans le code, les logs ou le dépôt.
- Réseau : HTTPS uniquement, allowlist d'hôtes, charges utiles bornées.

### Commentaires

- Aucun commentaire libre dans les fichiers de code.
- Seule la documentation d'API est autorisée, en Swift DocC (`///`), en français,
  avec les balises utiles :
  `- Parameter`, `- Parameters`, `- Returns`, `- Throws`, `- Complexity`,
  `- Authors: Axel L.`
- La documentation du code s'adresse aux humains : elle explique le contrat,
  les invariants, les erreurs et la complexité, pas l'implémentation ligne à ligne.
- Les commentaires existants non demandés ne sont ni supprimés, ni raccourcis.

Exemple conforme :

```swift
/// Fabrique un item absent de la collection en dépensant de la poussière.
///
/// - Parameter item: Item à fabriquer.
/// - Returns: `true` si la fabrication a abouti.
/// - Authors: Axel L.
@discardableResult
func craft(_ item: CatalogItem) -> Bool
```

## 3. Git

- Commits conventionnels, en français, à l'impératif.
- Préfixes autorisés : `feat:`, `fix:`, `core:`, `test:`, `docs:`.
- `core:` pour l'infrastructure, la configuration, l'outillage et les refactors
  transverses. `test:` pour les tests seuls. `docs:` pour la documentation seule.
- Un commit = une intention. Le sujet fait moins de 72 caractères.
- Détails dans le corps si le changement n'est pas évident.
- Ne jamais committer sans demande explicite.
- Ne jamais committer un secret, un fichier `xcuserdata`, `DerivedData` ou `build`.

Exemples :

```text
feat: verrouiller l'ouverture à un booster à la fois
fix: empêcher le double gain de poussière sur un doublon
core: injecter la session réseau dans ImagePipeline
test: couvrir les invariants de poussière et de fabrication
```

## 4. Tests

Les tests sont obligatoires. Toute modification de comportement ajoute ou met à
jour au moins un test. Une modification sans test est refusée, sauf documentation
pure. Un test qui échoue ne se contourne pas : on corrige le code ou le contrat.

### 4.1 Cible et outils

- Cible : `MineMasterTests`, tests unitaires hébergés par l'application
  (`TEST_HOST`), pour accéder au bundle et à `@testable import MineMaster`.
- Framework : Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`,
  `#require`). Ne pas mélanger avec XCTest sans raison.
- SwiftData : conteneur en mémoire uniquement.
  Jamais la base réelle de l'utilisateur.
- Réseau : jamais réel dans un test unitaire. Utiliser une `URLSession` injectée
  avec un `URLProtocol` de test.
- Aléatoire : jamais `SystemRandomNumberGenerator` dans un test. Injecter un
  générateur déterministe.
- Aucun `sleep`. Aucune dépendance à l'ordre d'exécution. Aucun état partagé
  entre suites.

### 4.2 Commandes

```bash
xcodebuild -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'generic/platform=iOS Simulator' build

xcodebuild test -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=<simulateur installé>'
```

Le build et les tests doivent passer avant de rendre le travail.

### 4.3 Organisation

```text
MineMasterTests/
├─ Support/     générateur déterministe, fixtures, URLProtocol de test, makeStore()
├─ Domain/      LootEngine, Rarity, Booster, ImagePolicy, SeedCatalog
├─ Data/        GameStore, ImagePipeline, CatalogAPI, Records
└─ Features/    verrous d'ouverture et de fabrication
```

Conventions :

- Nom de suite : `@Suite("Ouverture des boosters")`.
- Nom de test : phrase française décrivant l'invariant, pas le nom de la méthode.
- Structure : Arrange, Act, Assert.
- Un test vérifie un invariant. Plusieurs `#expect` acceptés si le même scénario.
- Les fixtures sont minimales et nommées. Pas de JSON de 99 items si 3 suffisent.
- Chaque test doit échouer si l'invariant est cassé. Vérifier ce point en cassant
  volontairement le code une fois, localement.

### 4.4 Créer un nouveau test

1. Identifier l'invariant métier ou de sécurité, pas la fonction.
2. Choisir la suite existante la plus proche. Créer une suite seulement si le
   domaine est nouveau.
3. Construire les dépendances injectables : générateur, session, conteneur.
4. Écrire le cas nominal, puis au moins un cas limite et un cas d'échec.
5. Lancer la cible de tests et vérifier que le test échoue sans le correctif.
6. Committer avec `test:` si les tests sont seuls, sinon avec le préfixe du
   changement.

Un test qui ne peut pas être écrit révèle une dépendance non injectable.
Corriger l'architecture avant d'ajouter le test, pas après.

### 4.5 Invariants couverts

Les invariants suivants sont obligatoires et doivent rester couverts.

**Ouverture des boosters**

- Quatre appuis rapides sur « Ouvrir » produisent une seule ouverture :
  un seul `OpeningRecord`, cinq items, poussière comptée une seule fois.
- Un seul booster peut être ouvert à la fois. Tant que la session courante
  n'est pas fermée, toute nouvelle ouverture est refusée. Après fermeture,
  l'ouverture suivante réussit.
- Cinq cartes par booster, aucun identifiant en double dans un paquet.
- La garantie de rareté du booster est toujours satisfaite.
- Une rareté de multiplicateur `0` n'apparaît jamais.
- Un catalogue vide retourne `[]`. Un catalogue plus petit que cinq retourne
  tous les items disponibles, sans doublon.

**CDN et images**

- `ImagePolicy.url(for:)` accepte uniquement `item/<nom>.png` et
  `block/<nom>.png`, en minuscules, chiffres et underscore.
- `ImagePolicy.url(for:)` refuse la traversée de chemin, les schémas, les hôtes,
  les requêtes, les majuscules et les extensions autres que `.png`.
- `ImagePolicy.isAllowed(_:)` accepte uniquement HTTPS, l'hôte du CDN, le préfixe
  de version figée et aucune query.
- Toutes les textures du catalogue embarqué produisent une URL autorisée.
- Le catalogue embarqué charge ses 99 items et aucun item n'est perdu au décodage.
- `ImagePipeline` coalesce les requêtes simultanées sur la même URL en un seul
  appel réseau, puis sert le cache sans second appel.
- `ImagePipeline` rejette un type MIME non image, un statut hors `200...299`,
  une charge utile supérieure à 2 Mo et une URL hors allowlist.
- Un test d'intégration CDN réel est autorisé uniquement s'il est explicitement
  marqué réseau et désactivé par défaut.
- Les items marqués ou possédés restent récupérables après rechargement depuis
  la persistance, sans doublon et sans perte.

**Poussière**

- Un item nouveau rapporte `0` poussière.
- Un doublon rapporte exactement `Rarity.dustValue` de sa rareté, une seule fois.
- Plusieurs doublons dans une même ouverture cumulent exactement leurs valeurs.
- La poussière ne devient jamais négative.
- Une fabrication réussie retire exactement `Rarity.craftCost`, une seule fois.
- Une fabrication refusée, item déjà possédé ou poussière insuffisante, ne change
  ni la poussière ni la collection.
- Deux fabrications simultanées du même item produisent un seul succès, un seul
  enregistrement et un seul débit.

**Fabrication**

- Un seul item peut être fabriqué à la fois. Quatre appuis rapides produisent une
  seule fabrication tant que la précédente n'est pas terminée.
- Après la fin d'une fabrication, une nouvelle fabrication valide réussit.
- Un item possédé ne peut pas être fabriqué.
- Le coût est vérifié avant toute écriture.

### 4.6 Prérequis connus

Certains invariants ne sont pas testables sur le code actuel. Le test doit être
écrit avec le contrat cible, puis le code corrigé dans le même travail.

- `GameStore` n'a aucun verrou d'ouverture ni de fabrication. Les verrous vont
  dans `GameStore` ou dans un contrôleur de session testable, pas dans la vue.
- `BoostersView` déclenche `store.open` à chaque appui. La garde doit être
  métier, pas seulement visuelle.
- `OpeningView` ne notifie pas la fermeture de la session au store. Ajouter un
  contrat de fin de session.
- `ImagePipeline` a un `init` privé et une session fixe. Rendre l'initialisation
  injectable pour les tests.
- `CatalogAPI` utilise une session statique. Injecter la session ou un client.
- `SeedCatalog.load()` lit `Bundle.main`. Accepter un `Bundle` en paramètre.
- `GameStore.currentPlayer()` peut créer plusieurs enregistrements si l'appel est
  concurrent. Le test de concurrence doit couvrir ce cas.

## 5. Definition of done

- Le code compile et les tests passent.
- Les nouveaux comportements ont leurs tests.
- La documentation d'API est à jour et en français.
- Aucun commentaire libre ajouté.
- Aucun secret, aucune dépendance tierce, aucun accès réseau non validé.
- Le commit respecte la convention et ne contient que l'intention annoncée.
