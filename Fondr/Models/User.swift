import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var partnerName: String?
    var timezone: String?
    var pairId: String?
    var partnerUid: String?
    var onboardingCompleted: Bool?
    var profileImageUrl: String?
    var createdAt: Date?

    init(
        id: String? = nil,
        displayName: String,
        email: String? = nil,
        partnerName: String? = nil,
        timezone: String? = nil,
        pairId: String? = nil,
        partnerUid: String? = nil,
        onboardingCompleted: Bool = false,
        profileImageUrl: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.partnerName = partnerName
        self.timezone = timezone
        self.pairId = pairId
        self.partnerUid = partnerUid
        self.onboardingCompleted = onboardingCompleted
        self.profileImageUrl = profileImageUrl
        self.createdAt = createdAt
    }
}
