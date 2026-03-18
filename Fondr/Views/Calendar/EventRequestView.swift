import SwiftUI

struct EventRequestView: View {
    @Environment(CalendarService.self) private var calendarService
    let onComplete: () -> Void

    @State private var currentIndex = 0
    @State private var isEnvelopeOpen = false
    @State private var declineMode = false
    @State private var declineReason = ""

    private var pendingEvents: [CalendarEvent] {
        calendarService.pendingPartnerEvents
    }

    private var currentEvent: CalendarEvent? {
        guard currentIndex < pendingEvents.count else { return nil }
        return pendingEvents[currentIndex]
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if let event = currentEvent {
                if !isEnvelopeOpen {
                    envelopeView
                        .transition(.opacity)
                } else {
                    cardRevealView(event: event)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isEnvelopeOpen)
        .onChange(of: pendingEvents.count) { _, newCount in
            if newCount == 0 {
                onComplete()
            }
        }
    }

    // MARK: - Envelope

    private var envelopeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.fill")
                .font(.system(size: 80))
                .foregroundStyle(.fondrPrimary)
                .symbolEffect(.pulse, options: .repeating)

            Text("You have a date request!")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)

            if pendingEvents.count > 1 {
                Text("\(pendingEvents.count) proposals waiting")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation {
                    isEnvelopeOpen = true
                }
            } label: {
                Text("Open")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.fondrPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    // MARK: - Card Reveal

    private func cardRevealView(event: CalendarEvent) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.fondrPrimary.opacity(0.6))

                Text(event.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Label(eventDateLabel(event), systemImage: "calendar")
                        .font(.system(.body, design: .rounded))

                    if let st = event.startTime, let et = event.endTime {
                        Label("\(st) – \(et)", systemImage: "clock")
                            .font(.system(.body, design: .rounded))
                    }
                }
                .foregroundStyle(.secondary)

                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if declineMode {
                    VStack(spacing: 12) {
                        TextField("Why can't you make it?", text: $declineReason, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        HStack(spacing: 16) {
                            Button("Back") {
                                declineMode = false
                                declineReason = ""
                            }
                            .font(.system(.subheadline, design: .rounded))

                            Button("Decline") {
                                respondToCurrentEvent(accepted: false)
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.red)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Button {
                            respondToCurrentEvent(accepted: true)
                        } label: {
                            Text("Accept")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.fondrPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            declineMode = true
                        } label: {
                            Text("Decline")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 24)

            Spacer()

            if pendingEvents.count > 1 {
                Text("\(currentIndex + 1) of \(pendingEvents.count)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Helpers

    private func respondToCurrentEvent(accepted: Bool) {
        guard let event = currentEvent, let id = event.id else { return }
        let reason = accepted ? nil : (declineReason.isEmpty ? nil : declineReason)
        calendarService.respondToEvent(eventId: id, accepted: accepted, reason: reason)

        // Reset state for next event
        declineMode = false
        declineReason = ""
        isEnvelopeOpen = false

        // pendingPartnerEvents is a computed property that re-filters,
        // so responded events drop out automatically. If no more pending,
        // the onChange handler above will call onComplete.
    }

    private func eventDateLabel(_ event: CalendarEvent) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        let outFmt = DateFormatter()
        outFmt.dateFormat = "MMMM d, yyyy"

        guard let start = inFmt.date(from: event.startDate),
              let end = inFmt.date(from: event.endDate) else {
            return "\(event.startDate) – \(event.endDate)"
        }

        if event.startDate == event.endDate {
            return outFmt.string(from: start)
        }

        let shortFmt = DateFormatter()
        shortFmt.dateFormat = "MMM d"
        return "\(shortFmt.string(from: start)) – \(shortFmt.string(from: end))"
    }
}
