import Foundation

@Observable
final class ListService {
    var items: [ListItem] = []
    var lists: [SharedList] = []
    var errorMessage: String?
    var isLoading = false

    private var currentPairId: String?

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

        // Initial load
        Task {
            do {
                async let loadedLists: [SharedList] = APIClient.shared.get("/pairs/\(pairId)/lists")
                async let loadedItems: [ListItem] = APIClient.shared.get("/pairs/\(pairId)/items")
                let (l, i) = try await (loadedLists, loadedItems)
                await MainActor.run {
                    self.lists = l
                    self.items = i
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }

        // WebSocket events
        WebSocketManager.shared.on("list:created") { [weak self] (list: SharedList) in
            self?.lists.append(list)
        }
        WebSocketManager.shared.on("list:updated") { [weak self] (list: SharedList) in
            if let i = self?.lists.firstIndex(where: { $0.id == list.id }) {
                self?.lists[i] = list
            }
        }
        WebSocketManager.shared.on("list:deleted") { [weak self] (payload: DeletePayload) in
            self?.lists.removeAll { $0.id == payload.id }
            self?.items.removeAll { $0.listId == payload.id }
        }
        WebSocketManager.shared.on("item:created") { [weak self] (item: ListItem) in
            self?.items.insert(item, at: 0)
        }
        WebSocketManager.shared.on("item:updated") { [weak self] (item: ListItem) in
            if let i = self?.items.firstIndex(where: { $0.id == item.id }) {
                self?.items[i] = item
            }
        }
        WebSocketManager.shared.on("item:deleted") { [weak self] (payload: DeletePayload) in
            self?.items.removeAll { $0.id == payload.id }
        }
    }

    func stopListening() {
        WebSocketManager.shared.removeHandlers(for: [
            "list:created", "list:updated", "list:deleted",
            "item:created", "item:updated", "item:deleted"
        ])
        items = []
        lists = []
        currentPairId = nil
    }

    // MARK: - SharedList CRUD

    func createList(title: String, emoji: String, subtitle: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = CreateListBody(title: title, emoji: emoji, subtitle: subtitle)
                let _: SharedList = try await APIClient.shared.post("/pairs/\(pairId)/lists", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func updateList(listId: String, title: String, emoji: String, subtitle: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = UpdateListBody(title: title, emoji: emoji, subtitle: subtitle)
                let _: SharedList = try await APIClient.shared.patch("/pairs/\(pairId)/lists/\(listId)", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteList(listId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pairId)/lists/\(listId)")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - Item CRUD

    func addItem(listId: String, title: String, description: String?, imageUrl: String?, metadata: MovieMetadata?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = CreateItemBody(
                    listId: listId,
                    title: title,
                    description: description,
                    imageUrl: imageUrl,
                    metadataTmdbId: metadata?.tmdbId,
                    metadataYear: metadata?.year,
                    metadataGenre: metadata?.genre,
                    metadataRating: metadata?.rating,
                    metadataRuntime: metadata?.runtime
                )
                let _: ListItem = try await APIClient.shared.post("/pairs/\(pairId)/items", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func updateItem(itemId: String, title: String, description: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = UpdateItemBody(title: title, description: description)
                let _: ListItem = try await APIClient.shared.patch("/pairs/\(pairId)/items/\(itemId)", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func markAsDone(itemId: String, note: String?) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                let body = UpdateItemBody(status: ItemStatus.done.rawValue, completionNote: note)
                let _: ListItem = try await APIClient.shared.patch("/pairs/\(pairId)/items/\(itemId)", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteItem(itemId: String) {
        guard let pairId = currentPairId else { return }

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pairId)/items/\(itemId)")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Request DTOs

private struct CreateListBody: Encodable {
    let title: String
    let emoji: String
    let subtitle: String?
}

private struct UpdateListBody: Encodable {
    let title: String?
    let emoji: String?
    let subtitle: String?
}

private struct CreateItemBody: Encodable {
    let listId: String
    let title: String
    let description: String?
    let imageUrl: String?
    let metadataTmdbId: Int?
    let metadataYear: String?
    let metadataGenre: String?
    let metadataRating: Double?
    let metadataRuntime: String?
}

private struct UpdateItemBody: Encodable {
    var title: String?
    var description: String?
    var status: String?
    var completionNote: String?
}
