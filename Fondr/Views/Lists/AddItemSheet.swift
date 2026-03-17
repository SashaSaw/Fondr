import SwiftUI

struct AddItemSheet: View {
    @Environment(ListService.self) private var listService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var imageUrl: String?
    @State private var metadata: MovieMetadata?
    @State private var tmdbService = TMDBService()
    @State private var showManualEntry = false

    private let listId: String
    private let editingItem: ListItem?
    private let isEditing: Bool

    // MARK: - Init

    init(listId: String) {
        self.listId = listId
        self.editingItem = nil
        self.isEditing = false
        _title = State(initialValue: "")
        _description = State(initialValue: "")
        _imageUrl = State(initialValue: nil)
        _metadata = State(initialValue: nil)
    }

    init(editing item: ListItem) {
        self.listId = item.listId
        self.editingItem = item
        self.isEditing = true
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.description ?? "")
        _imageUrl = State(initialValue: item.imageUrl)
        _metadata = State(initialValue: item.metadata)
        _showManualEntry = State(initialValue: true)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isWatchList: Bool {
        listService.isWatchList(listId) && tmdbService.isConfigured && !isEditing && !showManualEntry
    }

    private var listDisplay: (emoji: String, title: String) {
        if let list = listService.lists.first(where: { $0.id == listId }) {
            return (list.emoji, list.title)
        }
        return ("📋", "List")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    HStack {
                        Text(listDisplay.emoji)
                        Text(listDisplay.title)
                    }
                    .foregroundStyle(.secondary)
                }

                Section("Title") {
                    TextField(
                        listService.isWatchList(listId) ? "Movie or show name" : "e.g. Picnic in the park",
                        text: $title
                    )
                }

                if isWatchList && !title.isEmpty {
                    tmdbSearchSection
                }

                Section("Description (optional)") {
                    TextField("Add some details", text: $description)
                }

                if let meta = metadata {
                    Section("Movie Info") {
                        if let year = meta.year, !year.isEmpty {
                            HStack {
                                Text("Year")
                                Spacer()
                                Text(year).foregroundStyle(.secondary)
                            }
                        }
                        if let genre = meta.genre, !genre.isEmpty {
                            HStack {
                                Text("Genre")
                                Spacer()
                                Text(genre).foregroundStyle(.secondary)
                            }
                        }
                        if let rating = meta.rating {
                            HStack {
                                Text("Rating")
                                Spacer()
                                Text(String(format: "%.1f/10", rating)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .task(id: title) {
                guard isWatchList else { return }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await tmdbService.search(query: title)
            }
        }
    }

    // MARK: - TMDB Search

    @ViewBuilder
    private var tmdbSearchSection: some View {
        Section {
            if tmdbService.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if !tmdbService.searchResults.isEmpty {
                ForEach(tmdbService.searchResults) { result in
                    Button {
                        selectTMDBResult(result)
                    } label: {
                        HStack(spacing: 10) {
                            if let posterPath = result.posterPath, let url = TMDBService.posterUrl(path: posterPath) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.fondrSecondary.opacity(0.2)
                                }
                                .frame(width: 40, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(.primary)
                                if !result.year.isEmpty {
                                    Text(result.year)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Button("Can't find it? Add manually") {
                    showManualEntry = true
                    tmdbService.clearResults()
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.fondrPrimary)
            }
        } header: {
            Text("Search Results")
        }
    }

    // MARK: - Actions

    private func selectTMDBResult(_ result: TMDBResult) {
        title = result.title
        description = result.overview ?? ""
        if let posterPath = result.posterPath {
            imageUrl = "\(Constants.TMDB.imageBaseUrl)\(posterPath)"
        }
        metadata = MovieMetadata(
            tmdbId: result.id,
            year: result.year,
            rating: result.rating
        )
        showManualEntry = true
        tmdbService.clearResults()
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)

        if isEditing, let itemId = editingItem?.id {
            listService.updateItem(
                itemId: itemId,
                title: trimmedTitle,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc
            )
        } else {
            listService.addItem(
                listId: listId,
                title: trimmedTitle,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                imageUrl: imageUrl,
                metadata: metadata
            )
        }
        dismiss()
    }
}
