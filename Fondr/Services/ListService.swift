import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class ListService {
    var items: [ListItem] = []
    var lists: [SharedList] = []
    var errorMessage: String?
    var isLoading = false

    private var listener: ListenerRegistration?
    private var listsListener: ListenerRegistration?
    private var currentPairId: String?
    private var db: Firestore { Firestore.firestore() }

    deinit {
        listener?.remove()
        listsListener?.remove()
    }

    // MARK: - Computed

    func items(for listId: String) -> [ListItem] {
        items.filter { $0.listId == listId }
    }

    func items(for listId: String, status: ItemStatus?) -> [ListItem] {
        items.filter { item in
            item.listId == listId && (status == nil || item.status == status)
        }
    }

    func itemCount(for listId: String) -> Int {
        items.filter { $0.listId == listId }.count
    }

    func matchedCount(for listId: String) -> Int {
        items.filter { $0.listId == listId && $0.status == .matched }.count
    }

    func isWatchList(_ listId: String) -> Bool {
        guard let list = lists.first(where: { $0.id == listId }) else { return false }
        return list.title.contains("Watch") || list.emoji == "🍿"
    }

    // MARK: - Listener

    func startListening(pairId: String) {
        stopListening()
        currentPairId = pairId

        // Items listener
        listener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Lists.collection)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot else {
                    self?.errorMessage = error?.localizedDescription
                    return
                }
                self?.items = snapshot.documents.compactMap { try? $0.data(as: ListItem.self) }
            }

        // Lists-meta listener
        listsListener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Lists.metaCollection)
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                let decoded = snapshot.documents.compactMap { try? $0.data(as: SharedList.self) }
                self.lists = decoded

                // First snapshot: seed or migrate if needed
                if decoded.isEmpty {
                    if self.items.isEmpty {
                        self.seedDefaultLists()
                    } else {
                        self.migrateFromCategories()
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        listsListener?.remove()
        listsListener = nil
        items = []
        lists = []
        currentPairId = nil
    }

    // MARK: - SharedList CRUD

    func createList(title: String, emoji: String, subtitle: String?) {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        let list = SharedList(
            title: title,
            emoji: emoji,
            subtitle: subtitle,
            createdBy: uid,
            createdAt: Date(),
            sortOrder: lists.count
        )

        Task {
            do {
                let colRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.metaCollection)
                try colRef.addDocument(from: list)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func updateList(listId: String, title: String, emoji: String, subtitle: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.metaCollection)
                    .document(listId)
                    .updateData([
                        "title": title,
                        "emoji": emoji,
                        "subtitle": subtitle as Any
                    ])
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteList(listId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                // Delete the list meta doc
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.metaCollection)
                    .document(listId)
                    .delete()

                // Batch-delete all items belonging to this list
                let itemsRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.collection)
                let snapshot = try await itemsRef.whereField("listId", isEqualTo: listId).getDocuments()
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Item CRUD

    func addItem(listId: String, title: String, description: String?, imageUrl: String?, metadata: MovieMetadata?) {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        let now = Date()
        let item = ListItem(
            title: title,
            description: description,
            imageUrl: imageUrl,
            listId: listId,
            addedBy: uid,
            status: .suggested,
            metadata: metadata,
            createdAt: now,
            updatedAt: now
        )

        Task {
            do {
                let colRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.collection)
                try colRef.addDocument(from: item)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func updateItem(itemId: String, title: String, description: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.collection)
                    .document(itemId)
                    .updateData([
                        "title": title,
                        "description": description as Any,
                        "updatedAt": Date()
                    ])
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func markAsDone(itemId: String, note: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                var data: [String: Any] = [
                    "status": ItemStatus.done.rawValue,
                    "updatedAt": Date()
                ]
                if let note, !note.isEmpty {
                    data["completionNote"] = note
                }
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.collection)
                    .document(itemId)
                    .updateData(data)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteItem(itemId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.collection)
                    .document(itemId)
                    .delete()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Seeding & Migration

    private func seedDefaultLists() {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        let now = Date()
        let defaults: [(String, String, String?, Int)] = [
            ("Date Ideas", "💡", "Things to do together", 0),
            ("Watch Together", "🍿", "Movies, shows & more", 1)
        ]

        Task {
            do {
                let colRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.metaCollection)
                for (title, emoji, subtitle, order) in defaults {
                    let list = SharedList(title: title, emoji: emoji, subtitle: subtitle, createdBy: uid, createdAt: now, sortOrder: order)
                    try colRef.addDocument(from: list)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func migrateFromCategories() {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        let categoryMap: [String: (String, String)] = [
            "date-ideas": ("💡", "Date Ideas"),
            "watch-together": ("🍿", "Watch Together")
        ]

        // Collect unique categories from existing items
        let uniqueCategories = Set(items.map(\.listId))
        let now = Date()

        Task {
            do {
                let metaRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.metaCollection)
                let itemsRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Lists.collection)

                var categoryToDocId: [String: String] = [:]

                // Create SharedList docs for each category
                for (index, category) in uniqueCategories.sorted().enumerated() {
                    let (emoji, title) = categoryMap[category] ?? ("📋", category.replacingOccurrences(of: "-", with: " ").capitalized)
                    let list = SharedList(title: title, emoji: emoji, subtitle: nil, createdBy: uid, createdAt: now, sortOrder: index)
                    let docRef = try metaRef.addDocument(from: list)
                    categoryToDocId[category] = docRef.documentID
                }

                // Batch-update items to use new listId
                let batch = db.batch()
                for item in self.items {
                    guard let itemId = item.id,
                          let newListId = categoryToDocId[item.listId] else { continue }
                    let docRef = itemsRef.document(itemId)
                    batch.updateData(["listId": newListId], forDocument: docRef)
                }
                try await batch.commit()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
