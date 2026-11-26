import SwiftUI
import UIKit

/// Écran de connexion obligatoire avant l'accès à la collection.
///
/// Le formulaire reste réactif pendant l'appel réseau : le bouton principal
/// affiche sa progression, les champs se verrouillent et l'erreur arrive dans un
/// bandeau intérieur, sans faire sauter la mise en page.
struct AuthView: View {
    let session: AuthSession

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var resetSent = false
    @FocusState private var focusedField: Field?

    private enum Mode: Hashable {
        case signIn
        case signUp

        var title: String {
            switch self {
            case .signIn: "Se connecter"
            case .signUp: "Créer un compte"
            }
        }
    }

    private enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spaceL) {
                    masthead
                    accessCard
                    providers
                    footer
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.spaceM)
                .padding(.top, 56)
                .padding(.bottom, Theme.spaceXL)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.snappy(duration: 0.24), value: mode)
        .animation(.snappy(duration: 0.24), value: session.error)
        .onChange(of: email) {
            resetSent = false
            session.clearError()
        }
        .onChange(of: password) {
            session.clearError()
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: Theme.spaceS) {
            HStack(spacing: 10) {
                Image("gift")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Theme.accent)
                Text("MINEMASTER")
                    .font(.caption.weight(.heavy))
                    .tracking(3)
                    .foregroundStyle(Theme.textSecondary)
            }

            Text("Reprends\nl'expédition")
                .font(Theme.display(42, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(-6)

            Text("Un compte, une collection. Ta progression suit ton identité et se retrouve sur tes appareils.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Theme.spaceS)
    }

    private var accessCard: some View {
        VStack(spacing: Theme.spaceM) {
            modeSwitch

            VStack(spacing: Theme.spaceS) {
                field(
                    title: "Email",
                    prompt: "ton@email.com",
                    text: $email,
                    content: .username,
                    keyboard: .emailAddress,
                    isSecure: false
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                field(
                    title: "Mot de passe",
                    prompt: "8 caractères minimum",
                    text: $password,
                    content: mode == .signUp ? .newPassword : .password,
                    keyboard: .default,
                    isSecure: true
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
            }

            if let error = session.error {
                errorBanner(error)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if resetSent {
                Label("Email de réinitialisation envoyé.", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            submitButton

            if mode == .signIn {
                Button("Mot de passe oublié ?") {
                    Task { await requestReset() }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .opacity(isEmailValid && !session.isBusy ? 1 : 0.5)
                .disabled(!isEmailValid || session.isBusy)
            }
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
        .overlay(alignment: .top) {
            perforation
                .offset(y: 1)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            ForEach([Mode.signIn, Mode.signUp], id: \.self) { candidate in
                Button {
                    mode = candidate
                    session.clearError()
                    resetSent = false
                } label: {
                    Text(candidate.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(mode == candidate ? Theme.textPrimary : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if mode == candidate {
                                RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                                    .fill(Theme.surfaceRaised)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == candidate ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radiusS + 4, style: .continuous))
    }

    private func field(
        title: String,
        prompt: String,
        text: Binding<String>,
        content: UITextContentType,
        keyboard: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            Group {
                if isSecure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                }
            }
            .font(.body)
            .foregroundStyle(Theme.textPrimary)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.6)
            }
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if session.isBusy {
                    ProgressView()
                        .tint(Theme.background)
                } else {
                    Image(systemName: mode == .signIn ? "arrow.right" : "sparkles")
                        .font(.system(size: 13, weight: .heavy))
                }
                Text(session.isBusy ? "Connexion…" : mode.title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .opacity(canSubmit ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityLabel(mode.title)
    }

    private var providers: some View {
        VStack(spacing: Theme.spaceM) {
            HStack(spacing: Theme.spaceS) {
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 0.6)
                Text("ou")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 0.6)
            }

            Button {
                Task { await session.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Continuer avec Google")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.spaceM)
                .padding(.vertical, 13)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 0.6)
                }
            }
            .buttonStyle(.plain)
            .disabled(session.isBusy || !FirebaseRuntime.isGoogleSignInReady)
            .opacity(session.isBusy || !FirebaseRuntime.isGoogleSignInReady ? 0.5 : 1)

            if !FirebaseRuntime.isGoogleSignInReady {
                Text("Google s'active après activation du fournisseur, téléchargement du plist et déclaration de l'URL scheme (docs/FIREBASE.md).")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 6) {
                Button {} label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 16, weight: .medium))
                        Text("Continuer avec Apple")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.spaceM)
                    .padding(.vertical, 13)
                    .background(Theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 0.6)
                    }
                }
                .buttonStyle(.plain)
                .disabled(true)
                .accessibilityHint("Nécessite un compte Apple Developer payant et la capability Sign in with Apple.")

                Text("Apple : compte Apple Developer payant requis.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Connexion sécurisée Firebase", systemImage: "lock.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Text("Le compte sert à protéger ta progression. Aucune donnée n'est partagée avec un tiers.")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.spaceS)
    }

    private var perforation: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: Theme.spaceM, y: 0.5))
                path.addLine(to: CGPoint(x: proxy.size.width - Theme.spaceM, y: 0.5))
            }
            .stroke(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 5 && trimmed.contains("@") && trimmed.contains(".")
    }

    private var canSubmit: Bool {
        isEmailValid && password.count >= 8 && !session.isBusy
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        Task {
            switch mode {
            case .signIn:
                await session.signIn(email: email, password: password)
            case .signUp:
                await session.signUp(email: email, password: password)
            }
        }
    }

    private func requestReset() async {
        guard isEmailValid else { return }
        resetSent = await session.resetPassword(email: email)
    }

    private func errorBanner(_ error: AppError) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
            Text(error.errorDescription ?? "Connexion impossible.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }
}
