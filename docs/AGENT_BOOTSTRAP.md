# Démarrage agent — MineMaster

Procédure pour une IA ou un nouvel agent qui ouvre le dépôt pour la première
fois. Objectif : se placer à la racine, résoudre les dépendances, compiler pour
iPhone et lancer les tests sans toucher à la progression réelle.

Les règles de code et les invariants restent dans [`../AGENTS.md`](../AGENTS.md).
Ce document ne les remplace pas.

## 1. Racine du dépôt

Toutes les commandes partent de la racine, le dossier qui contient
`MineMaster.xcodeproj` :

```bash
cd "$(git rev-parse --show-toplevel)"
pwd
```

Le chemin peut contenir des espaces et des accents. Toujours le citer.

## 2. Vérifier Xcode

```bash
xcodebuild -version
xcode-select -p
```

`xcode-select -p` doit pointer vers `Xcode.app/Contents/Developer`, pas vers
`/Library/Developer/CommandLineTools`. Si ce n'est pas le cas, préfixer chaque
commande avec `DEVELOPER_DIR`, sans modifier la configuration globale :

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Sans cette variable, `xcodebuild` et `xcrun simctl` peuvent échouer avec
`unable to find utility "simctl"`.

## 3. Installation et build en une commande

```bash
./scripts/agent-bootstrap.sh
```

Le script :

1. se place à la racine du dépôt ;
2. sélectionne un Xcode installé si `DEVELOPER_DIR` manque ;
3. résout les paquets Swift Package Manager ;
4. compile `MineMaster` pour le simulateur iPhone ;
5. affiche le chemin du build.

Variables utiles :

```bash
SCHEME=MineMaster DESTINATION='generic/platform=iOS Simulator' \
  DERIVED_DATA=/tmp/minemaster-agent-derived \
  ./scripts/agent-bootstrap.sh
```

## 4. Build manuel

Résolution des dépendances :

```bash
xcodebuild -resolvePackageDependencies \
  -project MineMaster.xcodeproj \
  -scheme MineMaster
```

Build iPhone :

```bash
xcodebuild -project MineMaster.xcodeproj \
  -scheme MineMaster \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Build vers un simulateur précis :

```bash
xcrun simctl list devices available
xcodebuild -project MineMaster.xcodeproj \
  -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  build
```

## 5. Lancer sur le simulateur

```bash
UDID=$(xcrun simctl list devices available -j | \
  /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for xs in d.values() for x in xs if x["name"].startswith("iPhone")))')

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcodebuild -project MineMaster.xcodeproj \
  -scheme MineMaster \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath /tmp/minemaster-agent-derived \
  build
xcrun simctl install "$UDID" \
  /tmp/minemaster-agent-derived/Build/Products/Debug-iphonesimulator/MineMaster.app
xcrun simctl launch "$UDID" com.minemaster.iut-st-die
```

## 6. Tests

Tests unitaires iPhone et parcours d'interface :

```bash
xcodebuild test -project MineMaster.xcodeproj \
  -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

Tests unitaires seuls :

```bash
xcodebuild test -project MineMaster.xcodeproj \
  -scheme MineMaster \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:MineMasterTests
```

Les tests d'interface utilisent `-uiTesting` et un magasin en mémoire. Ils ne
touchent ni la base réelle, ni Firestore.

## 7. Captures d'écran

Les captures publiées vivent dans [`screenshots/`](screenshots/). Noms stables :

```text
boosters.png, ouverture.png, collection.png, profil.png,
marche.png, fiche.png,
widget-progression.png, widget-carriere.png, widget-pack.png
```

Pour des captures iPhone propres, fixer la barre d'état puis utiliser le
simulateur :

```bash
xcrun simctl status_bar booted override \
  --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4
xcrun simctl io booted screenshot /tmp/minemaster-capture.png
```

Un simulateur Apple Watch n'est pas nécessaire pour les captures iPhone. Ne
pas installer de runtime watchOS sans demande explicite.

## 8. Firebase et données réelles

`MineMaster/Resources/GoogleService-Info.plist` est déjà présent. Ne jamais
ajouter de jeton, de mot de passe ou de compte de test dans le dépôt, les
captures ou les logs.

Pour les tests et les captures, préférer `-uiTesting` (catalogue fixe, réseau
coupé, magasin en mémoire). Pour une capture de production, utiliser un compte
de démonstration local et ne pas modifier les règles Firestore sans instruction
explicite.

Les règles Firestore sont dans `firebase/firestore.rules`. Leur déploiement
n'est pas une opération de build : ne pas le lancer sans accord.

## 9. Cible Apple Watch

La cible `MineMasterWatch` existe et doit compiler, mais l'application iPhone ne
dépend pas d'un simulateur montre pour être buildée, testée ou capturée.

```bash
xcodebuild -project MineMaster.xcodeproj \
  -scheme MineMasterWatch \
  -destination 'generic/platform=watchOS' \
  build
```

## 10. Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| `unable to find utility "simctl"` | `DEVELOPER_DIR` pointe vers CommandLineTools | Exporter `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` |
| `No such module: Firebase...` | Paquets non résolus | Relancer `xcodebuild -resolvePackageDependencies` |
| `Unable to find a destination` | Simulateur absent ou nom différent | `xcrun simctl list devices available`, puis utiliser l'UDID |
| Signature refusée sur appareil | Équipe ou profil absent | Rester sur le simulateur, ou configurer la signature dans Xcode |
| Widget ou complication vide | App Groups non autorisé | Vérifier l'entitlement `group.com.minemaster.iut-st-die` |
| L'image distante reste en squelette | Réseau coupé en `-uiTesting` | Utiliser le build normal pour les captures réseau |

## 11. Carte de la documentation

| Besoin | Document |
|---|---|
| Règles de code, tests, Git, terminé | [`../AGENTS.md`](../AGENTS.md) |
| Règles de jeu, sécurité, données | [`CAHIER_DES_CHARGES.md`](CAHIER_DES_CHARGES.md) |
| Design, couleurs, composants | [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) |
| Firebase, Auth, Firestore | [`FIREBASE.md`](FIREBASE.md) |
| Stack, fonctionnalités, structure | [`../README.md`](../README.md) |
| Captures à jour | [`screenshots/`](screenshots/) |
