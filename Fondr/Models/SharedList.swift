import Foundation

struct SharedList: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var emoji: String
    var subtitle: String?
    var createdBy: String
    var createdAt: Date
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, subtitle
        case createdBy = "createdById"
        case createdAt, sortOrder
    }
}
