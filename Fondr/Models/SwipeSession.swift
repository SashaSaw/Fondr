import Foundation
import FirebaseFirestore

struct SwipeSession: Identifiable, Codable, Sendable, Equatable {
    @DocumentID var id: String?
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
}

enum SessionStatus: String, Codable, Sendable {
    case active
    case complete
}
