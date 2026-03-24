import SwiftUI

struct AddAvailabilitySheet: View {
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var addTime: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isSaving = false

    private let editingEventId: String?

    // MARK: - Init

    init() {
        _title = State(initialValue: "")
        _description = State(initialValue: "")
        _startDate = State(initialValue: Date())
        _endDate = State(initialValue: Date())
        _addTime = State(initialValue: false)
        _startTime = State(initialValue: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date())
        _endTime = State(initialValue: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date())
        editingEventId = nil
    }

    init(prefilledDate: Date) {
        _title = State(initialValue: "")
        _description = State(initialValue: "")
        _startDate = State(initialValue: prefilledDate)
        _endDate = State(initialValue: prefilledDate)
        _addTime = State(initialValue: false)
        _startTime = State(initialValue: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: prefilledDate) ?? prefilledDate)
        _endTime = State(initialValue: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: prefilledDate) ?? prefilledDate)
        editingEventId = nil
    }

    init(editing event: CalendarEvent) {
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description ?? "")
        editingEventId = event.id

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let start = formatter.date(from: event.startDate) ?? Date()
        let end = formatter.date(from: event.endDate) ?? Date()
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)

        let hasTime = event.startTime != nil
        _addTime = State(initialValue: hasTime)

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let defaultStart = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: start) ?? start
        let defaultEnd = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: start) ?? start

        if let st = event.startTime, let parsed = timeFmt.date(from: st) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
            _startTime = State(initialValue: Calendar.current.date(bySettingHour: comps.hour ?? 18, minute: comps.minute ?? 0, second: 0, of: start) ?? defaultStart)
        } else {
            _startTime = State(initialValue: defaultStart)
        }

        if let et = event.endTime, let parsed = timeFmt.date(from: et) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
            _endTime = State(initialValue: Calendar.current.date(bySettingHour: comps.hour ?? 21, minute: comps.minute ?? 0, second: 0, of: start) ?? defaultEnd)
        } else {
            _endTime = State(initialValue: defaultEnd)
        }
    }

    private var eventDateStrings: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var dates: [String] = []
        var current = startDate
        let calendar = Foundation.Calendar.current
        while current <= endDate {
            dates.append(formatter.string(from: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private var partnerBusyDates: [String] {
        let partnerSlots = calendarService.partnerSlots
        return eventDateStrings.filter { dateStr in
            partnerSlots.contains { $0.date == dateStr }
        }
    }

    private var hasPartnerBusyConflict: Bool {
        !partnerBusyDates.isEmpty
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !hasPartnerBusyConflict
    }

    private var previewText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"

        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        if Foundation.Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return startStr
        }

        let days = (Foundation.Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        return "\(startStr) – \(endStr) (\(days) days)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What's the plan?", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                .onChange(of: startDate) { _, newStart in
                    if endDate < newStart {
                        endDate = newStart
                    }
                }

                Section {
                    Toggle("Add time?", isOn: $addTime)
                    if addTime {
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }

                if hasPartnerBusyConflict {
                    Section {
                        Label("Your partner is busy on: \(partnerBusyDates.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text(previewText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(editingEventId != nil ? "Edit Date" : "Propose a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        let desc: String? = trimmedDesc.isEmpty ? nil : trimmedDesc

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let sTime: String? = addTime ? timeFmt.string(from: startTime) : nil
        let eTime: String? = addTime ? timeFmt.string(from: endTime) : nil

        if let eventId = editingEventId {
            calendarService.updateEvent(eventId: eventId, title: trimmedTitle, description: desc, startDate: startStr, endDate: endStr, startTime: sTime, endTime: eTime)
        } else {
            // Remove user's own busy slots for dates in the event range
            calendarService.removeMySlots(for: eventDateStrings)
            calendarService.addEvent(title: trimmedTitle, description: desc, startDate: startStr, endDate: endStr, startTime: sTime, endTime: eTime)
        }

        dismiss()
    }
}
