# MineMaster

Application iOS native de collection : ouvre des packs, découvre des items Minecraft et complète ta collection. La poussière gagnée sur les doublons servira plus tard.

| Boosters | Ouverture | Collection | Profil |
|---|---|---|---|
| ![Boosters](docs/screenshots/boosters.png) | ![Ouverture](docs/screenshots/ouverture.png) | ![Collection](docs/screenshots/collection.png) | ![Profil](docs/screenshots/profil.png) |

## Stack

- Swift 6 (mode langage complet, concurrence stricte, isolation `MainActor` par défaut)
- SwiftUI + Liquid Glass natif (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `tabBarMinimizeBehavior`, transitions zoom)
- SwiftData pour le catalogue, la collection et l'historique
- `URLSession` + pipeline d'images maison
- Firebase (`FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`) et `GoogleSignIn` via Swift Package Manager
- Cible : iOS 26.0, Xcode 26.6 ou plus récent (projet au format `project.pbxproj`)

## Lancer le projet

```bash
open MineMaster.xcodeproj
```

Sélectionne un simulateur iPhone, puis `⌘R`. Le fichier `GoogleService-Info.plist`
est déjà embarqué. Les fournisseurs (email, Google) et Firestore se configurent
dans la console : voir [`docs/FIREBASE.md`](docs/FIREBASE.md).

Build en ligne de commande :

```bash
xcodebuild -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'generic/platform=iOS Simulator' build
```

## Fonctionnalités

- Compte obligatoire : email/mot de passe, Google Sign-In (actif une fois le fournisseur configuré), progression synchronisée avec Firestore par compte
- Démarrage non bloquant : Firebase s'initialise derrière un skeleton de chargement
- Pack mystère unique : rareté et type tirés avant la déchirure, type affiché sur le pack scellé, 5 cartes par pack, garanties par rareté
- 5 raretés, 8 catégories, 254 items (blocs, outils, armes, armures, livres enchantés, créatures)
- Types de packs : créatures, armes, armures, consommables, nourriture, blocs, outils
- Chaque type possède sa couleur, son icône et sa bande de type sur le pack
- Pack scellé à ouvrir au doigt, révélation en carrousel, ondes et rayons renforcés pour les cartes rares, épiques et légendaires
- Écran de chargement avec skeleton, rendus 3D des créatures depuis Minecraft Wiki
- Thème ardoise et émeraude, police système Apple, icônes Heroicons
- Tutoriel de premier lancement en trois étapes, accessible depuis l'accueil et le profil
- Collection avec recherche, filtres rareté/catégorie et filtre « possédés »
- Profil animé : anneau de progression, répartitions par catégorie et rareté, sept titres d'explorateur expliqués en modal
- Fiche détail en modal avec chance de tirage, tirages locaux et prix du marché
- Marché local : achat et revente d'items contre de la poussière
- Doublons convertis en poussière
- Renaissance : boosts permanents de rareté et de poussière, cumulables
- Statistiques locales, renaissance, mentions légales
- Skeletons de chargement, mode hors ligne avec catalogue en cache
- Accessibilité : VoiceOver, Dynamic Type, Reduce Motion

## Sources de données

| Usage | Source |
|---|---|
| Métadonnées | `PrismarineJS/minecraft-data` (1.21.4) |
| Textures | jsDelivr, miroir `InventivetalentDev/minecraft-assets` (1.21.4) |
| Repli | `MineMaster/Resources/ItemCatalog.json` (embarqué) |

La version d'assets est figée. Aucune requête n'est faite vers un hôte hors allowlist, aucun secret n'est présent dans le binaire.

## Architecture

```text
MineMaster/
├─ App/            point d'entrée, onglets
├─ Domain/         modèles, règles de tirage
├─ Data/           API, SwiftData, GameStore, pipeline d'images
├─ Design/         thème, composants, skeletons
├─ Features/       boosters, ouverture, collection, profil
└─ Resources/      catalogue embarqué, manifeste de confidentialité
```

- `GameStore` centralise l'état observable et les règles métier.
- `LootEngine` est pur et testable (générateur aléatoire injecté).
- `ImagePipeline` coalesce les requêtes, valide les réponses (MIME, taille), met en cache mémoire et disque.
- Le catalogue distant est fusionné avec les définitions locales, puis persisté.

## Tests

Deux cibles de test coexistent :

- `MineMasterTests` : tests unitaires Swift Testing, conteneur SwiftData en mémoire et sessions réseau de test.
- `MineMasterUITests` : parcours XCTest pilotés par l'interface, avec un catalogue fixe de six items et aucun accès réseau.

```bash
xcodebuild test -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=<simulateur installé>'

xcodebuild test -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=<simulateur installé>' \
  -only-testing:MineMasterUITests
```

Les conventions et les invariants obligatoires sont décrits dans [`AGENTS.md`](AGENTS.md).

## Sécurité et vie privée

- HTTPS uniquement, ATS par défaut, aucune exception
- Allowlist d'hôtes et validation des chemins d'images
- Payloads bornés (5 Mo métadonnées, 2 Mo images)
- Firebase Auth et Firestore uniquement : aucun analytics, aucun tracking
- Règles Firestore limitées au document du compte connecté (`firebase/firestore.rules`)
- Un magasin SwiftData par compte, isolé sur disque
- `PrivacyInfo.xcprivacy` fourni
- SVG embarqués uniquement (Heroicons)

## Limites connues

- Le compte est obligatoire : aucun mode invité
- Sign in with Apple désactivé tant que la capability payante n'est pas provisionnée
- Économie non sécurisée côté serveur (projet pédagogique)
- App Check non activé
- Français uniquement pour l'instant, chaînes prêtes pour un String Catalog

## Licences

- Swift 6.0, Apache License 2.0, Apple
- SwiftUI, SwiftData, Foundation, SDK iOS 26, Apple
- Heroicons 2.2.0, MIT, © Tailwind Labs
- minecraft-data 1.21.4, MIT, PrismarineJS
- Textures et noms Minecraft, © Mojang Studios / Microsoft — projet non commercial et non affilié, assets non redistribués
- Rendus de créatures, Minecraft Wiki, CC BY-NC-SA 3.0
- SF Symbols, Apple

Le cahier des charges complet est disponible dans [`docs/CAHIER_DES_CHARGES.md`](docs/CAHIER_DES_CHARGES.md).
