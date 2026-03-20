import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class SessionService {
    var activeSession: SwipeSession?
    var sessionHistory: [SwipeSession] = []
    var errorMessage: String?

    private var listener: ListenerRegistration?
    private var currentPairId: String?
    private var currentPair: Pair?
    private var db: Firestore { Firestore.firestore() }

    deinit {
        listener?.remove()
    }

    private var sessionsRef: CollectionReference? {
        guard let pairId = currentPairId else { return nil }
        return db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Sessions.collection)
    }

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Listener

    func startListening(pairId: String, pair: Pair) {
        stopListening()
        currentPairId = pairId
        currentPair = pair

        // Listen for active sessions
        listener = sessionsRef?
            .whereField("status", isEqualTo: SessionStatus.active.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    self?.errorMessage = error?.localizedDescription
                    return
                }
                let sessions = snapshot.documents.compactMap { try? $0.data(as: SwipeSession.self) }

                // Use earliest active session if multiple exist
                self.activeSession = sessions.sorted(by: { $0.createdAt < $1.createdAt }).first

                // Clean up stale sessions (>24h old)
                let staleThreshold = Date().addingTimeInterval(-24 * 60 * 60)
                for session in sessions where session.createdAt < staleThreshold {
                    if let id = session.id {
                        self.discardSession(sessionId: id)
                    }
                }
            }

        loadHistory()
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        activeSession = nil
        sessionHistory = []
        currentPairId = nil
        currentPair = nil
    }

    // MARK: - Session Management

    func startSession(listId: String, items: [ListItem]) async throws {
        guard let uid = currentUid,
              let sessionsRef else {
            throw SessionError.notAuthenticated
        }

        let suggestedItems = items.filter { $0.listId == listId && $0.status != .done }
        guard suggestedItems.count >= 3 else {
            throw SessionError.notEnoughItems
        }

        let matchedItems = suggestedItems.filter { $0.status == .matched }
        for item in matchedItems {
            guard let itemId = item.id else { continue }
            await updateItemStatus(itemId: itemId, to: .suggested)
        }

        let itemIds = suggestedItems.compactMap(\.id).shuffled()

        let session = SwipeSession(
            listId: listId,
            itemIds: itemIds,
            swipesA: [:],
            swipesB: [:],
            matches: [],
            status: .active,
            startedBy: uid,
            createdAt: Date()
        )

        try sessionsRef.addDocument(from: session)
    }

    func submitSwipe(sessionId: String, itemId: String, direction: String) {
        guard let sessionsRef,
              let uid = currentUid,
              let pair = currentPair else { return }

        let isUserA = uid == pair.userA
        let swipeField = isUserA ? "swipesA" : "swipesB"
        let otherSwipeField = isUserA ? "swipesB" : "swipesA"

        Task {
            do {
                let docRef = sessionsRef.document(sessionId)
                let snapshot = try await docRef.getDocument()
                guard var session = try? snapshot.data(as: SwipeSession.self) else { return }

                // Record the swipe
                if isUserA {
                    session.swipesA[itemId] = direction
                } else {
                    session.swipesB[itemId] = direction
                }

                var updateData: [String: Any] = [
                    swipeField: isUserA ? session.swipesA : session.swipesB
                ]

                // Check for match
                let otherSwipes = isUserA ? session.swipesB : session.swipesA
                if direction == "right", otherSwipes[itemId] == "right" {
                    session.matches.append(itemId)
                    updateData["matches"] = session.matches

                    // Update the ListItem status to matched
                    await updateItemStatus(itemId: itemId, to: .matched)
                }

                // Check if this user is done
                let mySwipes = isUserA ? session.swipesA : session.swipesB
                let allUsersDone = mySwipes.count == session.itemIds.count && otherSwipes.count == session.itemIds.count

                if allUsersDone {
                    updateData["status"] = SessionStatus.complete.rawValue
                    updateData["completedAt"] = Date()
                }

                try await docRef.updateData(updateData)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func chooseMatch(sessionId: String, chosenItemId: String, allMatchIds: [String]) {
        guard let sessionsRef else { return }

        Task {
            do {
                // Set the chosen item on the session
                try await sessionsRef.document(sessionId).updateData([
                    "chosenItemId": chosenItemId
                ])

                // Revert non-chosen matches back to suggested
                for matchId in allMatchIds where matchId != chosenItemId {
                    await updateItemStatus(itemId: matchId, to: .suggested)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func discardSession(sessionId: String) {
        Task {
            do {
                try await sessionsRef?.document(sessionId).delete()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadHistory() {
        Task {
            do {
                let snapshot = try await sessionsRef?
                    .whereField("status", isEqualTo: SessionStatus.complete.rawValue)
                    .order(by: "completedAt", descending: true)
                    .limit(to: 10)
                    .getDocuments()

                let sessions = snapshot?.documents.compactMap { try? $0.data(as: SwipeSession.self) } ?? []
                await MainActor.run {
                    self.sessionHistory = sessions
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Helpers

    func mySwipeCount(in session: SwipeSession) -> Int {
        guard let uid = currentUid, let pair = currentPair else { return 0 }
        return uid == pair.userA ? session.swipesA.count : session.swipesB.count
    }

    func partnerSwipeCount(in session: SwipeSession) -> Int {
        guard let uid = currentUid, let pair = currentPair else { return 0 }
        return uid == pair.userA ? session.swipesB.count : session.swipesA.count
    }

    func hasUserFinished(session: SwipeSession) -> Bool {
        mySwipeCount(in: session) == session.itemIds.count
    }

    private func updateItemStatus(itemId: String, to status: ItemStatus) async {
        guard let pairId = currentPairId else { return }

        do {
            try await db.collection(Constants.Firestore.pairsCollection)
                .document(pairId)
                .collection(Constants.Lists.collection)
                .document(itemId)
                .updateData([
                    "status": status.rawValue,
                    "updatedAt": Date()
                ])
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    enum SessionError: LocalizedError {
        case notAuthenticated
        case notEnoughItems

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: "Not authenticated"
            case .notEnoughItems: "Need at least 3 items to start a session"
            }
        }
    }
}
