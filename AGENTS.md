# AGENTS.md — MineMaster

Instructions obligatoires pour toute IA ou agent qui travaille sur ce dépôt.
Elles priment sur les habitudes générales de l'outil. Le non-respect d'une règle
bloquante doit être signalé avant toute modification.

## 0. Lecture obligatoire

Avant de répondre ou de modifier quoi que ce soit :

1. Lire et appliquer `.kilo/skills/caveman/SKILL.md` à chaque réponse.
   La voix caveman est le mode de communication par défaut, sans exception,
   jusqu'à ce que l'utilisateur écrive « stop caveman » ou « normal mode ».
2. Lire et appliquer `.kilo/skills/swiftui-design-skill/SKILL.md` avant toute
   création ou refonte d'interface, puis respecter `docs/DESIGN_SYSTEM.md`.
3. Lire `README.md` pour la stack et l'architecture.
4. Lire `docs/CAHIER_DES_CHARGES.md` si la demande touche une fonctionnalité,
   une règle de jeu, la sécurité ou les données.
5. Lire les fichiers concernés avant de les modifier.

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
- SwiftUI, SwiftData, `URLSession`.
- Dépendances tierces autorisées, et elles seules : `FirebaseCore`,
  `FirebaseAuth`, `FirebaseFirestore` et `GoogleSignIn`, via Swift Package
  Manager. Toute autre dépendance est refusée.
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
  Les domaines Firebase (`*.googleapis.com`, `*.firebaseio.com`) sont atteints
  uniquement par les SDK Firebase, jamais par un `URLSession` maison.
- Toute image distante affiche un squelette de chargement avant décodage.
  Aucune zone d'image vide, même sans réponse du CDN.
- La montre livrée joue sur son propre magasin via `WatchLink` : aucune vue
  watchOS n'appelle directement `open`, `buy`, `sell` ou `rebirth`.
- Le mode miroir optionnel ne mute jamais la copie locale de la montre : il
  envoie une commande bornée à l'iPhone et applique l'état reçu.
- Les fichiers partagés entre iOS, watchOS et WidgetKit vivent dans `Shared/`,
  hors de tout groupe synchronisé. Ils sont référencés explicitement dans les
  phases Sources des cibles concernées, sans jamais dépendre de la
  synchronisation d'une autre cible.

### Commentaires

- Aucun commentaire libre dans les fichiers de code.
- Seule la documentation d'API est autorisée, en Swift DocC (`///`), en français,
  avec les balises utiles :
  `- Parameter`, `- Parameters`, `- Returns`, `- Throws`, `- Complexity`.
- Aucune balise d'auteur : ni `- Authors`, ni `@author`.
- La documentation du code s'adresse aux humains et aux IA : elle explique le
  contrat, les invariants, les erreurs et la complexité, pas l'implémentation
  ligne à ligne.
- Les commentaires existants non demandés ne sont ni supprimés, ni raccourcis.

Exemple conforme :

```swift
/// Ouvre un booster et retourne les cartes tirées.
///
/// - Parameter booster: Booster à ouvrir.
/// - Returns: Les cartes tirées avec leur poussière.
func open(_ booster: Booster) -> [DrawResult]
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
test: couvrir les invariants de poussière et d'ouverture
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
- Interface : cible `MineMasterUITests`, XCTest uniquement, car Swift Testing
  ne pilote pas `XCUIApplication`. Chaque lancement passe `-uiTesting` et
  `-hasSeenTutorial` pour obtenir un état déterministe.
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

xcodebuild test -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=<simulateur installé>' \
  -only-testing:MineMasterUITests

xcodebuild -project MineMaster.xcodeproj -scheme MineMasterWatch \
  -destination 'generic/platform=watchOS' build

xcodebuild test -project MineMaster.xcodeproj -scheme MineMasterWatch \
  -destination 'platform=watchOS Simulator,name=<montre installée>'
```

Le build et les tests doivent passer avant de rendre le travail.

### 4.3 Organisation

