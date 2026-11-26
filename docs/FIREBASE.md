# Firebase — configuration et exploitation

Guide des agents et de l'humain qui administre le projet Firebase
`minemaster-ios-app-but3`. Le projet Xcode est déjà câblé : ce document décrit
ce qui reste à faire dans la console et comment le code se comporte.

## Ce qui est installé dans l'application

Swift Package Manager, produits liés à la cible `MineMaster` :

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`
- `GoogleSignIn` (`google/GoogleSignIn-iOS`)

Le fichier `MineMaster/Resources/GoogleService-Info.plist` est copié dans le
bundle par le groupe synchronisé du projet. La cible de tests ne lie aucun SDK
Firebase : elle teste la logique pure et le magasin SwiftData.

## Démarrage

`RootGateView` affiche le skeleton de `LaunchLoadingView` pendant l'init.

1. `AuthSession.start()` lance `FirebaseRuntime.configure()` dans une tâche
   détachée : la première image n'attend pas l'initialisation.
2. Si `GoogleService-Info.plist` manque, l'application affiche un écran
   « Accès indisponible » avec un bouton de reprise.
3. Session restaurée : `RootTabView` s'ouvre, catalogue et progression
   chargent derrière le skeleton existant.
4. Aucune session : `AuthView` s'affiche. L'application exige un compte.

## Console Firebase — fournisseurs

### 1. Email / mot de passe

`Authentication` → `Sign-in method` → `Email/Password` → **Enable**.
Le lien magique peut rester désactivé : l'application utilise mot de passe.

### 2. Google

1. `Authentication` → `Sign-in method` → `Google` → **Enable**, puis renseigne
   l'email d'assistance.
2. `Project settings` → `Your apps` → application iOS
   `com.minemaster.iut-st-die` → **télécharge à nouveau**
   `GoogleService-Info.plist`.
3. Remplace `MineMaster/Resources/GoogleService-Info.plist`. Le nouveau fichier
   doit contenir `CLIENT_ID` et `REVERSED_CLIENT_ID`.
4. Déclare l'URL scheme. Le projet garde `GENERATE_INFOPLIST_FILE = YES` et
   ajoute un fichier `Info.plist` à la racine du dépôt, référencé par
   `INFOPLIST_FILE = Info.plist` dans les deux configurations de la cible
   `MineMaster`. Ce fichier ne contient que `CFBundleURLTypes` ; Xcode fusionne
   ses clés avec celles générées depuis les `INFOPLIST_KEY_*` du projet.
   - `CFBundleTypeRole` : `Editor`
   - `CFBundleURLName` et `CFBundleURLSchemes` : la valeur exacte de
     `REVERSED_CLIENT_ID`
     (ex. `com.googleusercontent.apps.44361496603-sg2is9advudglekuorka7uijt1n2mrrd`)
   - Changer de client OAuth impose de mettre à jour cette valeur : le scheme
     est figé dans le plist, alors que `FirebaseRuntime.googleURLScheme` est
     recalculé depuis `CLIENT_ID`. Une divergence laisse le bouton Google
     désactivé, avec le mode d'emploi affiché dessous.
   - Vérification après build :
     `plutil -p <produit>.app/Info.plist` doit montrer à la fois
     `CFBundleURLTypes`, `CFBundleDisplayName`, `UILaunchScreen`,
     `UIApplicationSceneManifest` et les orientations.
5. Si l'écran de consentement OAuth est en mode `Testing`, ajoute ton compte
   Google dans `OAuth consent screen` → `Test users`, sinon Google refuse la
   connexion.

L'application vérifie `CLIENT_ID` **et** la présence de l'URL scheme au
démarrage. Sans les deux, le bouton Google est affiché **désactivé** avec la
marche à suivre sous le bouton : aucun échec silencieux, aucun appel réseau.

### 3. Apple

Sign in with Apple exige un compte **Apple Developer Program payant** :

1. `Certificates, Identifiers & Profiles` → App ID
   `com.minemaster.iut-st-die` → capability `Sign in with Apple`.
2. `Authentication` → `Sign in with Apple` → Enable avec Team ID, Key ID et
   clé privée `.p8`.
3. Dans Xcode : cible `MineMaster` → `Signing & Capabilities` → ajoute
   `Sign in with Apple` (entitlement `com.apple.developer.applesignin`).
4. Implémente `ASAuthorizationAppleIDProvider` dans `AuthSession`, puis passe
   `AuthSession.isAppleSignInAvailable` à `true`.

Tant que l'étape 3 n'est pas faite, le bouton Apple est **visible mais
désactivé** : c'est volontaire. Un build d'appareil signé avec une équipe sans
cette capability échouerait, et l'entitlement ne peut pas être provisionné sans
abonnement payant.

## Firestore

1. `Firestore Database` → `Create database` → mode **Native**, région proche
   (ex. `europe-west1`).
2. Publie les règles de `firebase/firestore.rules`. Deux méthodes équivalentes :
   - Console : `Firestore Database` → `Rules` → colle le fichier → **Publish**.
   - CLI : depuis la racine du dépôt, `firebase login` puis
     `firebase deploy --only firestore:rules`. `firebase.json` pointe vers
     `firebase/firestore.rules` et `.firebaserc` fixe le projet.
3. Aucun index composite n'est requis.

Tant que les règles ne sont pas publiées, la base refuse toute lecture et toute
écriture avec le code 7 `PERMISSION_DENIED` : le profil affiche
« Synchronisation refusée par Firestore » et aucune progression n'est
sauvegardée en ligne.

### Modèle de données

Un document par compte, identifiant = `uid` Firebase :

```text
players/{uid}
├─ dust: Int
├─ rebirthLevel: Int
├─ marketPurchases: Int
├─ marketSales: Int
├─ owned: Map<itemID, Int>
├─ marketStock: Map<itemID, Int>
└─ updatedAt: Timestamp
```

Taille typique : moins de 40 Ko pour 515 items. L'historique des ouvertures
reste local, il n'est pas synchronisé.

Les compteurs communautaires vivent hors du compte, dans une collection
publique en lecture pour les utilisateurs connectés :

```text
globalItems/{itemID}
├─ pulls: Int          // tirages mondiaux
├─ marketTrades: Int   // achats + ventes mondiaux
└─ updatedAt: Timestamp
```

### Règles de sécurité

- Lecture et écriture réservées au propriétaire du document
  (`request.auth.uid == uid`).
- Toute autre collection est refusée.
- Suppression refusée.
- Les compteurs sont bornés et typés ; les cartes sont limitées à 2 000 entrées.
- Les règles ne peuvent pas vérifier le type de chaque valeur d'une carte : le
  client valide à la lecture (`ProgressSnapshot(firestoreData:)`) et ignore tout
  identifiant hors catalogue.
- `globalItems` est lisible par tout utilisateur connecté. Les écritures sont
  limitées aux champs `pulls`, `marketTrades` et `updatedAt`, les compteurs ne
  peuvent que croître et chaque envoi est plafonné à `+50`. Suppression refusée.
- Ces agrégats sont fournis par les clients authentifiés : ils restent
  indicatifs et bornés. Pour une production réelle, activer App Check et
  déplacer l'agrégation dans une Cloud Function.

### Comportement de synchronisation

- Écriture différée de 2 secondes après la dernière action locale. Chaque envoi
  remplace le document entier (`setData` sans fusion) : un document qui garde un
  ancien champ hors schéma serait rejeté par `hasOnly` à chaque écriture.
- Au démarrage : lecture du document, puis
  - modification locale en attente → la copie locale est envoyée ;
  - document distant plus récent que la dernière écriture connue → la copie
    distante remplace la collection locale ;
  - sinon → la copie locale est envoyée.
- Hors ligne, Firestore met les écritures en file ; l'interface affiche
  « Modifications en attente d'envoi ».
- Chaque compte possède son propre magasin SwiftData sous
  `Application Support/MineMaster/Accounts/account-<uid>.store`. Aucun compte ne
  peut lire la progression d'un autre.
- La déconnexion vide l'état en mémoire mais conserve le magasin local du compte
  et le document Firestore.
- En cas de fichier local illisible, l'écran « Stockage local » propose de
  réinitialiser : les marqueurs de synchronisation sont effacés puis le magasin
  est supprimé, donc la prochaine ouverture **reprend** le document Firestore au
  lieu de l'écraser.
- La progression locale antérieure à l'arrivée des comptes (ancien magasin par
  défaut) n'est pas migrée : elle n'est rattachable à aucun compte.

## Vérifier rapidement

```bash
# Build
xcodebuild -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'generic/platform=iOS Simulator' build

# Tests unitaires (aucun appel Firebase)
xcodebuild test -project MineMaster.xcodeproj -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Après installation sur simulateur, crée un compte de test avec une adresse
jetable, puis vérifie dans la console : `Authentication` → `Users` et
`Firestore` → `players/{uid}`.

## Points de sécurité restants

- App Check n'est pas activé. À ajouter (App Attest) avant toute distribution.
- Les règles Firestore bornent les valeurs mais ne peuvent pas valider le
  contenu de chaque carte ; un client modifié peut écrire des identifiants
  arbitraires, ignorés à la lecture.
- Les dates de synchronisation viennent de l'horloge du client : une horloge
  très fausse peut faire gagner une copie ancienne. Acceptable pour un projet
  pédagogique ; un champ `serverTimestamp` serait nécessaire en production.
- L'API key Firebase est publique par conception. Ce sont les règles Firestore
  et les domaines autorisés de la console qui protègent les données.
