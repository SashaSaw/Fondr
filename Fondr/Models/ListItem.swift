import Foundation
import FirebaseFirestore

struct ListItem: Identifiable, Codable, Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String?
    var imageUrl: String?
    var listId: String
    var addedBy: String
    var status: ItemStatus
    var completionNote: String?
    var metadata: MovieMetadata?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, imageUrl, listId, addedBy, status, completionNote, metadata, createdAt, updatedAt
        case category // legacy key for migration
    }

    init(title: String, description: String? = nil, imageUrl: String? = nil, listId: String, addedBy: String, status: ItemStatus, completionNote: String? = nil, metadata: MovieMetadata? = nil, createdAt: Date, updatedAt: Date) {
        self.title = title
        self.description = description
        self.imageUrl = imageUrl
        self.listId = listId
        self.addedBy = addedBy
        self.status = status
        self.completionNote = completionNote
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        // Try listId first, fall back to category for old documents
        if let lid = try container.decodeIfPresent(String.self, forKey: .listId) {
            listId = lid
        } else {
            listId = try container.decode(String.self, forKey: .category)
        }
        addedBy = try container.decode(String.self, forKey: .addedBy)
        status = try container.decode(ItemStatus.self, forKey: .status)
        completionNote = try container.decodeIfPresent(String.self, forKey: .completionNote)
        metadata = try container.decodeIfPresent(MovieMetadata.self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(listId, forKey: .listId)
        try container.encode(addedBy, forKey: .addedBy)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(completionNote, forKey: .completionNote)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum ItemStatus: String, Codable, CaseIterable, Sendable {
    case suggested, matched, done

    var displayName: String {
        switch self {
        case .suggested: "Suggested"
        case .matched: "Matched"
        case .done: "Done"
        }
    }

    var icon: String {
        switch self {
        case .suggested: "lightbulb"
        case .matched: "sparkles"
        case .done: "checkmark.circle.fill"
        }
    }
}

struct MovieMetadata: Codable, Sendable {
    var tmdbId: Int?
    var year: String?
    var genre: String?
    var rating: Double?
    var runtime: String?
}