```text
MineMasterTests/
├─ Support/     générateur déterministe, fixtures, URLProtocol de test, makeStore()
├─ Domain/      LootEngine, Rarity, Booster, ImagePolicy, SeedCatalog
├─ Data/        GameStore, ImagePipeline, CatalogAPI, Records
└─ Features/    verrou d'ouverture, accueil, collection

MineMasterUITests/
├─ Support/     base commune, lancement déterministe et gestes partagés
├─ OpeningFlowUITests.swift
├─ CollectionUITests.swift
└─ ProfileUITests.swift

Shared/
├─ WatchProtocol.swift       paquets, commandes et bornes
├─ WatchSessionRelay.swift   relais WCSession sans état
└─ ComplicationState.swift   état borné partagé avec WidgetKit

MineMasterWidgets/
├─ MineMasterWidgetsBundle.swift  bundle des trois widgets iPhone
├─ ProgressionWidget.swift        collection, poussière et titres
├─ CareerWidget.swift             titre, ouvertures et renaissances
└─ PackWidget.swift               accès rapide aux boosters

MineMasterWatch/
├─ WatchLink.swift        lien iPhone, commandes et cache de lecture
├─ WatchMarketView.swift  marché compact
└─ ...                    accueil, ouverture, collection, profil, tutoriel

MineMasterWatchTests/
├─ WatchStoreTests.swift
└─ WatchProtocolTests.swift

MineMasterWatchUITests/
├─ Support/
├─ WatchNavigationUITests.swift
└─ WatchOpeningFlowUITests.swift
```

Conventions :

- Nom de suite : `@Suite("Ouverture des boosters")`.
- Nom de test : phrase française décrivant l'invariant, pas le nom de la méthode.
- Structure : Arrange, Act, Assert.
- Un test vérifie un invariant. Plusieurs `#expect` acceptés si le même scénario.
- Les fixtures sont minimales et nommées. Pas de JSON de 500 items si 3 suffisent.
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
- Le pack mystère tire une rareté de booster et un type de contenu.
- Le type affiché sur le pack scellé est exactement celui passé à l'ouverture.
  Planifier une ouverture ne consomme pas le verrou et n'enregistre rien.
- Un seul booster peut être ouvert à la fois. Tant que la session courante
  n'est pas fermée, toute nouvelle ouverture est refusée. Après fermeture,
  l'ouverture suivante réussit.
- Cinq cartes par booster, aucun identifiant en double dans un paquet.
- La garantie de rareté du booster est toujours satisfaite.
- Une rareté de multiplicateur `0` n'apparaît jamais.
- Un catalogue vide retourne `[]`. Un catalogue plus petit que cinq retourne
  tous les items disponibles, sans doublon.

**CDN et images**

- `ImagePolicy.url(for:)` accepte `item/<nom>.png`, `block/<nom>.png` et
  `entity/[<dossier>/]<nom>.png`, en minuscules, chiffres et underscore.
- `ImagePolicy.url(for:)` refuse la traversée de chemin, les schémas, les hôtes,
  les requêtes, les majuscules et les extensions autres que `.png`.
- `ImagePolicy.isAllowed(_:)` accepte HTTPS, l'hôte du CDN avec le préfixe de
  version figée, ou les rendus `minecraft.wiki/images/` en PNG, GIF ou WebP.
- Toute URL refusée : query, fragment, traversée, hôte inconnu ou port non standard.
- Toutes les textures du catalogue embarqué produisent une URL autorisée.
- Chaque créature du catalogue possède un rendu Minecraft Wiki autorisé.
- Le catalogue embarqué charge ses 515 items et aucun item n'est perdu au décodage.
- Le catalogue contient les créatures et objets historiques (`herobrine`,
  `killer_bunny`, `horse_saddle`, `camera`) avec un rendu autorisé.
- Le catalogue contient les catégories armure, créature, arme, outil, bloc,
  nourriture, matériau et spécial.
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
- Un doublon rapporte `Rarity.dustValue` augmenté du boost de renaissance, une
  seule fois.
