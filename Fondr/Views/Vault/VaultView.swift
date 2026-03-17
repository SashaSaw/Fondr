import SwiftUI

struct VaultView: View {
    @Environment(VaultService.self) private var vaultService
    @State private var searchText = ""
    @State private var showAddSheet = false

    private var isSearching: Bool { !searchText.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if vaultService.facts.isEmpty && !isSearching {
                    EmptyStateView(
                        emoji: "🔐",
                        title: "Your Vault",
                        subtitle: "Save facts, preferences, and gift ideas about each other",
                        ctaTitle: "Add First Fact",
                        ctaAction: { showAddSheet = true }
                    )
                } else {
                    List {
                        if isSearching {
                            searchResultsSection
                        } else {
                            categorySections
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Vault")
            .searchable(text: $searchText, prompt: "Search facts")
            .toolbar {
                if !vaultService.facts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddFactSheet()
            }
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        let results = vaultService.searchFacts(query: searchText)
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ForEach(results) { fact in
                FactRow(fact: fact)
            }
        }
    }

    // MARK: - Category Sections

    @ViewBuilder
    private var categorySections: some View {
        let grouped = vaultService.factsByCategory
        ForEach(FactCategory.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { category in
            let facts = grouped[category] ?? []
            Section {
                ForEach(facts.prefix(3)) { fact in
                    FactRow(fact: fact)
                }
                if facts.count > 3 {
                    NavigationLink {
                        VaultCategoryView(category: category)
                    } label: {
                        Text("See all \(facts.count)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.fondrPrimary)
                    }
                }
            } header: {
                NavigationLink {
                    VaultCategoryView(category: category)
                } label: {
                    HStack(spacing: 6) {
                        Text(category.icon)
                        Text(category.displayName)
                        if !facts.isEmpty {
                            Text("(\(facts.count))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fact Row

struct FactRow: View {
    let fact: VaultFact
    @Environment(VaultService.self) private var vaultService
    @Environment(AppState.self) private var appState
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private var addedByText: String {
        if fact.addedBy == appState.authService.currentUser?.uid {
            return "Added by you"
        } else {
            return "Added by \(appState.partnerName ?? "partner")"
        }
    }

    var body: some View {
        Button {
            showEditSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(fact.label)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Text(fact.value)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(addedByText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this fact?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = fact.id {
                    vaultService.deleteFact(factId: id)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddFactSheet(editing: fact)
        }
    }
}
