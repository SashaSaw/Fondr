import SwiftUI

struct ListDetailView: View {
    let list: SharedList
    @Environment(ListService.self) private var listService
    @State private var selectedStatus: ItemStatus? = nil
    @State private var showAddSheet = false
    @State private var showEditSheet = false

    private var filteredItems: [ListItem] {
        listService.items(for: list.id ?? "", status: selectedStatus)
    }

    private var totalCount: Int {
        listService.itemCount(for: list.id ?? "")
    }

    private var matchedCount: Int {
        listService.matchedCount(for: list.id ?? "")
    }

    private var showMediaDetails: Bool {
        listService.isWatchList(list.id ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterChips

            if filteredItems.isEmpty {
                Spacer()
                EmptyStateView(
                    emoji: list.emoji,
                    title: "Nothing here yet",
                    subtitle: "Add the first item to \(list.title)",
                    ctaTitle: "Add Item",
                    ctaAction: { showAddSheet = true }
                )
                Spacer()
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            ListItemDetailView(item: item, showMediaDetails: showMediaDetails)
                        } label: {
                            ListItemRow(item: item, showMediaDetails: showMediaDetails)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let id = item.id {
                                    listService.deleteItem(itemId: id)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddItemSheet(listId: list.id ?? "")
        }
        .sheet(isPresented: $showEditSheet) {
            CreateListSheet(editing: list)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(list.emoji)
                .font(.system(size: 48))

            Text(list.title)
                .font(.system(.title, design: .rounded, weight: .bold))

            if let subtitle = list.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("\(totalCount) item\(totalCount == 1 ? "" : "s")")
                if matchedCount > 0 {
                    Text("·")
                    Text("\(matchedCount) matched ✨")
                        .foregroundStyle(.fondrAccent)
                }
            }
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", status: nil)
                ForEach(ItemStatus.allCases, id: \.self) { status in
                    filterChip(title: status.displayName, status: status)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(title: String, status: ItemStatus?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedStatus = status
            }
        } label: {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedStatus == status ? Color.fondrPrimary.opacity(0.8) : Color.fondrSecondary.opacity(0.1))
                .foregroundStyle(selectedStatus == status ? .white : .secondary)
                .clipShape(Capsule())
        }
    }
}
