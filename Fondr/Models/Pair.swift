import Foundation

struct PairUser: Codable, Sendable {
    let id: String
    let displayName: String
    let profileImageUrl: String?
    let timezone: String?
}

struct Pair: Codable, Identifiable, Sendable {
    var id: String
    var userA: String
    var userB: String?
    var inviteCode: String
    var status: Status
    var anniversary: Date?
    var createdAt: Date
    var userAProfile: PairUser?
    var userBProfile: PairUser?

    enum Status: String, Codable, Sendable {
        case pending
        case active
    }

    private enum CodingKeys: String, CodingKey {
        case id, inviteCode, status, anniversary, createdAt
        case userAId, userBId
        case userA, userB
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
        status = try container.decode(Status.self, forKey: .status)
        anniversary = try container.decodeIfPresent(Date.self, forKey: .anniversary)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // ID fields
        userA = try container.decode(String.self, forKey: .userAId)
        userB = try container.decodeIfPresent(String.self, forKey: .userBId)

        // Nested user profile objects (optional — not present in all responses)
        userAProfile = try container.decodeIfPresent(PairUser.self, forKey: .userA)
        userBProfile = try container.decodeIfPresent(PairUser.self, forKey: .userB)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userA, forKey: .userAId)
        try container.encodeIfPresent(userB, forKey: .userBId)
        try container.encode(inviteCode, forKey: .inviteCode)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(anniversary, forKey: .anniversary)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(userAProfile, forKey: .userA)
        try container.encodeIfPresent(userBProfile, forKey: .userB)
    }

    init(
        id: String = "",
        userA: String,
        userB: String? = nil,
        inviteCode: String = "",
        status: Status = .pending,
        anniversary: Date? = nil,
        createdAt: Date = Date(),
        userAProfile: PairUser? = nil,
        userBProfile: PairUser? = nil
    ) {
        self.id = id
        self.userA = userA
        self.userB = userB
        self.inviteCode = inviteCode
        self.status = status
        self.anniversary = anniversary
        self.createdAt = createdAt
        self.userAProfile = userAProfile
        self.userBProfile = userBProfile
    }
}
