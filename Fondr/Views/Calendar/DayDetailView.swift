import SwiftUI
import FirebaseAuth

struct DayDetailView: View {
    let date: Date

    @Environment(CalendarService.self) private var calendarService
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isBusy: Bool = false
    @State private var useTimeRange: Bool = false
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var label: String = ""
    @State private var showAddEvent = false
    @State private var editingEvent: CalendarEvent?
    @State private var declineReasonFor: String?
    @State private var declineReasonText: String = ""

    private var titleString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date)
    }

    private var userTz: String {
        appState.userTimezone ?? TimeZone.current.identifier
    }

    private var partnerTz: String {
        calendarService.partnerTimezone ?? "UTC"
    }

    private var mySlot: AvailabilitySlot? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return calendarService.slotForDate(userId: uid, date: date)
    }

    private var partnerSlot: AvailabilitySlot? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let dateStr = dateString(from: date)
        return calendarService.slots.first { $0.userId != uid && $0.date == dateStr }
    }

    private var dayEvents: [CalendarEvent] {
        calendarService.eventsForDate(date)
    }

    private var overlaps: [OverlapBlock] {
        calendarService.overlapsForDate(date)
    }

    var body: some View {
        NavigationStack {
            Form {
                yourAvailabilitySection
                partnerAvailabilitySection

                if !overlaps.isEmpty {
                    overlapSection
                }

                eventsSection
            }
            .navigationTitle(titleString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadCurrentState() }
            .sheet(isPresented: $showAddEvent) {
                AddAvailabilitySheet(prefilledDate: date)
            }
            .sheet(item: $editingEvent) { event in
                AddAvailabilitySheet(editing: event)
            }
        }
    }

    // MARK: - Your Availability

    private var yourAvailabilitySection: some View {
        Section("Your Availability") {
            Toggle("Busy this day", isOn: $isBusy)
                .onChange(of: isBusy) { _, newValue in
                    if newValue != (mySlot != nil) {
                        calendarService.toggleAvailability(for: date)
                    }
                }

            if isBusy {
                Toggle("Set time range", isOn: $useTimeRange)

                if useTimeRange {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    TextField("Label (optional)", text: $label)

                    Button("Save Time Range") {
                        let utcStart = calendarService.localToUtc(startTime, on: date, timezone: userTz)
                        let utcEnd = calendarService.localToUtc(endTime, on: date, timezone: userTz)
                        calendarService.setTimeRange(
                            for: date,
                            start: utcStart,
                            end: utcEnd,
                            label: label.isEmpty ? nil : label
                        )
                    }
                    .disabled(endTime <= startTime)
                }
            }
        }
    }

    // MARK: - Partner Availability

    private var partnerAvailabilitySection: some View {
        Section("Partner's Availability") {
            if let slot = partnerSlot {
                if let start = slot.startTime, let end = slot.endTime {
                    let range = calendarService.formatTimeRange(
                        start: start,
                        end: end,
                        timezone: partnerTz,
                        on: date
                    )
                    Label("Busy \(range)", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.fondrPrimary)

                    if partnerTz != userTz {
                        let localRange = calendarService.formatTimeRange(
                            start: start,
                            end: end,
                            timezone: userTz,
                            on: date
                        )
                        Text("Your time: \(localRange)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("Busy (all day)", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.fondrPrimary)
                }

                if let label = slot.label, !label.isEmpty {
                    Text(label)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Not set")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Overlap

    private var overlapSection: some View {
        Section {
            ForEach(overlaps) { overlap in
                let range = calendarService.formatTimeRange(
                    start: overlap.startTime,
                    end: overlap.endTime,
                    timezone: userTz,
                    on: date
                )
                Label("Overlap: \(range)", systemImage: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
        }
    }

    // MARK: - Events

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    private var eventsSection: some View {
        Section("Events") {
            if dayEvents.isEmpty {
                Text("No events this day")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .rounded))
            } else {
                ForEach(dayEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            eventStatusBadge(event.status)
                            Text(event.title)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                            Spacer()
                        }

                        if let desc = event.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Text("\(event.startDate) – \(event.endDate)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            if let st = event.startTime, let et = event.endTime {
                                Text("\(st) – \(et)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if event.status == .declined, let reason = event.declineReason, !reason.isEmpty {
                            Text("Reason: \(reason)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.red.opacity(0.8))
                        }

                        // Accept/Decline for pending events from partner
                        if event.status == .pending, event.createdBy != currentUid {
                            if declineReasonFor == event.id {
                                HStack {
                                    TextField("Reason (optional)", text: $declineReasonText)
                                        .font(.system(.caption, design: .rounded))
                                        .textFieldStyle(.roundedBorder)
                                    Button("Send") {
                                        if let id = event.id {
                                            calendarService.respondToEvent(eventId: id, accepted: false, reason: declineReasonText.isEmpty ? nil : declineReasonText)
                                            declineReasonFor = nil
                                            declineReasonText = ""
                                        }
                                    }
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    Button("Cancel") {
                                        declineReasonFor = nil
                                        declineReasonText = ""
                                    }
                                    .font(.system(.caption, design: .rounded))
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Button {
                                        if let id = event.id {
                                            calendarService.respondToEvent(eventId: id, accepted: true, reason: nil)
                                        }
                                    } label: {
                                        Label("Accept", systemImage: "checkmark")
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.fondrPrimary)
                                    .controlSize(.small)

                                    Button {
                                        declineReasonFor = event.id
                                    } label: {
                                        Label("Decline", systemImage: "xmark")
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .controlSize(.small)
                                }
                                .padding(.top, 2)
                            }
                        }

                        // Status for events you proposed
                        if event.createdBy == currentUid && event.status != .pending {
                            Text(event.status == .accepted ? "Partner accepted" : "Partner declined")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(event.status == .accepted ? .green : .red)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingEvent = event }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let id = event.id {
                                calendarService.deleteEvent(eventId: id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showAddEvent = true
            } label: {
                Label("Propose a Date", systemImage: "plus.circle")
            }
        }
    }

    private func eventStatusBadge(_ status: EventStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Text("?")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(4)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
            case .accepted:
                Image(systemName: "checkmark")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(4)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Circle())
            case .declined:
                Image(systemName: "xmark")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(4)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Helpers

    private func loadCurrentState() {
        isBusy = mySlot != nil
        if let slot = mySlot, let start = slot.startTime, let end = slot.endTime {
            useTimeRange = true
            startTime = timeFromString(start, on: date)
            endTime = timeFromString(end, on: date)
            label = slot.label ?? ""
        } else {
            useTimeRange = false
            let cal = Foundation.Calendar.current
            startTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
            endTime = cal.date(bySettingHour: 17, minute: 0, second: 0, of: date) ?? date
        }
    }

    private func timeFromString(_ time: String, on date: Date) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return date }

        var utcCal = Foundation.Calendar.current
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        var comps = utcCal.dateComponents([.year, .month, .day], from: date)
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.timeZone = TimeZone(identifier: "UTC")

        return utcCal.date(from: comps) ?? date
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
