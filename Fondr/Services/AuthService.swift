import Foundation
import AuthenticationServices
import CryptoKit

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AppUser
}

@Observable
final class AuthService {
    var appUser: AppUser?
    var errorMessage: String?
    var isLoading = false

    var isAuthenticated: Bool {
        TokenStore.shared.isLoggedIn
    }

    var currentUserId: String? {
        TokenStore.shared.userId
    }

    func start() {
        // Restore session from keychain
        if TokenStore.shared.isLoggedIn {
            Task {
                await loadCurrentUser()
            }
        }
    }

    // MARK: - Sign In with Apple

    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to process Apple Sign In."
                return
            }

            let fullName = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")

            isLoading = true
            Task {
                do {
                    let body = AppleSignInRequest(
                        identityToken: idTokenString,
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                    let response: AuthResponse = try await APIClient.shared.post("/auth/apple", body: body)
                    await handleAuthResponse(response)
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
                let body = LoginRequest(email: email, password: password)
                let response: AuthResponse = try await APIClient.shared.post("/auth/login", body: body)
                await handleAuthResponse(response)
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
                let body = RegisterRequest(email: email, password: password, displayName: displayName)
                let response: AuthResponse = try await APIClient.shared.post("/auth/register", body: body)
                await handleAuthResponse(response)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func signOut() {
        TokenStore.shared.clear()
        WebSocketManager.shared.disconnect()
        appUser = nil
    }

    // MARK: - User Profile

    func updateUserDoc(_ updates: [String: Any]) {
        // Convert to Encodable for the API
        Task {
            do {
                let body = UserUpdateBody(updates)
                let updated: AppUser = try await APIClient.shared.patch("/users/me", body: body)
                await MainActor.run {
                    self.appUser = updated
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadCurrentUser() async {
        do {
            let user: AppUser = try await APIClient.shared.get("/users/me")
            await MainActor.run {
                self.appUser = user
            }
        } catch {
            // Token might be invalid
            if case APIError.unauthorized = error {
                await MainActor.run {
                    TokenStore.shared.clear()
                    self.appUser = nil
                }
            }
        }
    }

    func registerAPNsToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            let body = APNsTokenBody(token: tokenString)
            try? await APIClient.shared.post("/users/me/apns-token", body: body) as SuccessResponse
        }
    }

    // MARK: - Private

    @MainActor
    private func handleAuthResponse(_ response: AuthResponse) {
        TokenStore.shared.accessToken = response.accessToken
        TokenStore.shared.refreshToken = response.refreshToken
        TokenStore.shared.userId = response.user.id
        appUser = response.user
        isLoading = false

        // Connect WebSocket after auth
        WebSocketManager.shared.connect()
    }
}

// MARK: - Request DTOs

private struct AppleSignInRequest: Encodable {
    let identityToken: String
    let fullName: String?
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String
}

private struct APNsTokenBody: Encodable {
    let token: String
}

struct UserUpdateBody: Encodable {
    let displayName: String?
    let timezone: String?
    let partnerName: String?
    let onboardingCompleted: Bool?

    init(_ dict: [String: Any]) {
        self.displayName = dict["displayName"] as? String
        self.timezone = dict["timezone"] as? String
        self.partnerName = dict["partnerName"] as? String
        self.onboardingCompleted = dict["onboardingCompleted"] as? Bool
    }
}
