import Foundation

@Observable
final class SessionService {
    var activeSession: SwipeSession?
    var sessionHistory: [SwipeSession] = []
    var errorMessage: String?

    private var currentPairId: String?
    private var currentPair: Pair?

    private var currentUid: String? {
        TokenStore.shared.userId
    }

    // MARK: - Listener

    func startListening(pairId: String, pair: Pair) {
        stopListening()
        currentPairId = pairId
        currentPair = pair

        // Initial load
        Task {
            do {
                let session: SwipeSession? = try await APIClient.shared.get("/pairs/\(pairId)/sessions/active")
                await MainActor.run { self.activeSession = session }
            } catch {
                // No active session is fine
                await MainActor.run { self.activeSession = nil }
            }
        }
        loadHistory()

        // WebSocket events
        WebSocketManager.shared.on("session:created") { [weak self] (session: SwipeSession) in
            self?.activeSession = session
        }
        WebSocketManager.shared.on("session:updated") { [weak self] (session: SwipeSession) in
            if session.status == .complete {
                self?.activeSession = nil
                self?.sessionHistory.insert(session, at: 0)
            } else {
                self?.activeSession = session
            }
        }
        WebSocketManager.shared.on("session:deleted") { [weak self] (payload: DeletePayload) in
            if self?.activeSession?.id == payload.id {
                self?.activeSession = nil
            }
        }
    }

    func stopListening() {
        WebSocketManager.shared.removeHandlers(for: [
            "session:created", "session:updated", "session:deleted"
        ])
        activeSession = nil
        sessionHistory = []
        currentPairId = nil
        currentPair = nil
    }

    // MARK: - Session Management

    func startSession(listId: String, items: [ListItem]) async throws {
        guard let pairId = currentPairId else {
            throw SessionError.notAuthenticated
        }

        let suggestedItems = items.filter { $0.listId == listId && $0.status != .done }
        guard suggestedItems.count >= 3 else {
            throw SessionError.notEnoughItems
        }

        let body = StartSessionBody(listId: listId)
        let session: SwipeSession = try await APIClient.shared.post("/pairs/\(pairId)/sessions", body: body)
        await MainActor.run {
            self.activeSession = session
        }
    }

    func submitSwipe(sessionId: String, itemId: String, direction: String) async throws -> SwipeSession {
        guard let pairId = currentPairId else { throw SessionError.notAuthenticated }

        let body = SwipeBody(itemId: itemId, direction: direction)
        let session: SwipeSession = try await APIClient.shared.post(
            "/pairs/\(pairId)/sessions/\(sessionId)/swipe",
            body: body
        )
        await MainActor.run {
            self.activeSession = session
        }
        return session
    }

    func chooseMatch(sessionId: String, chosenItemId: String, allMatchIds: [String]) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = ChooseBody(chosenItemId: chosenItemId, allMatchIds: allMatchIds)
                let _: SwipeSession = try await APIClient.shared.post(
                    "/pairs/\(pairId)/sessions/\(sessionId)/choose",
                    body: body
                )
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func discardSession(sessionId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pairId)/sessions/\(sessionId)")
                await MainActor.run { self.activeSession = nil }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func loadHistory() {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let sessions: [SwipeSession] = try await APIClient.shared.get("/pairs/\(pairId)/sessions/history?limit=10")
                await MainActor.run { self.sessionHistory = sessions }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
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

// MARK: - Request DTOs

private struct StartSessionBody: Encodable {
    let listId: String
}

private struct SwipeBody: Encodable {
    let itemId: String
    let direction: String
}

private struct ChooseBody: Encodable {
    let chosenItemId: String
    let allMatchIds: [String]
}
