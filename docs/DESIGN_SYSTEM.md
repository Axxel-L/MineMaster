# Design System — MineMaster

Document de référence pour les IA et agents. La documentation du code reste en
français dans les fichiers Swift, avec les commentaires DocC.

## Direction

**Atelier minier.** Un fond ardoise profond, un vert émeraude franc pour les
actions, un ambre réservé aux raretés et aux accents. Le pack reste le héros.
L'interface est plus directe qu'un carnet : police système Apple partout,
étiquettes courtes, filets discrets, aucune surcharge décorative.

Les icônes de navigation et d'illustration viennent du jeu Heroicons déjà
embarqué. SF Symbols reste utilisé pour les pictogrammes système secondaires.

## Tokens

| Token | Valeur | Usage |
|---|---|---|
| `Theme.accent` | émeraude | action principale, progression |
| `Theme.moss` | vert-bleu | collection, packs communs |
| `Theme.copper` | ambre | accents, packs mixtes |
| `Theme.background` | ardoise très sombre | fond global |
| `Theme.surface` | ardoise | cartes et panneaux |
| `Theme.surfaceRaised` | ardoise claire | états sélectionnés |
| `Theme.textPrimary` | blanc chaud | titres et valeurs |
| `Theme.textSecondary` | gris-vert | légendes et métadonnées |
| `Theme.danger` | rouge brique | suppression, erreurs |
| `Theme.display` | SF Pro / système | titres |
| `Theme.mono` | SF Mono / monospace | chiffres et codes seulement |

Espacement : 4, 8, 16, 24, 32, 48. Rayons : 10, 16, 24.

## Anatomie du pack

1. Corps foil avec dégradé propre au type du pack, ou à la rareté si le type
   n'est pas connu (pack mystère).
2. Grain pixel discret, jamais une illustration générique.
3. Bande crantée en haut et en bas, comme un sachet scellé.
4. Ligne de perforation et languette « Tire ici ».
5. Le pack s'ouvre au doigt ou via le bouton explicite.
6. Le pack s'ouvre uniquement après un geste explicite.

## Identité des packs par type

Chaque `BoosterKind` porte sa propre identité visuelle, exposée dans
`Theme.swift` :

| Propriété | Rôle |
|---|---|
| `foilColors` | Dégradé foil du corps du pack, trois teintes |
| `tint` | Lueur, boutons et accents du type |
| `systemImage` | Icône imprimée sur le pack et dans l'en-tête de révélation |
| `packLabel` | Bande de type imprimée sous le titre du pack |

Palettes : créatures vert forêt, armes rouge brique, armures acier bleuté,
consommables violet-magenta, nourriture blé olive, blocs pierre, outils cuivre,
pack mystère ambre. Chaque teinte reste distincte des voisines et lisible avec
le texte noir du pack.

Le pack scellé affiche le type tiré avant la déchirure : couleur, icône et bande
correspondent au tirage réel. L'accueil ne charge aucune galerie de packs. Le
pack mystère affiche `TOUS TYPES` uniquement tant que le plan n'est pas prêt.

## Profil

- Anneau de progression animé à l'apparition, chiffres en transition numérique.
- Répartition par catégorie et par rareté : barres animées une seule fois, une
  passe sur le catalogue pour calculer possédés et totaux.
- Titres d'explorateur : sept paliers fondés sur les items différents. Le titre
  courant, le prochain seuil et un bouton `?` ouvrent l'explication complète.
- Les animations respectent Reduce Motion.

## Révélation

- Cinq cartes, révélation manuelle au toucher.
- Aucun défilement automatique, aucune révélation automatique.
- Le dos de carte reste lisible : pas de texte en miroir.
- Plus la rareté monte, plus la lumière, l'échelle et le nombre de particules
  augmentent.
- `rare` : onde de choc et 22 étincelles avec traînée.
- `epic` : deux ondes, 10 rayons rotatifs, 40 étincelles, balayage lumineux.
- `legendary` : trois ondes, 16 rayons, 68 étincelles, balayage et impact
  haptique lourd.
- `common` et `uncommon` n'émettent pas de particules.
- La célébration s'arrête seule après 1,7 à 2,8 s et ne tourne pas hors écran.

## Règles anti-slop

- Pas de dégradé violet-bleu.
- Pas d'emoji comme icône.
- Pas de grille de trois cartes identiques.
- Pas de fond néon.
- Pas de titre centré sur un dégradé générique.
- Une seule signature par écran : pack foil, titre de profil, ou rareté.

## Navigation et tutoriel

Quatre onglets : Boosters, Collection, Profil, Marché. Le tutoriel de premier
lancement tient en trois écrans courts et reste accessible par le bouton `?` de
l'accueil ou depuis Profil.

## Marché

- Contrepartie unique locale : achat et revente contre de la poussière, sans
  réseau ni simulation. Le stock est persisté en SwiftData, les prix sont
  recalculés depuis la rareté et ne sont jamais stockés.
- Deux modes, `Acheter` et `Vendre`, sélectionnés par puces de filtre.
- Prix d'achat = `dustValue × 5`, prix de revente = `dustValue` (spread 5:1).
- Une carte par item : badge de rareté, stock ou quantité possédée en monospace,
  prix en monospace, un bouton d'action pleine largeur de 44 pt.
- Sélecteur Acheter / Vendre en contrôle segmenté pleine largeur.
- Grille adaptative : deux colonnes sur petit écran, plus sur iPad, une seule en
  taille de texte accessibilité. Les libellés se réduisent au lieu de déborder.
- Le bouton d'achat est désactivé si la poussière manque. Les refus métier
  (poussière insuffisante, stock nul, item non possédé) s'affichent en bandeau.
- La fiche item (`ItemDetailView`) expose prix d'achat, prix de revente, stock
  et quantité possédée, avec les mêmes actions.
- Le profil affiche le total des achats et des ventes, persisté avec le joueur.

## Renaissance

- Remplace l'ancienne réinitialisation : carte dédiée dans le profil, niveau
  courant, trois puces de boosts (légendaire, épique, poussière) et progression
  vers le seuil.
- Seuil : `Rebirth.minimumUniqueItems` items différents. Bouton `Renaître`
  désactivé et barre de progression tant que le seuil n'est pas atteint.
- Confirmation destructive explicite avant l'action.
- Remet la collection et la poussière à zéro, conserve l'historique des
  ouvertures, réapprovisionne le marché à `1` et incrémente le niveau.
- Boosts cumulatifs sans plafond, appliqués au tirage et à la poussière des
  doublons.

## Chargement

Toute image distante affiche `SkeletonImage` avant décodage. Aucune zone d'image
vide, même si le CDN ne répond pas. En cas d'échec, repli sur l'icône cube.
