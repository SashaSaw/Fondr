import Foundation
import FirebaseFirestore

struct SharedList: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    var title: String
    var emoji: String
    var subtitle: String?
    var createdBy: String
    var createdAt: Date
    var sortOrder: Int
}
