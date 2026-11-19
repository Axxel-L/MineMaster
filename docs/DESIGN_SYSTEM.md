# Design System — MineMaster

Document de référence pour les IA et agents. La documentation du code reste en
français dans les fichiers Swift, avec les commentaires DocC.

## Direction

**Coffre éditorial.** Un objet de collection chaleureux, dense mais respirant.
Le pack est le héros. Le reste de l'écran est une planche de collection imprimée :
titres SF Pro, étiquettes monospace, filets fins, papier sombre.

Références visuelles : boîte de cartes premium, carnet d'explorateur, papier
craft, foil de booster.

## Tokens

| Token | Valeur | Usage |
|---|---|---|
| `Theme.accent` | ambre chaud | action principale, progression |
| `Theme.moss` | vert mousse | packs communs, collection |
| `Theme.copper` | cuivre | packs rares, fabrication |
| `Theme.background` | brun-noir | fond global |
| `Theme.surface` | brun profond | cartes et panneaux |
| `Theme.surfaceRaised` | brun relevé | états sélectionnés |
| `Theme.textPrimary` | parchemin | titres et valeurs |
| `Theme.textSecondary` | sable éteint | légendes et métadonnées |
| `Theme.display` | SF Pro / système | titres |
| `Theme.mono` | SF Mono / monospace | étiquettes techniques |

Espacement : 4, 8, 16, 24, 32, 48. Rayons : 10, 16, 24.

## Anatomie du pack

1. Corps foil avec dégradé propre au type du pack, ou à la rareté si le type
   n'est pas connu (pack mystère).
2. Grain pixel discret, jamais une illustration générique.
3. Bande crantée en haut et en bas, comme un sachet scellé.
4. Ligne de perforation et languette « Tire ici ».
5. Le pack se déchire au doigt ou via le bouton explicite.
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

La galerie de l'accueil affiche un mini pack par type. L'icône et le libellé
restent lisibles hors du pack réduit. Le pack mystère affiche `TOUS TYPES`.

## Révélation

- Cinq cartes, révélation manuelle au toucher.
- Aucun défilement automatique, aucune révélation automatique.
- Le dos de carte reste lisible : pas de texte en miroir.
- Plus la rareté monte, plus la lumière, l'échelle et le nombre de particules
  augmentent.
- Particules : `rare` 18, `epic` 34, `legendary` 56. `common` et `uncommon`
  n'émettent pas de particules.

## Règles anti-slop

- Pas de dégradé violet-bleu.
- Pas d'emoji comme icône.
- Pas de grille de trois cartes identiques.
- Pas de fond néon.
- Pas de titre centré sur un dégradé générique.
- Une seule signature par écran : pack foil, tampon de passeport, ou rareté.

## Chargement

Toute image distante affiche `SkeletonImage` avant décodage. Aucune zone d'image
vide, même si le CDN ne répond pas. En cas d'échec, repli sur l'icône cube.
