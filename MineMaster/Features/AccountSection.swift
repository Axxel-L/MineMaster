import SwiftUI

/// Carte de compte du profil : identité, état de synchronisation et déconnexion.
struct AccountSection: View {
    @Environment(AuthSession.self) private var session
    @Environment(ProgressSync.self) private var sync

    @State private var confirmSignOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            header
            if let account = session.account {
                identity(account)
                syncRow
                signOutRow
            }
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
        .confirmationDialog(
            "Se déconnecter ?",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter", role: .destructive) {
                sync.suspend()
                session.signOut()
            }
        } message: {
            Text("Ta progression locale reste sur cet appareil et repartira vers ton compte à la prochaine connexion, même hors ligne.")
        }
    }

    private var header: some View {
        HStack {
            Text("Compte")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let provider = session.account?.provider {
                Text(provider.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
            }
        }
    }

    private func identity(_ account: AuthSession.Account) -> some View {
        HStack(spacing: 12) {
            Text(initial(of: account))
                .font(Theme.display(19, weight: .heavy))
                .foregroundStyle(Theme.background)
                .frame(width: 42, height: 42)
                .background(Theme.moss, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(account.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if !account.email.isEmpty {
                    Text(account.email)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Compte \(account.label), \(account.provider.displayName)")
    }

    private var syncRow: some View {
        HStack(spacing: 10) {
            Image(systemName: syncIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(syncTint)
                .frame(width: 18)
            Text(syncLabel)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if case .syncing = sync.state {
                ProgressView()
                    .controlSize(.mini)
                    .tint(Theme.textSecondary)
            } else if sync.lastError != nil {
                Button("Réessayer") {
                    sync.retry()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.copper)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var signOutRow: some View {
        Button {
            confirmSignOut = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 18)
                Text("Se déconnecter")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
            }
            .foregroundStyle(Theme.danger)
            .padding(.top, Theme.spaceXS)
        }
        .buttonStyle(.plain)
    }

    private func initial(of account: AuthSession.Account) -> String {
        let source = account.displayName?.isEmpty == false ? account.displayName ?? "" : account.email
        guard let first = source.first else { return "M" }
        return String(first).uppercased()
    }

    private var syncIcon: String {
        switch sync.state {
        case .idle: "icloud"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced: "checkmark.icloud.fill"
        case .pending: "icloud.slash"
        }
    }

    private var syncTint: Color {
        switch sync.state {
        case .synced: Theme.accent
        case .pending: Theme.copper
        case .idle, .syncing: Theme.textSecondary
        }
    }

    private var syncLabel: String {
        switch sync.state {
        case .idle: "Progression locale prête"
        case .syncing: "Synchronisation en cours"
        case .synced(let date): "Synchronisé \(date.formatted(.relative(presentation: .named)))"
        case .pending:
            sync.lastError?.errorDescription ?? "Modifications en attente d'envoi"
        }
    }
}
