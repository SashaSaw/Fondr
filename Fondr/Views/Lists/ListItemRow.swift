import SwiftUI

struct ListItemRow: View {
    let item: ListItem
    var showMediaDetails: Bool = false
    @Environment(AppState.self) private var appState

    private var addedByText: String {
        if item.addedBy == appState.authService.currentUserId {
            return "Added by you"
        } else {
            return "Added by \(appState.partnerName ?? "partner")"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if showMediaDetails, let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.fondrSecondary.opacity(0.2))
                        .overlay {
                            Text("🍿")
                                .font(.title2)
                        }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)

                if showMediaDetails {
                    if let meta = item.metadata {
                        HStack(spacing: 4) {
                            if let year = meta.year, !year.isEmpty {
                                Text(year)
                            }
                            if let genre = meta.genre, !genre.isEmpty {
                                Text("·")
                                Text(genre)
                            }
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    }
                } else if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(addedByText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            statusBadge
        }
        .opacity(item.status == .done ? 0.6 : 1.0)
        .listRowBackground(
            item.status == .matched
                ? Color.fondrAccent.opacity(0.08)
                : Color.clear
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: item.status.icon)
                .font(.caption2)
            Text(item.status.displayName)
                .font(.system(.caption, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
