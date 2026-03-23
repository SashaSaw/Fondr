import SwiftUI
import Foundation

struct SharedCalendarView: View {
    @Environment(CalendarService.self) private var calendarService
    @Environment(AppState.self) private var appState

    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var showAddEvent = false
    @State private var selectedDayForDetail: Date?
    @State private var dismissedEmptyState = false
    @State private var showHelp = false

    // Drag-to-select state
    @State private var gridWidth: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var dragCurrentIndex: Int?
    @State private var isDragAdding: Bool = true
    @State private var touchDownTime: Date?
    @State private var longPressTimer: Timer?
    @State private var longPressFired = false

    private var cal: Foundation.Calendar { Foundation.Calendar.current }
    private var year: Int { cal.component(.year, from: displayedMonth) }
    private var month: Int { cal.component(.month, from: displayedMonth) }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        let now = Date()
        return cal.component(.year, from: now) == year && cal.component(.month, from: now) == month
    }

    private var daysInGrid: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in range {
            if let date = cal.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(date)
            }
        }

        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    private var availability: [String: (mine: AvailabilitySlot?, partner: AvailabilitySlot?)] {
        calendarService.availabilityForMonth(year: year, month: month)
    }

    private var monthEvents: [CalendarEvent] {
        calendarService.eventsForMonth(year: year, month: month)
    }

    private var upcomingEvents: [CalendarEvent] {
        let todayStr = dateString(from: Date())
        return calendarService.events
            .filter { $0.endDate >= todayStr }
            .sorted { $0.startDate < $1.startDate }
    }

    private var dragSelectedIndices: Set<Int> {
        guard let start = dragStartIndex, let current = dragCurrentIndex else { return [] }
        let lo = min(start, current)
        let hi = max(start, current)
        return Set((lo...hi).filter {
            $0 >= 0 && $0 < daysInGrid.count && daysInGrid[$0] != nil
            && eventsSpanningDate(dateString(from: daysInGrid[$0]!)).isEmpty
        })
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var hasAnyAvailability: Bool {
        !availability.values.allSatisfy({ $0.mine == nil && $0.partner == nil })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasAnyAvailability && upcomingEvents.isEmpty && !dismissedEmptyState {
                    Spacer()
                    EmptyStateView(
                        emoji: "📆",
                        title: "When are you free?",
                        subtitle: "Tap days on the calendar to mark when you're busy",
                        ctaTitle: "Open Calendar",
                        ctaAction: { dismissedEmptyState = true }
                    )
                    Spacer()
                } else {
                    VStack(spacing: 12) {
                        monthHeader
                            .padding(.horizontal)
                        weekdayHeaders
                        calendarGrid
                        legend
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 8)

                    Divider()

                    ScrollView {
                        upcomingEventsSection
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }
                }
            }
            .background(Color.fondrBackground)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.fondrPrimary)
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                CalendarHelpSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddEvent) {
                AddAvailabilitySheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedDayForDetail) { date in
                DayDetailView(date: date)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
            }

            Spacer()

            Text(monthLabel)
                .font(.system(.headline, design: .rounded))

            if !isCurrentMonth {
                Button("Today") {
                    withAnimation {
                        displayedMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.fondrPrimary.opacity(0.15))
                .foregroundStyle(.fondrPrimary)
                .clipShape(Capsule())
            }

            Spacer()

            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
            }

            Button {
                showAddEvent = true
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
            }
            .accessibilityLabel("Propose a date")
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInGrid.enumerated()), id: \.offset) { index, date in
                if let date {
                    dayCell(for: date, index: index)
                } else {
                    Color.clear
                        .frame(height: 56)
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { gridWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in gridWidth = newWidth }
            }
        )
        .coordinateSpace(name: "calendarGrid")
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("calendarGrid"))
                .onChanged { value in
                    guard let index = gridIndexAt(value.location),
                          index < daysInGrid.count,
                          daysInGrid[index] != nil else { return }

                    if dragStartIndex == nil {
                        dragStartIndex = index
                        dragCurrentIndex = index
                        touchDownTime = Date()
                        longPressFired = false
                        HapticManager.shared.light()
                        if let date = daysInGrid[index] {
                            let dateStr = dateString(from: date)
                            isDragAdding = availability[dateStr]?.mine == nil
                        }
                        // Start long-press timer
                        longPressTimer?.invalidate()
                        let capturedIndex = index
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            DispatchQueue.main.async {
                                guard dragStartIndex == capturedIndex,
                                      dragCurrentIndex == capturedIndex,
                                      let date = daysInGrid[capturedIndex] else { return }
                                longPressFired = true
                                dragStartIndex = nil
                                dragCurrentIndex = nil
                                HapticManager.shared.medium()
                                selectedDayForDetail = date
                            }
                        }
                    }

                    if dragCurrentIndex != index {
                        // Finger moved to a different cell — cancel long press, treat as drag
                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        HapticManager.shared.selection()
                    }
                    dragCurrentIndex = index
                }
                .onEnded { value in
                    longPressTimer?.invalidate()
                    longPressTimer = nil

                    // If the long press already fired, don't also toggle
                    guard !longPressFired else {
                        dragStartIndex = nil
                        dragCurrentIndex = nil
                        touchDownTime = nil
                        return
                    }

                    let distance = hypot(
                        value.location.x - value.startLocation.x,
                        value.location.y - value.startLocation.y
                    )

                    if distance < 10 {
                        // Tap — toggle just the tapped cell
                        if let startIdx = dragStartIndex,
                           let date = daysInGrid[startIdx] {
                            let dateStr = dateString(from: date)
                            if eventsSpanningDate(dateStr).isEmpty {
                                calendarService.toggleAvailability(for: date)
                            }
                        }
                    } else {
                        // Drag — apply to entire selected range
                        applyDragSelection()
                    }

                    dragStartIndex = nil
                    dragCurrentIndex = nil
                    touchDownTime = nil
                }
        )
    }

    private func dayCell(for date: Date, index: Int) -> some View {
        let dateStr = dateString(from: date)
        let isToday = cal.isDateInToday(date)
        let entry = availability[dateStr]
        let hasMine = entry?.mine != nil
        let hasPartner = entry?.partner != nil
        let dayEvents = eventsSpanningDate(dateStr)
        let isBeingSelected = dragSelectedIndices.contains(index)

        let hasEvent = !dayEvents.isEmpty

        return VStack(spacing: 1) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.fondrAccent)
                        .frame(width: 28, height: 28)
                }
                Text("\(cal.component(.day, from: date))")
                    .font(.system(.callout, design: .rounded, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
            }
            .frame(height: 26)

            if hasMine || hasPartner {
                heartIndicator(hasMine: hasMine, hasPartner: hasPartner)
            } else if hasEvent {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fondrAccent)
                    .frame(height: 20)
            } else {
                Spacer().frame(height: 20)
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cellBackground(
                    hasEvent: hasEvent,
                    isBeingSelected: isBeingSelected
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isBeingSelected
                        ? (isDragAdding ? Color.fondrSecondary : Color.red.opacity(0.5))
                        : hasEvent
                            ? Color.fondrAccent
                            : Color(.separator).opacity(0.3),
                    lineWidth: isBeingSelected ? 2 : (hasEvent ? 1.5 : 0.5)
                )
        )
        .contentShape(Rectangle())
    }

    // MARK: - Heart Indicator

    private func heartIndicator(hasMine: Bool, hasPartner: Bool) -> some View {
        let bothBusy = hasMine && hasPartner
        return ZStack {
            if hasMine {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fondrSecondary)
                    .mask { HeartCrackMask(side: .left) }
                    .rotationEffect(.degrees(bothBusy ? -8 : -5))
                    .offset(x: bothBusy ? -1.5 : 0)
            }
            if hasPartner {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fondrPartner)
                    .mask { HeartCrackMask(side: .right) }
                    .rotationEffect(.degrees(bothBusy ? 8 : 5))
                    .offset(x: bothBusy ? 1.5 : 0)
            }
        }
        .frame(height: 20)
    }

    private func cellBackground(hasEvent: Bool, isBeingSelected: Bool) -> Color {
        if isBeingSelected {
            return isDragAdding
                ? Color.fondrSecondary.opacity(0.3)
                : Color.red.opacity(0.12)
        }
        if hasEvent {
            return Color.fondrAccent.opacity(0.15)
        }
        return .white
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendHeartItem(color: .fondrSecondary, label: "You're busy", isLeft: true)
            legendHeartItem(color: .fondrPartner, label: "Partner's busy", isLeft: false)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fondrAccent)
                Text("Event")
            }
        }
        .font(.system(.caption2, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private func legendHeartItem(color: Color, label: String, isLeft: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
                .mask { HeartCrackMask(side: isLeft ? .left : .right) }
                .rotationEffect(.degrees(isLeft ? -5 : 5))
            Text(label)
        }
    }

    // MARK: - Upcoming Events

    @State private var declineReasonFor: String?
    @State private var declineReasonText: String = ""

    private var currentUid: String? { TokenStore.shared.userId }

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming Events")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            if upcomingEvents.isEmpty {
                EmptyStateView(
                    emoji: "📅",
                    title: "No upcoming dates",
                    subtitle: "Propose a date and it will show up here",
                    ctaTitle: "Propose a Date",
                    ctaAction: { showAddEvent = true }
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(upcomingEvents) { event in
                    FondrCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                statusIcon(for: event)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    Text(eventDateRangeLabel(event))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    calendarService.deleteEvent(eventId: event.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let desc = event.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            if let st = event.startTime, let et = event.endTime {
                                Label("\(st) – \(et)", systemImage: "clock")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
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
                                            calendarService.respondToEvent(eventId: event.id, accepted: false, reason: declineReasonText.isEmpty ? nil : declineReasonText)
                                            declineReasonFor = nil
                                            declineReasonText = ""
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
                                            calendarService.respondToEvent(eventId: event.id, accepted: true, reason: nil)
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

                            // Status label for events you proposed
                            if event.createdBy == currentUid && event.status != .pending {
                                Text(event.status == .accepted ? "Partner accepted" : "Partner declined")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(event.status == .accepted ? .green : .red)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statusIcon(for event: CalendarEvent) -> some View {
        Group {
            switch event.status {
            case .pending:
                Text("?")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 22, height: 22)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
            case .accepted:
                Image(systemName: "checkmark")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(width: 22, height: 22)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Circle())
            case .declined:
                Image(systemName: "xmark")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 22, height: 22)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Drag Helpers

    private func gridIndexAt(_ point: CGPoint) -> Int? {
        guard gridWidth > 0 else { return nil }
        let cellWidth = gridWidth / 7
        let cellHeight: CGFloat = 60 // 56 cell + 4 spacing

        let col = min(max(Int(point.x / cellWidth), 0), 6)
        let row = min(max(Int(point.y / cellHeight), 0), 5)
        let index = row * 7 + col

        guard index >= 0, index < daysInGrid.count else { return nil }
        return index
    }

    private func applyDragSelection() {
        for index in dragSelectedIndices {
            guard let date = daysInGrid[index] else { continue }
            let dateStr = dateString(from: date)
            guard eventsSpanningDate(dateStr).isEmpty else { continue }
            let isCurrentlyMarked = availability[dateStr]?.mine != nil
            if isDragAdding && !isCurrentlyMarked {
                calendarService.toggleAvailability(for: date)
            } else if !isDragAdding && isCurrentlyMarked {
                calendarService.toggleAvailability(for: date)
            }
        }
    }

    // MARK: - General Helpers

    private func shiftMonth(by value: Int) {
        withAnimation {
            if let newDate = cal.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newDate
            }
        }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func eventsSpanningDate(_ dateStr: String) -> [CalendarEvent] {
        monthEvents.filter { dateStr >= $0.startDate && dateStr <= $0.endDate }
    }

    private func eventDateRangeLabel(_ event: CalendarEvent) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"

        let outFmt = DateFormatter()
        outFmt.dateFormat = "MMM d"

        guard let start = inFmt.date(from: event.startDate),
              let end = inFmt.date(from: event.endDate) else {
            return "\(event.startDate) – \(event.endDate)"
        }

        if event.startDate == event.endDate {
            return outFmt.string(from: start)
        }

        let days = (Foundation.Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return "\(outFmt.string(from: start)) – \(outFmt.string(from: end)) (\(days) days)"
    }
}

// MARK: - Heart Crack Mask

private struct HeartCrackMask: View {
    enum Side { case left, right }
    let side: Side

    var body: some View {
        GeometryReader { geo in
            HeartCrackMaskShape(side: side)
                .fill()
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct HeartCrackMaskShape: Shape {
    let side: HeartCrackMask.Side

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = rect.midX
        // Depth of zigzag — subtle but visible
        let d: CGFloat = w * 0.06

        // Zigzag edge: 2 zags matching the broken heart emoji style
        // top-center → right → left → right → bottom-center
        var path = Path()
        switch side {
        case .left:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX + d, y: h * 0.3))
            path.addLine(to: CGPoint(x: midX - d, y: h * 0.5))
            path.addLine(to: CGPoint(x: midX + d, y: h * 0.7))
            path.addLine(to: CGPoint(x: midX, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()
        case .right:
            path.move(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX + d, y: h * 0.3))
            path.addLine(to: CGPoint(x: midX - d, y: h * 0.5))
            path.addLine(to: CGPoint(x: midX + d, y: h * 0.7))
            path.addLine(to: CGPoint(x: midX, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
        }
        return path
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

// MARK: - Calendar Help Sheet

private struct CalendarHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CalendarHelpRow(
                        icon: "hand.tap",
                        title: "Tap to toggle busy",
                        description: "Tap any day to mark yourself as busy. Tap again to clear it.",
                        animation: .tap
                    )

                    CalendarHelpRow(
                        icon: "hand.draw",
                        title: "Drag to select range",
                        description: "Press and drag across multiple days to mark or clear them all at once.",
                        animation: .drag
                    )

                    CalendarHelpRow(
                        icon: "hand.tap.fill",
                        title: "Long press for details",
                        description: "Hold a day for 1 second to see events and details for that date.",
                        animation: .longPress
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("How to use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

private enum CalendarHelpAnimation {
    case tap, drag, longPress
}

private struct CalendarHelpRow: View {
    let icon: String
    let title: String
    let description: String
    let animation: CalendarHelpAnimation

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            CalendarAnimatedDemo(animation: animation)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CalendarAnimatedDemo: View {
    let animation: CalendarHelpAnimation
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemGray6))

            switch animation {
            case .tap:
                tapAnimation
            case .drag:
                dragAnimation
            case .longPress:
                longPressAnimation
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private var tapAnimation: some View {
        ZStack {
            HStack(spacing: 3) {
                ForEach(Array(0..<3), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == 1 ? Color.fondrSecondary.opacity(phase) : Color(UIColor.systemGray5))
                        .frame(width: 14, height: 14)
                }
            }

            Circle()
                .fill(Color.fondrPrimary.opacity(0.5))
                .frame(width: 16, height: 16)
                .scaleEffect(phase < 0.5 ? 0.8 : 1.2)
                .opacity(phase < 0.3 ? 0.8 : 0.0)
        }
    }

    private var dragAnimation: some View {
        ZStack {
            HStack(spacing: 3) {
                ForEach(Array(0..<3), id: \.self) { i in
                    let filled = CGFloat(i) / 2.0 <= phase
                    RoundedRectangle(cornerRadius: 3)
                        .fill(filled ? Color.fondrSecondary.opacity(0.6) : Color(UIColor.systemGray5))
                        .frame(width: 14, height: 14)
                }
            }

            Circle()
                .fill(Color.fondrPrimary.opacity(0.4))
                .frame(width: 14, height: 14)
                .offset(x: -17 + (34 * phase), y: 0)
        }
    }

    private var longPressAnimation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(UIColor.systemGray5))
                .frame(width: 14, height: 14)

            Circle()
                .stroke(Color.fondrPrimary.opacity(1 - phase), lineWidth: 2)
                .frame(width: 10 + (14 * phase), height: 10 + (14 * phase))

            Circle()
                .fill(Color.fondrPrimary.opacity(0.4))
                .frame(width: 14, height: 14)
                .scaleEffect(0.9 + 0.1 * phase)
        }
    }
}
