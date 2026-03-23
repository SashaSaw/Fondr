import Foundation

struct SwipeSession: Identifiable, Codable, Sendable, Equatable {
    var id: String
    var listId: String
    var itemIds: [String]
    var swipesA: [String: String]
    var swipesB: [String: String]
    var matches: [String]
    var status: SessionStatus
    var startedBy: String
    var createdAt: Date
    var completedAt: Date?
    var chosenItemId: String?

    enum CodingKeys: String, CodingKey {
        case id, listId, itemIds, swipesA, swipesB, matches, status
        case startedBy = "startedById"
        case createdAt, completedAt, chosenItemId
    }
}

enum SessionStatus: String, Codable, Sendable {
    case active
    case complete
}
