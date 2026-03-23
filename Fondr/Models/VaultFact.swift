import Foundation

struct VaultFact: Identifiable, Codable, Sendable {
    var id: String
    var category: FactCategory
    var label: String
    var value: String
    var addedBy: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, category, label, value
        case addedBy = "addedById"
        case createdAt, updatedAt
    }
}

enum FactCategory: String, Codable, CaseIterable, Sendable {
    case basics, food, gifts, notes

    var displayName: String {
        switch self {
        case .basics: "Basics"
        case .food: "Food & Drink"
        case .gifts: "Gifts"
        case .notes: "Notes"
        }
    }

    var icon: String {
        switch self {
        case .basics: "💝"
        case .food: "🍕"
        case .gifts: "🎁"
        case .notes: "📝"
        }
    }

    var sortOrder: Int {
        switch self {
        case .basics: 0
        case .food: 1
        case .gifts: 2
        case .notes: 3
        }
    }
}
