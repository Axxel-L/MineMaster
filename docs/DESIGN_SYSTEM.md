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

Trois onglets seulement : Boosters, Collection, Profil. Le tutoriel de premier
lancement tient en trois écrans courts et reste accessible par le bouton `?` de
l'accueil ou depuis Profil.

## Chargement

Toute image distante affiche `SkeletonImage` avant décodage. Aucune zone d'image
vide, même si le CDN ne répond pas. En cas d'échec, repli sur l'icône cube.
