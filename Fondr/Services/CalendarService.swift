import Foundation

@Observable
final class CalendarService {
    var slots: [AvailabilitySlot] = []
    var events: [CalendarEvent] = []
    var partnerTimezone: String?
    var errorMessage: String?

    private var currentPairId: String?

    // MARK: - Computed

    var mySlots: [AvailabilitySlot] {
        guard let uid = TokenStore.shared.userId else { return [] }
        return slots.filter { $0.userId == uid }
    }

    var partnerSlots: [AvailabilitySlot] {
        guard let uid = TokenStore.shared.userId else { return [] }
        return slots.filter { $0.userId != uid }
    }

    var pendingPartnerEvents: [CalendarEvent] {
        guard let uid = TokenStore.shared.userId else { return [] }
        return events.filter { $0.createdBy != uid && $0.status == .pending }
    }

    // MARK: - Listeners

    func startListening(pairId: String, partnerUid: String) {
        stopListening()
        currentPairId = pairId

        // Initial load
        Task {
            do {
                async let loadedSlots: [AvailabilitySlot] = APIClient.shared.get("/pairs/\(pairId)/availability")
                async let loadedEvents: [CalendarEvent] = APIClient.shared.get("/pairs/\(pairId)/events")
                let (s, e) = try await (loadedSlots, loadedEvents)
                await MainActor.run {
                    self.slots = s
                    self.events = e
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }

        // WebSocket events
        WebSocketManager.shared.on("availability:created") { [weak self] (slot: AvailabilitySlot) in
            self?.slots.removeAll { $0.userId == slot.userId && $0.date == slot.date }
            self?.slots.append(slot)
        }
        WebSocketManager.shared.on("availability:updated") { [weak self] (slot: AvailabilitySlot) in
            if let i = self?.slots.firstIndex(where: { $0.id == slot.id }) {
                self?.slots[i] = slot
            }
        }
        WebSocketManager.shared.on("availability:deleted") { [weak self] (payload: DeletePayload) in
            self?.slots.removeAll { $0.id == payload.id }
        }
        WebSocketManager.shared.on("event:created") { [weak self] (event: CalendarEvent) in
            self?.events.append(event)
        }
        WebSocketManager.shared.on("event:updated") { [weak self] (event: CalendarEvent) in
            if let i = self?.events.firstIndex(where: { $0.id == event.id }) {
                self?.events[i] = event
            }
        }
        WebSocketManager.shared.on("event:deleted") { [weak self] (payload: DeletePayload) in
            self?.events.removeAll { $0.id == payload.id }
        }
    }

    func stopListening() {
        WebSocketManager.shared.removeHandlers(for: [
            "availability:created", "availability:updated", "availability:deleted",
            "event:created", "event:updated", "event:deleted"
        ])
        slots = []
        events = []
        partnerTimezone = nil
        currentPairId = nil
    }

    // MARK: - Availability CRUD

    func toggleAvailability(for date: Date) {
        guard let uid = TokenStore.shared.userId else { return }
        let dateStr = dateString(from: date)

        if let existingIndex = slots.firstIndex(where: { $0.userId == uid && $0.date == dateStr }) {
            let existing = slots[existingIndex]
            slots.remove(at: existingIndex) // Optimistic remove
            deleteSlot(slotId: existing.id)
        } else {
            var slot = AvailabilitySlot(userId: uid, date: dateStr)
            slot.id = UUID().uuidString // Temp local id
            slots.append(slot) // Optimistic add
            createSlot(date: dateStr, startTime: nil, endTime: nil, label: nil)
        }
    }

    func setTimeRange(for date: Date, start: String, end: String, label: String?) {
        guard let uid = TokenStore.shared.userId else { return }
        let dateStr = dateString(from: date)

        if let existing = slots.first(where: { $0.userId == uid && $0.date == dateStr }) {
            Task {
                do {
                    guard let pairId = currentPairId else { return }
                    let body = UpdateSlotBody(startTime: start, endTime: end, label: label)
                    let _: AvailabilitySlot = try await APIClient.shared.patch("/pairs/\(pairId)/availability/\(existing.id)", body: body)
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        } else {
            createSlot(date: dateStr, startTime: start, endTime: end, label: label?.isEmpty == true ? nil : label)
        }
    }

    func deleteSlot(slotId: String) {
        guard let pairId = currentPairId else { return }
        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pairId)/availability/\(slotId)")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func isAvailable(userId: String, date: Date) -> Bool {
        let dateStr = dateString(from: date)
        return slots.contains { $0.userId == userId && $0.date == dateStr }
    }

    func slotForDate(userId: String, date: Date) -> AvailabilitySlot? {
        let dateStr = dateString(from: date)
        return slots.first { $0.userId == userId && $0.date == dateStr }
    }

    func removeMySlots(for dateStrings: [String]) {
        guard let uid = TokenStore.shared.userId else { return }
        for dateStr in dateStrings {
            if let index = slots.firstIndex(where: { $0.userId == uid && $0.date == dateStr }) {
                let slotId = slots[index].id
                slots.remove(at: index)
                deleteSlot(slotId: slotId)
            }
        }
    }

    // MARK: - Event CRUD

    func addEvent(title: String, description: String?, startDate: String, endDate: String, startTime: String?, endTime: String?) {
        guard let pairId = currentPairId else { return }

        var event = CalendarEvent(
            title: title, description: description,
            startDate: startDate, endDate: endDate,
            startTime: startTime, endTime: endTime,
            createdBy: TokenStore.shared.userId ?? ""
        )
        event.id = UUID().uuidString
        events.append(event) // Optimistic

        Task {
            do {
                let body = CreateEventBody(
                    title: title, description: description,
                    startDate: startDate, endDate: endDate,
                    startTime: startTime, endTime: endTime
                )
                let _: CalendarEvent = try await APIClient.shared.post("/pairs/\(pairId)/events", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func updateEvent(eventId: String, title: String, description: String?, startDate: String, endDate: String, startTime: String?, endTime: String?) {
        guard let pairId = currentPairId else { return }
        Task {
            do {
                let body = UpdateEventBody(
                    title: title, description: description,
                    startDate: startDate, endDate: endDate,
                    startTime: startTime, endTime: endTime
                )
                let _: CalendarEvent = try await APIClient.shared.patch("/pairs/\(pairId)/events/\(eventId)", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func respondToEvent(eventId: String, accepted: Bool, reason: String?) {
        guard let pairId = currentPairId else { return }

        // Optimistic update
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].status = accepted ? .accepted : .declined
            events[index].declineReason = reason
            events[index].respondedAt = Date()
        }

        Task {
            do {
                let body = RespondBody(accepted: accepted, reason: reason)
                let _: CalendarEvent = try await APIClient.shared.post("/pairs/\(pairId)/events/\(eventId)/respond", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteEvent(eventId: String) {
        guard let pairId = currentPairId else { return }
        events.removeAll { $0.id == eventId } // Optimistic

        Task {
            do {
                try await APIClient.shared.delete("/pairs/\(pairId)/events/\(eventId)")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let dateStr = dateString(from: date)
        return events.filter { dateStr >= $0.startDate && dateStr <= $0.endDate }
    }

    func eventsForMonth(year: Int, month: Int) -> [CalendarEvent] {
        let startStr = String(format: "%04d-%02d-01", year, month)
        let endStr = String(format: "%04d-%02d-31", year, month)
        return events.filter { $0.startDate <= endStr && $0.endDate >= startStr }
    }

    // MARK: - Query Helpers

    func availabilityForMonth(year: Int, month: Int) -> [String: (mine: AvailabilitySlot?, partner: AvailabilitySlot?)] {
        guard let uid = TokenStore.shared.userId else { return [:] }
        let prefix = String(format: "%04d-%02d", year, month)

        var result: [String: (mine: AvailabilitySlot?, partner: AvailabilitySlot?)] = [:]

        for slot in slots where slot.date.hasPrefix(prefix) {
            var entry = result[slot.date] ?? (mine: nil, partner: nil)
            if slot.userId == uid {
                entry.mine = slot
            } else {
                entry.partner = slot
            }
            result[slot.date] = entry
        }

        return result
    }

    func overlapsForDate(_ date: Date) -> [OverlapBlock] {
        guard let uid = TokenStore.shared.userId else { return [] }
        let dateStr = dateString(from: date)

        let mySlot = slots.first { $0.userId == uid && $0.date == dateStr && $0.startTime != nil && $0.endTime != nil }
        let partnerSlot = slots.first { $0.userId != uid && $0.date == dateStr && $0.startTime != nil && $0.endTime != nil }

        guard let mine = mySlot, let partner = partnerSlot,
              let myStart = mine.startTime, let myEnd = mine.endTime,
              let pStart = partner.startTime, let pEnd = partner.endTime else {
            return []
        }

        let overlapStart = max(myStart, pStart)
        let overlapEnd = min(myEnd, pEnd)

        guard overlapStart < overlapEnd else { return [] }

        return [OverlapBlock(
            date: date,
            startTime: overlapStart,
            endTime: overlapEnd,
            yourSlot: mine,
            partnerSlot: partner
        )]
    }

    // MARK: - Timezone Conversion

    func utcToLocal(_ timeString: String, on date: Date, timezone: String) -> String {
        guard let tz = TimeZone(identifier: timezone) else { return timeString }
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return timeString }

        let utcCalendar = {
            var cal = Calendar.current
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal
        }()

        var comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.timeZone = TimeZone(identifier: "UTC")

        guard let utcDate = utcCalendar.date(from: comps) else { return timeString }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = tz
        return formatter.string(from: utcDate)
    }

    func localToUtc(_ timeString: Date, on date: Date, timezone: String) -> String {
        guard let tz = TimeZone(identifier: timezone) else { return "00:00" }

        var localCal = Calendar.current
        localCal.timeZone = tz

        let timeComps = localCal.dateComponents([.hour, .minute], from: timeString)
        var dateComps = localCal.dateComponents([.year, .month, .day], from: date)
        dateComps.hour = timeComps.hour
        dateComps.minute = timeComps.minute
        dateComps.timeZone = tz

        guard let localDate = localCal.date(from: dateComps) else { return "00:00" }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: localDate)
    }

    func formatTimeRange(start: String, end: String, timezone: String, on date: Date) -> String {
        let localStart = utcToLocal(start, on: date, timezone: timezone)
        let localEnd = utcToLocal(end, on: date, timezone: timezone)
        return "\(localStart) – \(localEnd)"
    }

    // MARK: - Private Helpers

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func createSlot(date: String, startTime: String?, endTime: String?, label: String?) {
        guard let pairId = currentPairId else { return }
        Task {
            do {
                let body = CreateSlotBody(date: date, startTime: startTime, endTime: endTime, label: label)
                let _: AvailabilitySlot = try await APIClient.shared.post("/pairs/\(pairId)/availability", body: body)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Request DTOs

private struct CreateSlotBody: Encodable {
    let date: String
    let startTime: String?
    let endTime: String?
    let label: String?
}

private struct UpdateSlotBody: Encodable {
    let startTime: String
    let endTime: String
    let label: String?
}

private struct CreateEventBody: Encodable {
    let title: String
    let description: String?
    let startDate: String
    let endDate: String
    let startTime: String?
    let endTime: String?
}

private struct UpdateEventBody: Encodable {
    let title: String?
    let description: String?
    let startDate: String?
    let endDate: String?
    let startTime: String?
    let endTime: String?
}

private struct RespondBody: Encodable {
    let accepted: Bool
    let reason: String?
}
