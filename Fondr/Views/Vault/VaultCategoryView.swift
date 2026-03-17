import SwiftUI

struct VaultCategoryView: View {
    let category: FactCategory
    @Environment(VaultService.self) private var vaultService
    @State private var showAddSheet = false
    @State private var sortAlphabetically = false

    private var facts: [VaultFact] {
        let categoryFacts = vaultService.factsByCategory[category] ?? []
        if sortAlphabetically {
            return categoryFacts.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        }
        return categoryFacts
    }

    var body: some View {
        Group {
            if facts.isEmpty {
                EmptyStateView(
                    emoji: category.icon,
                    title: "No \(category.displayName) Yet",
                    subtitle: "Add your first fact in this category",
                    ctaTitle: "Add Fact",
                    ctaAction: { showAddSheet = true }
                )
            } else {
                List {
                    ForEach(facts) { fact in
                        FactRow(fact: fact)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(category.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation { sortAlphabetically.toggle() }
                    } label: {
                        Image(systemName: sortAlphabetically ? "textformat.abc" : "clock")
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
            AddFactSheet(preselectedCategory: category)
        }
    }
}
