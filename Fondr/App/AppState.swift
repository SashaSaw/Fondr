import Foundation
import Observation

@Observable
final class AppState {
    let authService = AuthService()
    let pairService = PairService()
    let ourStoryService = OurStoryService()
    let profileImageService = ProfileImageService()
    let listService = ListService()
    let sessionService = SessionService()
    let calendarService = CalendarService()
    let notificationService = NotificationService()

    var isAuthenticated: Bool {
        authService.isAuthenticated
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
        guard let pair = pairService.currentPair,
              let myId = authService.currentUserId else { return nil }
        return (myId == pair.userA ? pair.userBProfile : pair.userAProfile)?.displayName
    }

    var partnerProfileImageUrl: String? {
        guard let pair = pairService.currentPair,
              let myId = authService.currentUserId else { return nil }
        return (myId == pair.userA ? pair.userBProfile : pair.userAProfile)?.profileImageUrl
    }

    var userTimezone: String? {
        authService.appUser?.timezone
    }

    func leavePartnership() {
        Task {
            await pairService.unpair()
            await authService.loadCurrentUser()
        }
    }

    func handlePairRemoved() {
        Task {
            await authService.loadCurrentUser()
        }
    }

    func setupPairListener() {
        if let pairId = authService.appUser?.pairId {
            pairService.listenToPair(pairId: pairId)
        }
    }

    func setupOurStoryListener() {
        if let pairId = pairService.currentPair?.id {
            ourStoryService.startListening(pairId: pairId)
        } else {
            ourStoryService.stopListening()
        }
    }

    func setupListListener() {
        if let pairId = pairService.currentPair?.id {
            listService.startListening(pairId: pairId)
        } else {
            listService.stopListening()
        }
    }

    func setupCalendarListener() {
        if let pairId = pairService.currentPair?.id,
           let partnerUid = authService.appUser?.partnerUid {
            calendarService.startListening(pairId: pairId, partnerUid: partnerUid)
        } else {
            calendarService.stopListening()
        }
    }

    func setupNotificationListener() {
        if let pairId = pairService.currentPair?.id,
           let partnerUid = authService.appUser?.partnerUid {
            notificationService.startListening(pairId: pairId, partnerUid: partnerUid)
        } else {
            notificationService.stopListening()
        }
    }

    func setupSessionListener() {
        if let pairId = pairService.currentPair?.id,
           let pair = pairService.currentPair {
            sessionService.startListening(pairId: pairId, pair: pair)
        } else {
            sessionService.stopListening()
        }
    }
}
