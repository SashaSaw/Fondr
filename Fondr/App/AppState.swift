import Foundation
import Observation

@Observable
final class AppState {
    let authService = AuthService()
    let pairService = PairService()
    let vaultService = VaultService()

    var isAuthenticated: Bool {
        authService.currentUser != nil
    }

    var needsOnboarding: Bool {
        guard let appUser = authService.appUser else { return true }
        return !(appUser.onboardingCompleted ?? false)
    }

    var isPaired: Bool {
        guard let pair = pairService.currentPair else { return false }
        return pair.status == .active
    }

    var partnerName: String? {
        authService.appUser?.partnerName
    }

    var userTimezone: String? {
        authService.appUser?.timezone
    }

    func setupPairListener() {
        if let pairId = authService.appUser?.pairId {
            pairService.listenToPair(pairId: pairId)
        }
    }

    func setupVaultListener() {
        if let pairId = pairService.currentPair?.id {
            vaultService.startListening(pairId: pairId)
        } else {
            vaultService.stopListening()
        }
    }
}
