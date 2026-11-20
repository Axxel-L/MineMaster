import SwiftUI

/// Écran de chargement affiché avant l'ouverture de la navigation.
struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: Theme.spaceL) {
                Spacer()

                VStack(spacing: 4) {
                    Text("MineMaster")
                        .font(Theme.display(42, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Ta collection se prépare")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                SkeletonBooster()
                    .frame(maxWidth: 260)

                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("Chargement du catalogue")
                        .font(.footnote)
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
