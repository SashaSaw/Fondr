import SwiftUI

struct SetAnniversarySheet: View {
    @Environment(OurStoryService.self) private var ourStoryService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date

    init(existingDate: Date? = nil) {
        _selectedDate = State(initialValue: existingDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Anniversary Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
            .navigationTitle("Set Anniversary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ourStoryService.setAnniversary(date: selectedDate)
                        dismiss()
                    }
                }
            }
        }
    }
}
