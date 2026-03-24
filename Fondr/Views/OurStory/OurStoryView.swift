import SwiftUI

struct OurStoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(OurStoryService.self) private var ourStoryService
    @Environment(CalendarService.self) private var calendarService

    @State private var showAnniversarySheet = false
    @State private var showAddDateSheet = false
    @State private var showSettings = false
    @State private var partnerImageUrl: String?
    private var currentUser: AppUser? { appState.authService.appUser }
    private var currentPair: Pair? { appState.pairService.currentPair }
    private var anniversary: Date? { currentPair?.anniversary }

    private var yourName: String {
        currentUser?.displayName ?? "You"
    }

    private var partnerDisplayName: String {
        appState.partnerName ?? "Partner"
    }

    private var daysTogether: Int? {
        guard let anniversary else { return nil }
        return Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day
    }

    private var milestoneText: String? {
        guard let days = daysTogether, days > 0 else { return nil }
        switch days {
        case 100: return "100 days together!"
        case 365: return "1 year together!"
        case 500: return "500 days together!"
        case 1000: return "1,000 days together!"
        default:
            if days > 365 && days % 365 == 0 {
                return "\(days / 365) years together!"
            }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CoupleProfileHeader(
                        yourName: yourName,
                        partnerName: partnerDisplayName,
                        yourImageUrl: currentUser?.profileImageUrl,
                        partnerImageUrl: $partnerImageUrl,
                        partnerUid: currentUser?.partnerUid,
                        onImageUploaded: { url in
                            appState.authService.appUser?.profileImageUrl = url
                        },
                        onImageRemoved: {
                            appState.authService.appUser?.profileImageUrl = nil
                        }
                    )

                    anniversarySection

                    if let milestoneText {
                        milestoneBanner(milestoneText)
                    }

                    upcomingDatesSection
                }
                .padding()
            }
            .background(Color.fondrBackground)
            .navigationTitle("Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.fondrPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showAnniversarySheet) {
                SetAnniversarySheet(existingDate: anniversary)
            }
            .sheet(isPresented: $showAddDateSheet) {
                AddSignificantDateSheet()
            }
        }
    }

    // MARK: - Anniversary Section

    @ViewBuilder
    private var anniversarySection: some View {
        FondrCard {
            VStack(spacing: 8) {
                if let anniversary {
                    Text(anniversary, style: .date)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let days = daysTogether, days >= 0 {
                        Text("\(days) days together")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.fondrPrimary)
                    }

                    Button("Edit") {
                        showAnniversarySheet = true
                    }
                    .font(.caption)
                    .foregroundStyle(.fondrSecondary)
                } else {
                    Button {
                        showAnniversarySheet = true
                    } label: {
                        Label("Set your anniversary", systemImage: "heart.circle")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.fondrPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Milestone Banner

    private func milestoneBanner(_ text: String) -> some View {
        FondrCard {
            HStack {
                Text("🎉")
                    .font(.title)
                Text(text)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.fondrAccent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Upcoming Dates Section

    @ViewBuilder
    private var upcomingDatesSection: some View {
        let dates = Array(ourStoryService.upcomingDates(anniversary: anniversary, calendarEvents: calendarService.events).prefix(5))

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Coming Up")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    showAddDateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.fondrPrimary)
                }
            }

            if dates.isEmpty {
                FondrCard {
                    Text("No upcoming dates yet. Tap + to add one!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(dates) { upcoming in
                    if upcoming.isAutoGenerated {
                        upcomingDateCard(upcoming)
                    } else {
                        upcomingDateCard(upcoming)
                            .contextMenu {
                                Button(role: .destructive) {
                                    ourStoryService.deleteSignificantDate(dateId: upcoming.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    private func upcomingDateCard(_ upcoming: UpcomingDate) -> some View {
        HStack(spacing: 12) {
            Text(upcoming.emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text(upcoming.title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                Text(upcoming.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(upcoming.daysUntil == 0 ? "Today!" : "in \(upcoming.daysUntil)d")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(upcoming.daysUntil == 0 ? Color.fondrAccent : Color.fondrSecondary.opacity(0.2))
                .foregroundStyle(upcoming.daysUntil == 0 ? .white : .fondrSecondary)
                .clipShape(Capsule())
        }
        .padding()
        .background(upcoming.isCalendarEvent ? Color.fondrAccent.opacity(0.12) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.fondrAccent, lineWidth: upcoming.isCalendarEvent ? 1.5 : 0)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
