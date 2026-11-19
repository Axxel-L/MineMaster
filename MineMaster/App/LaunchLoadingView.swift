import SwiftUI

/// Écran de chargement affiché avant l'ouverture de la navigation.
///
/// - Authors: Axel L.
struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: Theme.spaceL) {
                Spacer()

                VStack(spacing: 4) {
                    Text("LE COFFRE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(Theme.textSecondary)
                    Text("MineMaster")
                        .font(Theme.display(42, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                }

                SkeletonBooster()
                    .frame(maxWidth: 260)

                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("CHARGEMENT DU MONDE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Chargement du catalogue")

                Spacer()
                Spacer()
            }
            .padding(.horizontal, Theme.spaceL)
        }
    }
}
