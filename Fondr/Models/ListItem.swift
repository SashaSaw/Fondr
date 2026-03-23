import Foundation

struct ListItem: Identifiable, Codable, Sendable {
    var id: String
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
        case id, title, description, imageUrl, listId
        case addedBy = "addedById"
        case status, completionNote, createdAt, updatedAt
        case metadataTmdbId, metadataYear, metadataGenre, metadataRating, metadataRuntime
    }

    init(
        id: String = "",
        title: String,
        description: String? = nil,
        imageUrl: String? = nil,
        listId: String,
        addedBy: String,
        status: ItemStatus,
        completionNote: String? = nil,
        metadata: MovieMetadata? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
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
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        listId = try container.decode(String.self, forKey: .listId)
        addedBy = try container.decode(String.self, forKey: .addedBy)
        status = try container.decode(ItemStatus.self, forKey: .status)
        completionNote = try container.decodeIfPresent(String.self, forKey: .completionNote)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        let tmdbId = try container.decodeIfPresent(Int.self, forKey: .metadataTmdbId)
        let year = try container.decodeIfPresent(String.self, forKey: .metadataYear)
        let genre = try container.decodeIfPresent(String.self, forKey: .metadataGenre)
        let rating = try container.decodeIfPresent(Double.self, forKey: .metadataRating)
        let runtime = try container.decodeIfPresent(String.self, forKey: .metadataRuntime)

        if tmdbId != nil || year != nil || genre != nil || rating != nil || runtime != nil {
            metadata = MovieMetadata(tmdbId: tmdbId, year: year, genre: genre, rating: rating, runtime: runtime)
        } else {
            metadata = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(listId, forKey: .listId)
        try container.encode(addedBy, forKey: .addedBy)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(completionNote, forKey: .completionNote)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(metadata?.tmdbId, forKey: .metadataTmdbId)
        try container.encodeIfPresent(metadata?.year, forKey: .metadataYear)
        try container.encodeIfPresent(metadata?.genre, forKey: .metadataGenre)
        try container.encodeIfPresent(metadata?.rating, forKey: .metadataRating)
        try container.encodeIfPresent(metadata?.runtime, forKey: .metadataRuntime)
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
