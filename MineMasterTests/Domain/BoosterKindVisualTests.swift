import SwiftUI
import Testing
@testable import MineMaster

@MainActor
@Suite("Identité visuelle des packs")
struct BoosterKindVisualTests {
    @Test("Chaque type de pack possède une palette de trois couleurs")
    func eachKindHasPalette() {
        for kind in BoosterKind.allCases {
            #expect(kind.foilColors.count == 3, "Palette incomplète: \(kind.rawValue)")
        }
    }

    @Test("Chaque type de pack possède un libellé et une icône")
    func eachKindHasLabelAndIcon() {
        for kind in BoosterKind.allCases {
            #expect(!kind.packLabel.isEmpty, "Libellé absent: \(kind.rawValue)")
            #expect(!kind.systemImage.isEmpty, "Icône absente: \(kind.rawValue)")
        }
        #expect(Set(BoosterKind.allCases.map(\.packLabel)).count == BoosterKind.allCases.count)
        #expect(Set(BoosterKind.allCases.map(\.systemImage)).count == BoosterKind.allCases.count)
    }

    @Test("Un pack typé affiche le nom de son type")
    func typedPackLabelMatchesName() {
        for kind in BoosterKind.allCases where kind != .mixed {
            #expect(kind.packLabel == kind.displayName.uppercased())
        }
        #expect(BoosterKind.mixed.packLabel == "TOUS TYPES")
    }
}
