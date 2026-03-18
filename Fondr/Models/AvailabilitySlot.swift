import Foundation
import FirebaseFirestore

struct AvailabilitySlot: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var date: String              // "2026-03-20"
    var startTime: String?        // "14:00" UTC (nil = all day)
    var endTime: String?          // "18:00" UTC (nil = all day)
    var label: String?
    var createdAt: Date
}

struct CalendarEvent: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String?      // event description
    var startDate: String         // "2026-03-22"
    var endDate: String           // "2026-03-25"
    var startTime: String?        // "14:00" (optional)
    var endTime: String?          // "18:00" (optional)
    var createdBy: String
    var createdAt: Date
    var status: EventStatus       // pending / accepted / declined
    var declineReason: String?    // reason if declined
    var respondedAt: Date?        // when partner responded
}

enum EventStatus: String, Codable, Sendable {
    case pending, accepted, declined
}

struct OverlapBlock: Identifiable {
    let id = UUID()
    let date: Date
    let startTime: String          // UTC "HH:mm"
    let endTime: String
    let yourSlot: AvailabilitySlot
    let partnerSlot: AvailabilitySlot
}
