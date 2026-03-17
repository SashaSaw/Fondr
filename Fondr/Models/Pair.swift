import Foundation
import FirebaseFirestore

struct Pair: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userA: String
    var userB: String?
    var inviteCode: String
    var status: Status
    var createdAt: Date

    enum Status: String, Codable, Sendable {
        case pending
        case active
    }

    init(
        id: String? = nil,
        userA: String,
        userB: String? = nil,
        inviteCode: String,
        status: Status = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userA = userA
        self.userB = userB
        self.inviteCode = inviteCode
        self.status = status
        self.createdAt = createdAt
    }
}
