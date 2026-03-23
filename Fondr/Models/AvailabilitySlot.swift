import Foundation

struct AvailabilitySlot: Identifiable, Codable, Sendable {
    var id: String
    var userId: String
    var date: String              // "2026-03-20"
    var startTime: String?        // "14:00" UTC (nil = all day)
    var endTime: String?          // "18:00" UTC (nil = all day)
    var label: String?
    var createdAt: Date

    init(
        id: String = "",
        userId: String,
        date: String,
        startTime: String? = nil,
        endTime: String? = nil,
        label: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, date, startTime, endTime, label, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Date comes as ISO8601 from API — convert to "yyyy-MM-dd" string
        if let dateValue = try? container.decode(Date.self, forKey: .date) {
            date = DateFormatter.yyyyMMdd.string(from: dateValue)
        } else {
            date = try container.decode(String.self, forKey: .date)
        }
    }
}

struct CalendarEvent: Identifiable, Codable, Sendable, Equatable {
    var id: String
    var title: String
    var description: String?
    var startDate: String         // "2026-03-22"
    var endDate: String           // "2026-03-25"
    var startTime: String?
    var endTime: String?
    var createdBy: String
    var createdAt: Date
    var status: EventStatus
    var declineReason: String?
    var respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, startDate, endDate, startTime, endTime
        case createdBy = "createdById"
        case createdAt, status, declineReason, respondedAt
    }

    init(
        id: String = "",
        title: String,
        description: String? = nil,
        startDate: String,
        endDate: String,
        startTime: String? = nil,
        endTime: String? = nil,
        createdBy: String,
        createdAt: Date = Date(),
        status: EventStatus = .pending,
        declineReason: String? = nil,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.status = status
        self.declineReason = declineReason
        self.respondedAt = respondedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(EventStatus.self, forKey: .status)
        declineReason = try container.decodeIfPresent(String.self, forKey: .declineReason)
        respondedAt = try container.decodeIfPresent(Date.self, forKey: .respondedAt)

        let formatter = DateFormatter.yyyyMMdd
        if let dateValue = try? container.decode(Date.self, forKey: .startDate) {
            startDate = formatter.string(from: dateValue)
        } else {
            startDate = try container.decode(String.self, forKey: .startDate)
        }
        if let dateValue = try? container.decode(Date.self, forKey: .endDate) {
            endDate = formatter.string(from: dateValue)
        } else {
            endDate = try container.decode(String.self, forKey: .endDate)
        }
    }
}

enum EventStatus: String, Codable, Sendable {
    case pending, accepted, declined
}

struct OverlapBlock: Identifiable {
    let id = UUID()
    let date: Date
    let startTime: String
    let endTime: String
    let yourSlot: AvailabilitySlot
    let partnerSlot: AvailabilitySlot
}
