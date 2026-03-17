import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User?
    var appUser: AppUser?
    var errorMessage: String?
    var isLoading = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private var currentNonce: String?
    private var db: Firestore { Firestore.firestore() }

    func start() {

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in

            self?.currentUser = user
            if let uid = user?.uid {
                self?.ensureUserDocExists(uid: uid, email: user?.email ?? "")
                self?.listenToUserDoc(uid: uid)
            } else {
                self?.userListener?.remove()
                self?.appUser = nil
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        userListener?.remove()
    }

    // MARK: - Sign In with Apple

    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Unable to process Apple Sign In."
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            isLoading = true
            Task {
                do {
                    let authResult = try await Auth.auth().signIn(with: credential)
                    let uid = authResult.user.uid

                    // Create user doc if first sign-in
                    let docRef = db.collection(Constants.Firestore.usersCollection).document(uid)
                    let snapshot = try await docRef.getDocument()
                    if !snapshot.exists {
                        let displayName = [
                            appleIDCredential.fullName?.givenName,
                            appleIDCredential.fullName?.familyName
                        ].compactMap { $0 }.joined(separator: " ")

                        let newUser = AppUser(
                            displayName: displayName.isEmpty ? "User" : displayName,
                            email: appleIDCredential.email ?? authResult.user.email ?? ""
                        )
                        try docRef.setData(from: newUser)
                    }

                    await MainActor.run {
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await Auth.auth().signIn(withEmail: email, password: password)
                await MainActor.run { self.isLoading = false }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func signUp(email: String, password: String, displayName: String) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                let uid = result.user.uid

                let newUser = AppUser(displayName: displayName, email: email)
                try db.collection(Constants.Firestore.usersCollection)
                    .document(uid)
                    .setData(from: newUser)

                await MainActor.run { self.isLoading = false }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - User Doc

    func updateUserDoc(_ updates: [String: Any]) {
        guard let uid = currentUser?.uid else { return }
        db.collection(Constants.Firestore.usersCollection).document(uid).setData(updates, merge: true)
    }

    private func ensureUserDocExists(uid: String, email: String) {
        let docRef = db.collection(Constants.Firestore.usersCollection).document(uid)
        Task {
            do {
                let snapshot = try await docRef.getDocument()
                print("[AUTH] ensureUserDoc: exists=\(snapshot.exists)")
                if !snapshot.exists {
                    let newUser = AppUser(
                        displayName: Auth.auth().currentUser?.displayName ?? "User",
                        email: email
                    )
                    try docRef.setData(from: newUser)
                    print("[AUTH] ensureUserDoc: created new doc")
                }
            } catch {
                print("[AUTH] ensureUserDoc error: \(error)")
            }
        }
    }

    private func listenToUserDoc(uid: String) {
        userListener?.remove()
        userListener = db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    print("[AUTH] listenToUserDoc error: \(error)")
                    return
                }
                guard let snapshot else {
                    print("[AUTH] listenToUserDoc: no snapshot")
                    return
                }
                print("[AUTH] listenToUserDoc: exists=\(snapshot.exists), data=\(snapshot.data() ?? [:])")
                if snapshot.exists {
                    do {
                        self?.appUser = try snapshot.data(as: AppUser.self)
                        print("[AUTH] listenToUserDoc: appUser.onboardingCompleted=\(self?.appUser?.onboardingCompleted ?? false)")
                    } catch {
                        print("[AUTH] listenToUserDoc decode error: \(error)")
                    }
                }
            }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
