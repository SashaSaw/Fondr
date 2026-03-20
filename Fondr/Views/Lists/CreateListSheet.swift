import SwiftUI

struct CreateListSheet: View {
    @Environment(ListService.self) private var listService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var subtitle: String
    @State private var selectedEmoji: String
    @State private var showDeleteConfirmation = false

    private let editingList: SharedList?
    private let isEditing: Bool
    var onDelete: (() -> Void)?

    private let emojiOptions = ["💡", "🍿", "🎯", "🎮", "🍽️", "✈️", "🎵", "📚", "🏋️", "🛍️", "🎨", "🎲", "🏖️", "💝", "🧘", "🎬", "🌮", "☕", "🎤", "🏠", "🐾", "🎁", "🔥", "💭"]

    // MARK: - Init

    init() {
        self.editingList = nil
        self.isEditing = false
        _title = State(initialValue: "")
        _subtitle = State(initialValue: "")
        _selectedEmoji = State(initialValue: "📋")
    }

    init(editing list: SharedList, onDelete: (() -> Void)? = nil) {
        self.editingList = list
        self.isEditing = true
        self.onDelete = onDelete
        _title = State(initialValue: list.title)
        _subtitle = State(initialValue: list.subtitle ?? "")
        _selectedEmoji = State(initialValue: list.emoji)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Emoji") {
                    emojiGrid
                }

                Section("Title") {
                    TextField("e.g. Restaurants", text: $title)
                }

                Section("Subtitle (optional)") {
                    TextField("e.g. Places to try together", text: $subtitle)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete List", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .alert("Delete List", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let listId = editingList?.id {
                        listService.deleteList(listId: listId)
                    }
                    dismiss()
                    onDelete?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this list and all its items.")
            }
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Emoji Grid

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(emojiOptions, id: \.self) { emoji in
                emojiButton(emoji)
            }
        }
        .padding(.vertical, 4)
    }

    private func emojiButton(_ emoji: String) -> some View {
        let isSelected = selectedEmoji == emoji
        return Button {
            selectedEmoji = emoji
        } label: {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.fondrPrimary.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.fondrPrimary : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.borderless)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespaces)

        if isEditing, let listId = editingList?.id {
            listService.updateList(
                listId: listId,
                title: trimmedTitle,
                emoji: selectedEmoji,
                subtitle: trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
            )
        } else {
            listService.createList(
                title: trimmedTitle,
                emoji: selectedEmoji,
                subtitle: trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
            )
        }
        dismiss()
    }
}
