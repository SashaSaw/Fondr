import SwiftUI

struct AddSignificantDateSheet: View {
    @Environment(OurStoryService.self) private var ourStoryService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var emoji: String
    @State private var recurring: Bool

    private let editingDate: SignificantDate?
    private let isEditing: Bool

    private let commonEmojis = ["🎂", "🎉", "✈️", "🏠", "💍", "🐶", "🎓", "⭐️", "🌸", "🎁"]

    init() {
        _title = State(initialValue: "")
        _date = State(initialValue: Date())
        _emoji = State(initialValue: "")
        _recurring = State(initialValue: true)
        editingDate = nil
        isEditing = false
    }

    init(editing sigDate: SignificantDate) {
        _title = State(initialValue: sigDate.title)
        _date = State(initialValue: sigDate.date)
        _emoji = State(initialValue: sigDate.emoji ?? "")
        _recurring = State(initialValue: sigDate.recurring)
        editingDate = sigDate
        isEditing = true
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. First Date", text: $title)
                }

                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonEmojis, id: \.self) { e in
                                Button {
                                    emoji = e
                                } label: {
                                    Text(e)
                                        .font(.title2)
                                        .padding(8)
                                        .background(emoji == e ? Color.fondrSecondary.opacity(0.3) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    TextField("Or type your own", text: $emoji)
                        .font(.title3)
                }

                Section {
                    Toggle("Repeats yearly", isOn: $recurring)
                }
            }
            .navigationTitle(isEditing ? "Edit Date" : "Add Date")
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        let emojiValue = trimmedEmoji.isEmpty ? nil : trimmedEmoji

        if isEditing, let dateId = editingDate?.id {
            ourStoryService.updateSignificantDate(
                dateId: dateId,
                title: trimmedTitle,
                date: date,
                emoji: emojiValue,
                recurring: recurring
            )
        } else {
            ourStoryService.addSignificantDate(
                title: trimmedTitle,
                date: date,
                emoji: emojiValue,
                recurring: recurring
            )
        }
        dismiss()
    }
}
