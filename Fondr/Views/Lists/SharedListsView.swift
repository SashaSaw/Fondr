import SwiftUI

struct SharedListsView: View {
    @Environment(ListService.self) private var listService
    @Environment(AppState.self) private var appState
    @State private var showCreateSheet = false

    private var partnerName: String {
        appState.partnerName ?? "your partner"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if listService.lists.isEmpty {
                    EmptyStateView(
                        emoji: "📋",
                        title: "No lists yet",
                        subtitle: "Your shared lists will appear here",
                        ctaTitle: "Create List",
                        ctaAction: { showCreateSheet = true }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(listService.lists) { list in
                            NavigationLink {
                                ListDetailView(list: list)
                            } label: {
                                ListCardView(
                                    list: list,
                                    itemCount: listService.itemCount(for: list.id),
                                    matchedCount: listService.matchedCount(for: list.id)
                                )
                            }
                            .buttonStyle(ListCardButtonStyle())
                        }

                        // "+" card
                        Button {
                            showCreateSheet = true
                        } label: {
                            FondrCard {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundStyle(.secondary)

                                    Text("New List")
                                        .font(.system(.headline, design: .rounded, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .foregroundStyle(Color.secondary.opacity(0.3))
                            )
                        }
                        .buttonStyle(ListCardButtonStyle())
                    }
                    .id(listService.lists.count)
                    .padding()
                }
            }
            .background(Color.fondrBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Things to do with \(partnerName)")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListSheet()
            }
        }
    }
}
