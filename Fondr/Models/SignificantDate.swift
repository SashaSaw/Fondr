import Foundation

struct SignificantDate: Identifiable, Codable, Sendable, Equatable {
    var id: String
    var title: String
    var date: Date
    var emoji: String?
    var recurring: Bool
    var addedBy: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, date, emoji, recurring
        case addedBy = "addedById"
        case createdAt
    }
}
