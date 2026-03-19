import Foundation
import FirebaseAuth
import FirebaseFirestore
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

    func leavePartnership() {
        pairService.unpair()
        // Reset local state immediately so needsOnboarding becomes true
        // before the Firestore listener fires
        authService.appUser?.onboardingCompleted = nil
        authService.appUser?.partnerName = nil
    }

    /// Called when currentPair becomes nil (either we left or partner left).
    /// Resets pair-related fields on the current user's Firestore doc so they re-onboard.
    func handlePairRemoved() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // If the user still has a pairId locally, the pair was deleted by the partner
        guard authService.appUser?.pairId != nil else { return }

        let db = Firestore.firestore()
        db.collection(Constants.Firestore.usersCollection).document(uid).updateData([
            "pairId": FieldValue.delete(),
            "partnerUid": FieldValue.delete(),
            "partnerName": FieldValue.delete(),
            "onboardingCompleted": FieldValue.delete()
        ])

        // Update local state immediately
        authService.appUser?.pairId = nil
        authService.appUser?.partnerUid = nil
        authService.appUser?.onboardingCompleted = nil
        authService.appUser?.partnerName = nil
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
