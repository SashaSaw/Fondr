import Foundation

struct Pair: Codable, Identifiable, Sendable {
    var id: String
    var userA: String
    var userB: String?
    var inviteCode: String
    var status: Status
    var anniversary: Date?
    var createdAt: Date

    enum Status: String, Codable, Sendable {
        case pending
        case active
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userA = "userAId"
        case userB = "userBId"
        case inviteCode, status, anniversary, createdAt
    }

    init(
        id: String = "",
        userA: String,
        userB: String? = nil,
        inviteCode: String = "",
        status: Status = .pending,
        anniversary: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userA = userA
        self.userB = userB
        self.inviteCode = inviteCode
        self.status = status
        self.anniversary = anniversary
        self.createdAt = createdAt
    }
}
