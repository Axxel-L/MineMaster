import Observation

/// État partagé de la révélation d'un paquet de cartes.
///
/// Le paquet garde la carte affichée et les positions déjà révélées. Une carte
/// révélée se touche une seconde fois pour passer à la suivante.
@MainActor
@Observable
final class RevealDeck {
    /// Nombre de cartes du paquet.
    let count: Int

    /// Position de la carte affichée.
    private(set) var index = 0

    /// Positions déjà révélées.
    private(set) var revealed: Set<Int> = []

    /// Compteur déclenchant le retour haptique de révélation.
    private(set) var revealTick = 0

    /// Compteur déclenchant le retour haptique de passage.
    private(set) var advanceTick = 0

    /// Crée un paquet de cartes, toutes face cachée.
    ///
    /// - Parameter count: Nombre de cartes, borné à zéro.
    init(count: Int) {
        self.count = max(0, count)
    }

    /// Indique si toutes les cartes sont révélées.
    var allRevealed: Bool {
        revealed.count == count
    }

    /// Indique si la carte affichée est révélée.
    var isCurrentRevealed: Bool {
        revealed.contains(index)
    }

    /// Révèle une carte sans changer la carte affichée.
    ///
    /// - Parameter position: Position de la carte.
    func reveal(_ position: Int) {
        guard (0..<count).contains(position), revealed.insert(position).inserted else { return }
        revealTick += 1
    }

    /// Passe à la prochaine carte non révélée après une position.
    ///
    /// Le parcours est circulaire : si aucune carte ne suit, la première carte
    /// non révélée du paquet est choisie. Sans carte disponible, rien ne change.
    ///
    /// - Parameter position: Position de départ.
    func advance(from position: Int) {
        guard let next = nextUnrevealed(after: position) else { return }
        advanceTick += 1
        index = next
    }

    /// Affiche une carte précise.
    ///
    /// - Parameter position: Position de la carte.
    func select(_ position: Int) {
        guard (0..<count).contains(position) else { return }
        index = position
    }

    private func nextUnrevealed(after position: Int) -> Int? {
        guard count > 0 else { return nil }
        for step in 1...count {
            let candidate = (position + step) % count
            if !revealed.contains(candidate) {
                return candidate
            }
        }
        return nil
    }
}
