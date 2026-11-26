import SwiftUI

/// Tutoriel compact de premier lancement sur la montre.
struct WatchTutorialView: View {
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let tint: Color
        let title: String
        let message: String
    }

    private let steps = [
        Step(
            id: 0,
            icon: "shippingbox.fill",
            tint: Theme.copper,
            title: "Ouvre un pack",
            message: "Cinq cartes par pack. Touche chaque carte pour la révéler."
        ),
        Step(
            id: 1,
            icon: "square.grid.2x2.fill",
            tint: Theme.moss,
            title: "Collectionne",
            message: "Les nouveaux items rejoignent ta collection. Les doublons donnent de la poussière."
        ),
        Step(
            id: 2,
            icon: "chart.bar.fill",
            tint: Theme.accent,
            title: "Progresse",
            message: "Ton titre monte avec les items différents. Le profil garde tes statistiques."
        )
    ]

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 6) {
                HStack {
                    Text("Comment ça marche")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("Passer") {
                        finish()
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityIdentifier("watch-skip-tutorial")
                }
                .padding(.horizontal, 6)

                TabView(selection: $page) {
                    ForEach(steps) { step in
                        stepView(step)
                            .tag(step.id)
                    }
                }
                .tabViewStyle(.verticalPage)

                Button(page == steps.count - 1 ? "Commencer" : "Suivant") {
                    if page == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(reduceMotion ? nil : .snappy) {
                            page += 1
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(page == steps.count - 1 ? Theme.accent : Theme.copper)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.bottom, 4)
            }
        }
    }

    private func stepView(_ step: Step) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: step.icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(step.tint)
                .frame(width: 56, height: 56)
                .background(step.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(step.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(step.message)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}
