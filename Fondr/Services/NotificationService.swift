import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

@Observable
final class NotificationService {
    private var db: Firestore { Firestore.firestore() }
    private var listeners: [ListenerRegistration] = []
    private var initialLoadComplete: [String: Bool] = [:]

    func startListening(pairId: String, partnerUid: String) {
        stopListening()

        listenForVaultFacts(pairId: pairId, partnerUid: partnerUid)
        listenForListItems(pairId: pairId, partnerUid: partnerUid)
        listenForSessions(pairId: pairId, partnerUid: partnerUid)
        listenForEvents(pairId: pairId, partnerUid: partnerUid)
        listenForAvailability(pairId: pairId, partnerUid: partnerUid)
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        initialLoadComplete.removeAll()
    }

    // MARK: - Vault Facts

    private func listenForVaultFacts(pairId: String, partnerUid: String) {
        let key = "vault"
        let listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Vault.collection)
            .whereField("addedBy", isEqualTo: partnerUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                guard self.markLoaded(key) else { return }
                guard let doc = snapshot.documentChanges.first(where: { $0.type == .added }) else { return }

                self.scheduleLocal(
                    title: "New Vault Entry",
                    body: "Your partner added something to your vault",
                    type: "vault"
                )
            }
        listeners.append(listener)
    }

    // MARK: - List Items

    private func listenForListItems(pairId: String, partnerUid: String) {
        let key = "lists"
        let listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Lists.collection)
            .whereField("addedBy", isEqualTo: partnerUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                guard self.markLoaded(key) else { return }
                guard let doc = snapshot.documentChanges.first(where: { $0.type == .added }) else { return }

                let title = doc.document.data()["title"] as? String ?? "something"
                self.scheduleLocal(
                    title: "New Idea Added",
                    body: "Your partner added: \(title)",
                    type: "listItem"
                )
            }
        listeners.append(listener)
    }

    // MARK: - Sessions

    private func listenForSessions(pairId: String, partnerUid: String) {
        let key = "sessions"
        let listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Sessions.collection)
            .whereField("startedBy", isEqualTo: partnerUid)
            .whereField("status", isEqualTo: SessionStatus.active.rawValue)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                guard self.markLoaded(key) else { return }
                guard snapshot.documentChanges.contains(where: { $0.type == .added }) else { return }

                self.scheduleLocal(
                    title: "Swipe Time!",
                    body: "Your partner wants to decide — swipe time!",
                    type: "session"
                )
            }
        listeners.append(listener)
    }

    // MARK: - Events

    private func listenForEvents(pairId: String, partnerUid: String) {
        let key = "events"
        let listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Calendar.eventsCollection)
            .whereField("createdBy", isEqualTo: partnerUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                guard self.markLoaded(key) else { return }
                guard let doc = snapshot.documentChanges.first(where: { $0.type == .added }) else { return }

                let title = doc.document.data()["title"] as? String ?? "a date"
                self.scheduleLocal(
                    title: "Date Proposed!",
                    body: "Your partner proposed: \(title)",
                    type: "event"
                )
            }
        listeners.append(listener)
    }

    // MARK: - Availability

    private func listenForAvailability(pairId: String, partnerUid: String) {
        let key = "availability"
        let listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Calendar.collection)
            .whereField("userId", isEqualTo: partnerUid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                guard self.markLoaded(key) else { return }
                guard snapshot.documentChanges.contains(where: { $0.type == .added || $0.type == .removed }) else { return }

                self.scheduleLocal(
                    title: "Schedule Updated",
                    body: "Your partner updated their availability",
                    type: "availability"
                )
            }
        listeners.append(listener)
    }

    // MARK: - Helpers

    /// Returns true if this is NOT the initial load (i.e. we should notify).
    /// First call per key returns false to skip the initial snapshot.
    private func markLoaded(_ key: String) -> Bool {
        if initialLoadComplete[key] == true {
            return true
        }
        initialLoadComplete[key] = true
        return false
    }

    private func scheduleLocal(title: String, body: String, type: String) {
        // Don't notify if app is in foreground
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["type": type]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
