import SwiftUI

/// Tutoriel de premier lancement, en trois étapes.
struct TutorialView: View {
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
            icon: "gift",
            tint: Theme.copper,
            title: "Ouvre un pack",
            message: "Chaque pack contient 5 cartes. Touche le pack pour l'ouvrir, puis touche chaque carte pour la découvrir."
        ),
        Step(
            id: 1,
            icon: "squares-2x2",
            tint: Theme.accent,
            title: "Complète ta collection",
            message: "Les nouveaux items s'ajoutent à ta collection. Les doublons se transforment en poussière."
        ),
        Step(
            id: 2,
            icon: "chart-bar",
            tint: Theme.moss,
            title: "Fais monter ton titre",
            message: "Plus tu collectionnes d'items différents, plus ton titre progresse. Tout se règle dans l'onglet Profil."
        )
    ]

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 0) {
                HStack {
                    Text("Comment ça marche")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("Passer") {
                        finish()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.spaceL)
                .padding(.top, Theme.spaceM)

                TabView(selection: $page) {
                    ForEach(steps) { step in
                        stepView(step)
                            .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots

                Button(page == steps.count - 1 ? "Commencer" : "Suivant") {
                    if page == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            page += 1
                        }
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(page == steps.count - 1 ? Theme.accent : Theme.copper)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.spaceL)
                .padding(.bottom, Theme.spaceL)
            }
        }
    }

    private func stepView(_ step: Step) -> some View {
        VStack(spacing: Theme.spaceL) {
            Spacer()

            Image(step.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(step.tint)
                .frame(width: 132, height: 132)
                .background(step.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(step.tint.opacity(0.28), lineWidth: 0.8)
                }

            VStack(spacing: 10) {
                Text(step.title)
                    .font(Theme.display(30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(step.message)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.spaceXL)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.spaceM)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(steps) { step in
                Capsule()
                    .fill(step.id == page ? Theme.accent : Theme.textSecondary.opacity(0.24))
                    .frame(width: step.id == page ? 22 : 7, height: 7)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: page)
        .padding(.bottom, Theme.spaceL)
        .accessibilityHidden(true)
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}
