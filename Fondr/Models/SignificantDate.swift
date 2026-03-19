import Foundation
import FirebaseFirestore

struct SignificantDate: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    var title: String
    var date: Date
    var emoji: String?
    var recurring: Bool
    var addedBy: String
    var createdAt: Date
}
