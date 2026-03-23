import SwiftUI

struct ListItemDetailView: View {
    let item: ListItem
    var showMediaDetails: Bool = false
    @Environment(ListService.self) private var listService
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showMarkDoneAlert = false
    @State private var completionNote = ""

    private var addedByText: String {
        if item.addedBy == appState.authService.currentUserId {
            return "Added by you"
        } else {
            return "Added by \(appState.partnerName ?? "partner")"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showMediaDetails, let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.fondrSecondary.opacity(0.2))
                            .overlay {
                                Text("🍿").font(.system(size: 48))
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text(item.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let meta = item.metadata {
                    metadataChips(meta)
                }

                HStack {
                    Text(addedByText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(item.createdAt, style: .relative)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("ago")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                statusBadge

                if item.status == .matched {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("You both picked this!")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(.fondrAccent)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.fondrAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let note = item.completionNote, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completion Note")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(note)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 20)

                if item.status != .done {
                    FondrButton("Mark as Done") {
                        showMarkDoneAlert = true
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddItemSheet(editing: item)
        }
        .confirmationDialog("Delete this item?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                listService.deleteItem(itemId: item.id)
                dismiss()
            }
        }
        .alert("Mark as Done", isPresented: $showMarkDoneAlert) {
            TextField("Add a note (optional)", text: $completionNote)
            Button("Done") {
                listService.markAsDone(itemId: item.id, note: completionNote.isEmpty ? nil : completionNote)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add an optional note about how it went!")
        }
    }

    // MARK: - Components

    private func metadataChips(_ meta: MovieMetadata) -> some View {
        HStack(spacing: 8) {
            if let year = meta.year, !year.isEmpty {
                chip(year)
            }
            if let genre = meta.genre, !genre.isEmpty {
                chip(genre)
            }
            if let rating = meta.rating {
                chip(String(format: "%.1f ★", rating))
            }
            if let runtime = meta.runtime, !runtime.isEmpty {
                chip(runtime)
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.fondrSecondary.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: item.status.icon)
            Text(item.status.displayName)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.15))
        .foregroundStyle(statusColor)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch item.status {
        case .suggested: .fondrPrimary
        case .matched: .fondrAccent
        case .done: .secondary
        }
    }
}