- Plusieurs doublons dans une même ouverture cumulent exactement leurs valeurs.
- La poussière ne devient jamais négative.

**Marché**

- Achat : débite le prix d'achat, ajoute un exemplaire, décrémente le stock.
- Vente : crédite le prix de revente, retire un exemplaire, incrémente le stock.
- Un achat refuse une poussière insuffisante (`insufficientDust`) ou un stock nul
  (`outOfStock`).
- Une vente refuse un item non possédé (`notOwned`).
- Acheter l'unique exemplaire d'un item ne le marque pas deux fois comme unique.
- Les prix dérivent de la rareté et ne sont jamais persistés.
- Les compteurs d'achats et de ventes survivent au rechargement.

**Renaissance**

- La renaissance est refusée sous `Rebirth.minimumUniqueItems` items différents
  (`rebirthLocked`).
- Une renaissance vide la collection et la poussière, conserve l'historique des
  ouvertures et incrémente le niveau d'un palier.
- Les boosts de rareté et de poussière se cumulent sans plafond et persistent.
- Le boost est transmis au tirage ; la poussière d'un doublon suit le niveau.
- Une renaissance remet le stock du marché à `1`.

**Compte et synchronisation**

- Aucun accès à la progression sans session authentifiée.
- Chaque compte Firebase utilise son propre magasin SwiftData : deux comptes ne
  partagent jamais collection, poussière ou stock.
- Un identifiant de compte invalide (chemin, séparateur, longueur) ne produit
  jamais d'URL de magasin.
- `ProgressSnapshot` borne toutes les valeurs reçues : négatifs ramenés à zéro,
  quantités plafonnées, identifiants hors catalogue ignorés.
- Un document Firestore aux types invalides, aux cartes démesurées ou dont la
  date manque est refusé.
- Une modification locale en attente gagne sur la copie distante. Sinon la copie
  distante la plus récente gagne, et une première connexion reprend le document
  existant.
- Aucune écriture distante n'est émise avant une lecture réussie du document :
  sans cette vérification, une copie locale périmée écraserait la progression
  d'un autre appareil.
- Toute opération Firestore est bornée dans le temps ; une réponse tardive ne
  peut ni reprendre deux fois la continuation ni modifier les marqueurs d'un
  compte déjà suspendu.
- Réinitialiser le stockage local efface les marqueurs de synchronisation avant
  de supprimer le fichier : la reconnexion reprend le document distant au lieu
  de l'écraser.
- La restauration distante n'émet aucun nouvel envoi vers Firestore.
- Les règles Firestore n'autorisent que `players/{uid}` du compte connecté.
- Chaque envoi remplace le document entier, sans fusion : un champ hors schéma
  laissé par une ancienne version ferait échouer `hasOnly` et toutes les
  écritures suivantes seraient refusées (`PERMISSION_DENIED`).

**Statistiques mondiales**

- `globalItems/{itemID}` est lisible par tout utilisateur authentifié et ne
  contient que `pulls`, `marketTrades` et `updatedAt`.
- Les compteurs ne peuvent que croître, chaque envoi est plafonné à `+50` et la
  suppression est refusée.
- Les incréments sont agrégés par item, envoyés par lots et bornés dans le
  temps ; un échec conserve les incréments en attente.
- Les compteurs mondiaux sont indicatifs et ne pilotent jamais la progression,
  la rareté ou les prix.

**Profil**

- Les seuils de titres sont strictement croissants.
- Le titre courant est le plus haut seuil atteint par les items uniques.
- Le prochain titre est le premier seuil non atteint ; le titre maximal n'a pas
  de suivant.

**Apple Watch**

- L'app livrée utilise `WatchLink.Mode.local` : la montre joue sur son propre
  magasin SwiftData, sans compte, sans Firebase et sans iPhone.
- Ouvertures, achats, ventes et renaissances ne modifient que la progression
  locale de la montre ; la progression iPhone diverge par conception.
- La montre charge le catalogue embarqué et le stock du marché sans réseau.
- Les tirages locaux par item sont persistés ; les compteurs communautaires
  restent indisponibles sur la montre.
