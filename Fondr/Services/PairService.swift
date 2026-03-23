import Foundation

@Observable
final class PairService {
    var currentPair: Pair?
    var errorMessage: String?
    var isLoading = false

    // MARK: - Create Pair

    func createPair() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let pair: Pair = try await APIClient.shared.post("/pairs", body: EmptyBody())
                await MainActor.run {
                    self.currentPair = pair
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Join Pair

    func joinPair(inviteCode: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let body = JoinPairRequest(inviteCode: inviteCode.uppercased())
                let pair: Pair = try await APIClient.shared.post("/pairs/join", body: body)
                await MainActor.run {
                    self.currentPair = pair
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Listen to Pair (load + WebSocket)

    func listenToPair(pairId: String) {
        Task {
            do {
                let pair: Pair = try await APIClient.shared.get("/pairs/\(pairId)")
                await MainActor.run {
                    self.currentPair = pair
                }
            } catch {
                await MainActor.run {
                    self.currentPair = nil
                }
            }
        }

        // WebSocket updates
        WebSocketManager.shared.on("pair:updated") { [weak self] (pair: Pair) in
            self?.currentPair = pair
        }
    }

    // MARK: - Cancel Pending Pair

    func cancelPair() {
        guard let pair = currentPair, pair.status == .pending else { return }

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pair.id)") as SuccessResponse
                await MainActor.run {
                    self.currentPair = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Unpair

    func unpair() {
        guard let pair = currentPair else { return }
        isLoading = true

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pair.id)") as SuccessResponse
                await MainActor.run {
                    self.currentPair = nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Request DTOs

private struct JoinPairRequest: Encodable {
    let inviteCode: String
}

struct EmptyBody: Encodable {}
