import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class VaultService {
    var facts: [VaultFact] = []
    var errorMessage: String?
    var isLoading = false

    private var listener: ListenerRegistration?
    private var currentPairId: String?
    private var db: Firestore { Firestore.firestore() }

    deinit {
        listener?.remove()
    }

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

        listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Vault.collection)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot else {
                    self?.errorMessage = error?.localizedDescription
                    return
                }
                self?.facts = snapshot.documents.compactMap { try? $0.data(as: VaultFact.self) }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        facts = []
        currentPairId = nil
    }

    // MARK: - CRUD

    func addFact(category: FactCategory, label: String, value: String) {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        let now = Date()
        let fact = VaultFact(
            category: category,
            label: label,
            value: value,
            addedBy: uid,
            createdAt: now,
            updatedAt: now
        )

        Task {
            do {
                let colRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Vault.collection)
                try colRef.addDocument(from: fact)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func updateFact(factId: String, label: String, value: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Vault.collection)
                    .document(factId)
                    .updateData([
                        "label": label,
                        "value": value,
                        "updatedAt": Date()
                    ])
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteFact(factId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Vault.collection)
                    .document(factId)
                    .delete()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
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
