import Foundation

@Observable
final class VaultService {
    var facts: [VaultFact] = []
    var errorMessage: String?
    var isLoading = false

    private var currentPairId: String?

    // MARK: - Computed

    var factsByCategory: [FactCategory: [VaultFact]] {
        var grouped = Dictionary(grouping: facts) { $0.category }
        for category in FactCategory.allCases where grouped[category] == nil {
            grouped[category] = []
        }
        return grouped
    }

    // MARK: - Listener

    func startListening(pairId: String) {
        stopListening()
        currentPairId = pairId

        // Initial load via REST
        Task {
            do {
                let loaded: [VaultFact] = try await APIClient.shared.get("/pairs/\(pairId)/vault")
                await MainActor.run { self.facts = loaded }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }

        // Real-time updates via WebSocket
        WebSocketManager.shared.on("vault:created") { [weak self] (fact: VaultFact) in
            self?.facts.insert(fact, at: 0)
        }
        WebSocketManager.shared.on("vault:updated") { [weak self] (fact: VaultFact) in
            if let i = self?.facts.firstIndex(where: { $0.id == fact.id }) {
                self?.facts[i] = fact
            }
        }
        WebSocketManager.shared.on("vault:deleted") { [weak self] (payload: DeletePayload) in
            self?.facts.removeAll { $0.id == payload.id }
        }
    }

    func stopListening() {
        facts = []
        currentPairId = nil
    }

    // MARK: - CRUD

    func addFact(category: FactCategory, label: String, value: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = CreateVaultFactBody(category: category.rawValue, label: label, value: value)
                let _: VaultFact = try await APIClient.shared.post("/pairs/\(pairId)/vault", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func updateFact(factId: String, label: String, value: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = UpdateVaultFactBody(label: label, value: value)
                let _: VaultFact = try await APIClient.shared.patch("/pairs/\(pairId)/vault/\(factId)", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteFact(factId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pairId)/vault/\(factId)")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - Search

    func searchFacts(query: String) -> [VaultFact] {
        let lowered = query.lowercased()
        return facts.filter {
            $0.label.lowercased().contains(lowered) ||
            $0.value.lowercased().contains(lowered)
        }
    }
}

// MARK: - Request DTOs

private struct CreateVaultFactBody: Encodable {
    let category: String
    let label: String
    let value: String
}

private struct UpdateVaultFactBody: Encodable {
    let label: String
    let value: String
}

struct DeletePayload: Decodable {
    let id: String
}

struct ItemStatusUpdate: Encodable {
    let status: String
}
