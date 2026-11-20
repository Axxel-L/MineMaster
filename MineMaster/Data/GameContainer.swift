import SwiftData

/// Fabrique le conteneur SwiftData commun aux applications iOS et watchOS.
enum GameContainer {
    /// Schéma persistant partagé par les deux plateformes.
    static var schema: Schema {
        Schema([
            CatalogItemRecord.self,
            CollectionRecord.self,
            PlayerRecord.self,
            OpeningRecord.self,
            MarketListingRecord.self
        ])
    }

    /// Ouvre le conteneur persistant du joueur.
    ///
    /// - Returns: Un conteneur SwiftData prêt à l'emploi.
    /// - Throws: L'erreur SwiftData si le stockage est indisponible.
    static func make() throws -> ModelContainer {
        let schema = schema
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema)]
        )
    }
}
