import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class CalendarService {
    var slots: [AvailabilitySlot] = []
    var events: [CalendarEvent] = []
    var partnerTimezone: String?
    var errorMessage: String?

    private var slotsListener: ListenerRegistration?
    private var eventsListener: ListenerRegistration?
    private var currentPairId: String?
    private var db: Firestore { Firestore.firestore() }

    deinit {
        slotsListener?.remove()
        eventsListener?.remove()
    }

    // MARK: - Computed

    var mySlots: [AvailabilitySlot] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return slots.filter { $0.userId == uid }
    }

    var partnerSlots: [AvailabilitySlot] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return slots.filter { $0.userId != uid }
    }

    var pendingPartnerEvents: [CalendarEvent] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        return events.filter { $0.createdBy != uid && $0.status == .pending }
    }

    // MARK: - Listeners

    func startListening(pairId: String, partnerUid: String) {
        stopListening()
        currentPairId = pairId

        let pairRef = db.collection(Constants.Firestore.pairsCollection).document(pairId)

        slotsListener = pairRef
            .collection(Constants.Calendar.collection)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot else {
                    self?.errorMessage = error?.localizedDescription
                    return
                }
                self?.slots = snapshot.documents.compactMap { try? $0.data(as: AvailabilitySlot.self) }
            }

        eventsListener = pairRef
            .collection(Constants.Calendar.eventsCollection)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    self?.errorMessage = error?.localizedDescription
                    return
                }
                var decoded: [CalendarEvent] = []
                for doc in snapshot.documents {
                    do {
                        let event = try doc.data(as: CalendarEvent.self)
                        decoded.append(event)
                    } catch {
                        print("⚠️ [CalendarService] Failed to decode event \(doc.documentID): \(error)")
                    }
                }
                let firestoreIds = Set(decoded.compactMap(\.id))
                // Keep optimistic events that haven't appeared in Firestore yet
                let pendingOptimistic = self.events.filter { event in
                    guard let id = event.id else { return false }
                    return !firestoreIds.contains(id) && UUID(uuidString: id) != nil
                }
                self.events = decoded + pendingOptimistic
            }

        Task {
            do {
                let doc = try await db.collection(Constants.Firestore.usersCollection)
                    .document(partnerUid)
                    .getDocument()
                let tz = doc.data()?["timezone"] as? String
                await MainActor.run {
                    self.partnerTimezone = tz
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopListening() {
        slotsListener?.remove()
        slotsListener = nil
        eventsListener?.remove()
        eventsListener = nil
        slots = []
        events = []
        partnerTimezone = nil
        currentPairId = nil
    }

    // MARK: - Availability CRUD

    func toggleAvailability(for date: Date) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dateStr = dateString(from: date)

        if let existingIndex = slots.firstIndex(where: { $0.userId == uid && $0.date == dateStr }) {
            let existing = slots[existingIndex]
            slots.remove(at: existingIndex) // Optimistic remove
            if let slotId = existing.id {
                deleteSlot(slotId: slotId)
            }
        } else {
            var slot = AvailabilitySlot(
                userId: uid,
                date: dateStr,
                startTime: nil,
                endTime: nil,
                label: nil,
                createdAt: Date()
            )
            slot.id = UUID().uuidString // Temp local id for immediate UI
            slots.append(slot) // Optimistic add
            addSlotToFirestore(slot)
        }
    }

    func setTimeRange(for date: Date, start: String, end: String, label: String?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dateStr = dateString(from: date)

        if let existing = slots.first(where: { $0.userId == uid && $0.date == dateStr }),
           let slotId = existing.id {
            Task {
                do {
                    try await slotRef(slotId).updateData([
                        "startTime": start,
                        "endTime": end,
                        "label": label as Any
                    ])
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        } else {
            let slot = AvailabilitySlot(
                userId: uid,
                date: dateStr,
                startTime: start,
                endTime: end,
                label: label?.isEmpty == true ? nil : label,
                createdAt: Date()
            )
            addSlotToFirestore(slot)
        }
    }

    func deleteSlot(slotId: String) {
        guard let pairId = currentPairId else { return }
        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Calendar.collection)
                    .document(slotId)
                    .delete()
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

    // MARK: - Event CRUD

    func addEvent(title: String, description: String?, startDate: String, endDate: String, startTime: String?, endTime: String?) {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        var event = CalendarEvent(
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            startTime: startTime,
            endTime: endTime,
            createdBy: uid,
            createdAt: Date(),
            status: .pending
        )
        event.id = UUID().uuidString // Temp local id for immediate UI
        events.append(event) // Optimistic add

        Task {
            do {
                let docRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Calendar.eventsCollection)
                    .document(event.id!)
                try docRef.setData(from: event)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func updateEvent(eventId: String, title: String, description: String?, startDate: String, endDate: String, startTime: String?, endTime: String?) {
        guard let pairId = currentPairId else { return }
        Task {
            do {
                var data: [String: Any] = [
                    "title": title,
                    "startDate": startDate,
                    "endDate": endDate
                ]
                data["description"] = description as Any
                data["startTime"] = startTime as Any
                data["endTime"] = endTime as Any
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Calendar.eventsCollection)
                    .document(eventId)
                    .updateData(data)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func respondToEvent(eventId: String, accepted: Bool, reason: String?) {
        guard let pairId = currentPairId,
              let uid = Auth.auth().currentUser?.uid else { return }

        // Optimistic update
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].status = accepted ? .accepted : .declined
            events[index].declineReason = reason
            events[index].respondedAt = Date()
        }

        Task {
            do {
                var data: [String: Any] = [
                    "status": accepted ? EventStatus.accepted.rawValue : EventStatus.declined.rawValue,
                    "respondedAt": FieldValue.serverTimestamp()
                ]
                if let reason, !reason.isEmpty {
                    data["declineReason"] = reason
                }
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Calendar.eventsCollection)
                    .document(eventId)
                    .updateData(data)

                // If accepted, create availability slots for each date in the event range
                if accepted, let event = self.events.first(where: { $0.id == eventId }) {
                    await self.createSlotsForEventRange(event: event, userId: uid, pairId: pairId)
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func createSlotsForEventRange(event: CalendarEvent, userId: String, pairId: String) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard var current = formatter.date(from: event.startDate),
              let end = formatter.date(from: event.endDate) else { return }

        let calendar = Foundation.Calendar.current
        let colRef = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .collection(Constants.Calendar.collection)

        while current <= end {
            let dateStr = formatter.string(from: current)
            // Only create if user doesn't already have a slot for this date
            let exists = slots.contains { $0.userId == userId && $0.date == dateStr }
            if !exists {
                let slot = AvailabilitySlot(
                    userId: userId,
                    date: dateStr,
                    startTime: event.startTime,
                    endTime: event.endTime,
                    label: event.title,
                    createdAt: Date()
                )
                do {
                    try colRef.addDocument(from: slot)
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
    }

    func deleteEvent(eventId: String) {
        guard let pairId = currentPairId else { return }

        // Optimistic removal so UI updates immediately
        events.removeAll { $0.id == eventId }

        Task {
            do {
                try await db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Calendar.eventsCollection)
                    .document(eventId)
                    .delete()
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
        guard let uid = Auth.auth().currentUser?.uid else { return [:] }
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
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
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
            var cal = Foundation.Calendar.current
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

        var localCal = Foundation.Calendar.current
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

    private func addSlotToFirestore(_ slot: AvailabilitySlot) {
        guard let pairId = currentPairId else { return }
        Task {
            do {
                let colRef = db.collection(Constants.Firestore.pairsCollection)
                    .document(pairId)
                    .collection(Constants.Calendar.collection)
                try colRef.addDocument(from: slot)
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func slotRef(_ slotId: String) -> DocumentReference {
        db.collection(Constants.Firestore.pairsCollection)
            .document(currentPairId ?? "")
            .collection(Constants.Calendar.collection)
            .document(slotId)
    }
}
