import SwiftUI

struct AddFactSheet: View {
    @Environment(VaultService.self) private var vaultService
    @Environment(\.dismiss) private var dismiss

    @State private var category: FactCategory
    @State private var label: String
    @State private var value: String

    private let editingFact: VaultFact?
    private let isEditing: Bool

    // MARK: - Init

    init() {
        _category = State(initialValue: .basics)
        _label = State(initialValue: "")
        _value = State(initialValue: "")
        editingFact = nil
        isEditing = false
    }

    init(preselectedCategory: FactCategory) {
        _category = State(initialValue: preselectedCategory)
        _label = State(initialValue: "")
        _value = State(initialValue: "")
        editingFact = nil
        isEditing = false
    }

    init(editing fact: VaultFact) {
        _category = State(initialValue: fact.category)
        _label = State(initialValue: fact.label)
        _value = State(initialValue: fact.value)
        editingFact = fact
        isEditing = true
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty &&
        !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var suggestions: [String] {
        guard label.count < 3 else { return [] }
        return Constants.Vault.labelSuggestions[category] ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(FactCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.displayName)").tag(cat)
                        }
                    }
                    .disabled(isEditing)
                }

                Section("Label") {
                    TextField("e.g. Favourite Restaurant", text: $label)

                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button {
                                        label = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.fondrSecondary.opacity(0.2))
                                            .foregroundStyle(.fondrSecondary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Value") {
                    TextField("Enter value", text: $value)
                }
            }
            .navigationTitle(isEditing ? "Edit Fact" : "Add Fact")
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
        }
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)

        if isEditing, let factId = editingFact?.id {
            vaultService.updateFact(factId: factId, label: trimmedLabel, value: trimmedValue)
        } else {
            vaultService.addFact(category: category, label: trimmedLabel, value: trimmedValue)
        }
        dismiss()
    }
}