- La complication ne lit qu'un état borné partagé par groupe d'applications,
  sans progression brute ni identifiant de compte.
- Le mode miroir optionnel (`WatchLink.Mode.live`) conserve les invariants
  suivants, couverts par les tests du routeur : commandes idempotentes, plan
  sans verrou, états bornés, paquets de 60 Ko et commandes de 8 Ko maximum.
- En mode miroir optionnel, une montre hors connexion reste en lecture seule et
  une déconnexion iPhone verrouille son cache.

**Widgets iPhone**

- Les widgets sont en lecture seule : aucune ouverture, aucun achat, aucune
  vente et aucune renaissance depuis l'extension.
- L'état partagé ne contient que des agrégats bornés : progression, compteurs,
  titre, poussière et date. Aucun email, aucun identifiant de compte, aucune
  collection brute.
- L'état est effacé à la déconnexion ; un widget sans état affiche un
  placeholder et n'expose aucune donnée du compte précédent.
- Le lien profond `minemaster://` ouvre uniquement un onglet connu et ne modifie
  jamais la progression.
- Les tailles supportées sont petit et moyen. Les trois widgets partagent le
  même état borné et la même identité visuelle.
- La cible iOS et la cible `MineMasterWidgets` partagent le groupe
  `group.com.minemaster.iut-st-die`. Sans cette capacité, le widget affiche son
  placeholder.

**Interface**

- L'ouverture d'un pack révèle cinq cartes, puis revient à l'accueil.
- La deuxième ouverture crédite exactement la poussière des doublons.
- La recherche isole un item et ouvre son détail.
- Le filtre « Possédés » masque les items jamais obtenus.
- La renaissance vide la collection et la poussière, puis incrémente le niveau.
- Le tutoriel de premier lancement se ferme par « Passer ».
- Le mode `-uiTesting` ne touche ni la base réelle, ni le réseau, ni le catalogue
  de production.

### 4.6 Prérequis et limites connues

Le verrou d'ouverture vit dans `GameStore`. Les vues lisent `isOpening` ; elles
ne portent jamais la règle métier.

`AuthSession` dépend du SDK Firebase : aucun test unitaire ne l'appelle.
`ProgressSync` accepte un `ProgressSync.Transport` injecté, ce qui couvre sans
réseau la garde d'écriture, la révocation après lecture ratée et la suspension.
La résolution des conflits et les instantanés sont testés directement. Les
règles Firestore se vérifient dans la console, pas dans la cible de tests.

Points restant à instrumenter avant d'ajouter les tests correspondants :

- `CatalogAPI` utilise une session statique. Injecter la session ou un client
  avant de tester les statuts, la taille et les erreurs réseau.
- `GameStore.currentPlayer()` crée un enregistrement si aucun joueur n'existe.
  Un test multi-instances sur le même conteneur doit couvrir l'unicité.
- Le chargement des images est vérifié par les tests de `ImagePipeline`.
  Le rendu SwiftUI du squelette n'est pas couvert par un test unitaire.
- `WCSession` n'est pas injectable dans les tests unitaires : le mode local
  livré de `WatchLink` est testé directement, et le mode miroir optionnel est
  couvert par le protocole et le routeur séparément.
- La complication et les widgets WidgetKit n'ont pas de cible de test dédiée ;
  seuls l'encodage, les bornes de `ComplicationState` et l'instantané publié
  sont testés. Le rendu SwiftUI des widgets n'est pas couvert.
- La capacité App Groups doit être autorisée par l'équipe de signature pour que
  la complication et les widgets iPhone partagent leur état. Sans elle, ils
  affichent un placeholder et le reste de l'app reste fonctionnel.

## 5. Definition of done

- Le code compile et les tests passent.
- Les nouveaux comportements ont leurs tests.
- La documentation d'API est à jour et en français.
- Aucun commentaire libre ajouté.
- Aucun secret, aucune dépendance tierce, aucun accès réseau non validé.
- Le commit respecte la convention et ne contient que l'intention annoncée.
