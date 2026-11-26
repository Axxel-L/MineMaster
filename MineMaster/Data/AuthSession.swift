import FirebaseAuth
import Foundation
import GoogleSignIn
import Observation
import UIKit

/// Session d'authentification Firebase et fournisseurs activés.
///
/// L'application exige un compte : tant que la phase n'est pas `signedIn`, aucun
/// accès à la progression n'est exposé. La configuration Firebase est faite hors
/// du `MainActor` pour laisser la première image s'afficher immédiatement.
@Observable
@MainActor
final class AuthSession {
    /// Compte authentifié, réduit aux informations affichables.
    struct Account: Equatable, Sendable {
        /// Identifiant Firebase, opaque et non devinable.
        let id: String
        /// Adresse email du compte, vide si le fournisseur n'en expose pas.
        let email: String
        /// Nom affiché par le fournisseur, `nil` s'il n'est pas fourni.
        let displayName: String?
        /// Fournisseur utilisé pour la connexion.
        let provider: Provider

        /// Nom lisible du compte.
        var label: String {
            if let displayName, !displayName.isEmpty { return displayName }
            if !email.isEmpty { return email }
            return "Explorateur"
        }

        init(id: String, email: String, displayName: String?, provider: Provider) {
            self.id = id
            self.email = email
            self.displayName = displayName
            self.provider = provider
        }

        init(user: User) {
            let providerID = user.providerData.first?.providerID ?? ""
            self.init(
                id: user.uid,
                email: user.email ?? "",
                displayName: user.displayName,
                provider: Provider(rawValue: providerID) ?? .unknown
            )
        }
    }

    /// Fournisseur d'identité reconnu.
    enum Provider: String, Sendable {
        case email = "password"
        case google = "google.com"
        case apple = "apple.com"
        case unknown

        /// Libellé affiché dans le profil.
        var displayName: String {
            switch self {
            case .email: "Email"
            case .google: "Google"
            case .apple: "Apple"
            case .unknown: "Compte"
            }
        }
    }

    /// État de démarrage ou d'authentification.
    enum Phase: Equatable {
        /// Firebase s'initialise.
        case loading
        /// Configuration absente ou invalide.
        case unavailable(AppError)
        /// Aucun compte connecté.
        case signedOut
        /// Compte connecté.
        case signedIn(Account)
    }

    /// Indique si le bouton Sign in with Apple peut aboutir sur ce binaire.
    ///
    /// `false` tant que la capability `com.apple.developer.applesignin` n'est pas
    /// provisionnée, ce qui exige un compte Apple Developer Program payant.
    static let isAppleSignInAvailable = false

    private(set) var phase: Phase = .loading
    private(set) var isBusy = false
    private(set) var error: AppError?

    /// Compte connecté, `nil` sinon.
    var account: Account? {
        if case .signedIn(let account) = phase { return account }
        return nil
    }

    /// Initialise Firebase puis restaure la session enregistrée.
    func start() async {
        let configured = await Task.detached(priority: .userInitiated) {
            FirebaseRuntime.configure()
        }.value

        guard configured else {
            phase = .unavailable(.authUnavailable)
            return
        }
        if let user = Auth.auth().currentUser {
            phase = .signedIn(Account(user: user))
        } else {
            phase = .signedOut
        }
    }

    /// Connecte un compte email et mot de passe.
    ///
    /// - Parameters:
    ///   - email: Adresse saisie.
    ///   - password: Mot de passe saisi.
    /// - Returns: `true` si la connexion a réussi.
    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        await perform {
            let email = try Self.validatedEmail(email)
            try Self.validate(password: password)
            try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }

    /// Crée un compte email et mot de passe, puis ouvre la session.
    ///
    /// - Parameters:
    ///   - email: Adresse saisie.
    ///   - password: Mot de passe saisi.
    /// - Returns: `true` si la création a réussi.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        await perform {
            let email = try Self.validatedEmail(email)
            try Self.validate(password: password)
            try await Auth.auth().createUser(withEmail: email, password: password)
        }
    }

    /// Envoie un email de réinitialisation du mot de passe.
    ///
    /// - Parameter email: Adresse du compte.
    /// - Returns: `true` si Firebase a accepté la demande.
    @discardableResult
    func resetPassword(email: String) async -> Bool {
        await perform {
            let email = try Self.validatedEmail(email)
            try await Auth.auth().sendPasswordReset(withEmail: email)
        }
    }

    /// Ouvre une session avec Google Sign-In puis relie le jeton à Firebase.
    ///
    /// - Returns: `true` si la connexion a réussi.
    /// - Throws: `AppError.authGoogleNotConfigured` si le fournisseur ou l'URL
    ///   scheme manque dans la configuration.
    @discardableResult
    func signInWithGoogle() async -> Bool {
        guard let clientID = FirebaseRuntime.googleClientID,
              FirebaseRuntime.isGoogleSignInReady,
              let presenter = Self.presentingViewController() else {
            error = .authGoogleNotConfigured
            return false
        }
        return await perform {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AppError.authInvalidCredentials
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
        }
    }

    /// Ferme la session courante sur cet appareil.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
        } catch {
            self.error = Self.map(error)
        }
        phase = .signedOut
    }

    /// Efface l'erreur affichée par l'interface.
    func clearError() {
        error = nil
    }

    private func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        error = nil
        defer { isBusy = false }

        do {
            try await operation()
            if let user = Auth.auth().currentUser {
                phase = .signedIn(Account(user: user))
            } else {
                phase = .signedOut
            }
            return true
        } catch let appError as AppError {
            self.error = appError
        } catch {
            self.error = Self.map(error)
        }
        return false
    }

    private static func validate(password: String) throws {
        guard password.count >= 8, password.count <= 128 else { throw AppError.authWeakPassword }
    }

    private static func validatedEmail(_ raw: String) throws -> String {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (5...254).contains(email.count),
              !email.contains(" "),
              email.filter({ $0 == "@" }).count == 1,
              let at = email.firstIndex(of: "@") else {
            throw AppError.authInvalidInput
        }
        let local = email[..<at]
        let host = email[email.index(after: at)...]
        guard !local.isEmpty,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix(".") else {
            throw AppError.authInvalidInput
        }
        return email
    }

    private static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        let nsError = error as NSError

        if nsError.domain == AuthErrors.domain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .emailAlreadyInUse: return .authEmailInUse
            case .invalidEmail, .invalidCredential, .userNotFound, .wrongPassword:
                return .authInvalidCredentials
            case .weakPassword: return .authWeakPassword
            case .userDisabled: return .authUserDisabled
            case .tooManyRequests: return .authTooManyRequests
            case .networkError: return .authNetwork
            case .operationNotAllowed: return .authProviderDisabled
            case .appNotAuthorized, .invalidAPIKey: return .authAppNotAuthorized
            default: return .authUnknown
            }
        }

        if nsError.domain == kGIDSignInErrorDomain,
           nsError.code == GIDSignInError.canceled.rawValue {
            return .authCancelled
        }
        if nsError.domain == NSURLErrorDomain { return .authNetwork }
        return .authUnknown
    }

    private static func presentingViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
