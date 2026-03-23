import SwiftUI

struct SwipeTabView: View {
    @Environment(SessionService.self) private var sessionService
    @Environment(ListService.self) private var listService
    @Environment(AppState.self) private var appState
    @State private var showSession = false
    @State private var sessionError: String?
    @State private var isStarting = false

    private var totalSuggested: Int {
        listService.items.filter { $0.status != .done }.count
    }

    var body: some View {
        NavigationStack {
            if showSession, let session = sessionService.activeSession {
                SwipeSessionView(
                    session: session,
                    items: listService.items,
                    isWatchList: listService.isWatchList(session.listId),
                    onDismiss: { showSession = false }
                )
            } else {
                launcher
            }
        }
        .onChange(of: sessionService.activeSession) { _, newValue in
            if newValue != nil && showSession == false {
                // Auto-show if partner started a session
            }
        }
    }

    // MARK: - Launcher

    private var launcher: some View {
        ScrollView {
            VStack(spacing: 24) {
                if listService.lists.isEmpty {
                    // No lists at all
                    Spacer(minLength: 60)
                    EmptyStateView(
                        emoji: "🃏",
                        title: "Nothing to swipe on yet!",
                        subtitle: "Add some ideas to your lists first, then come back to decide together.",
                        ctaTitle: "Go to Lists",
                        ctaAction: { navigateToLists() }
                    )
                } else if totalSuggested < 3 {
                    // Lists exist but too few items
                    Spacer(minLength: 60)
                    EmptyStateView(
                        emoji: "🃏",
                        title: "Need more ideas!",
                        subtitle: "You need at least 3 ideas to start swiping. Add some more to your lists!",
                        ctaTitle: "Go to Lists",
                        ctaAction: { navigateToLists() }
                    )
                } else {
                    normalLauncher
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.fondrBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var normalLauncher: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Can't decide?")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Let's swipe it out")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            // List cards
            ForEach(listService.lists) { list in
                listLaunchCard(list: list)
            }

            // Error
            if let error = sessionError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // History
            if !sessionService.sessionHistory.isEmpty {
                historySection
            }
        }
    }

    // MARK: - List Launch Card

    private func listLaunchCard(list: SharedList) -> some View {
        let listId = list.id
        let suggestedCount = listService.items.filter { $0.listId == listId && $0.status != .done }.count
        let isActiveSession = sessionService.activeSession?.listId == listId
        let isEnabled = suggestedCount >= 3 || isActiveSession

        return Button {
            guard isEnabled else { return }
            HapticManager.shared.light()
            if isActiveSession {
                showSession = true
            } else {
                startSession(listId: listId)
            }
        } label: {
            launchCardLabel(list: list, suggestedCount: suggestedCount, isEnabled: isEnabled, isActiveSession: isActiveSession)
        }
        .buttonStyle(ListCardButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal)
        .accessibilityLabel("\(list.title), \(suggestedCount) ideas")
        .accessibilityHint(isActiveSession ? "Double-tap to continue session" : isEnabled ? "Double-tap to start a swipe session" : "Need at least 3 items to start swiping")
    }

    private func launchCardLabel(list: SharedList, suggestedCount: Int, isEnabled: Bool, isActiveSession: Bool) -> some View {
        let subtitle: String
        let subtitleColor: Color
        if isActiveSession, let session = sessionService.activeSession {
            subtitle = "\(sessionService.mySwipeCount(in: session)) of \(session.itemIds.count) swiped"
            subtitleColor = .fondrPrimary
        } else if isEnabled {
            subtitle = "\(suggestedCount) ideas to swipe through"
            subtitleColor = .secondary
        } else {
            subtitle = "Need at least 3 items"
            subtitleColor = .red
        }

        return HStack(spacing: 14) {
            Text(list.emoji)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(list.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    if isActiveSession {
                        Text("LIVE")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.fondrPrimary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(subtitleColor)
            }

            Spacer()

            if isActiveSession {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.fondrPrimary)
            } else if isEnabled {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                    .foregroundStyle(.fondrPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(isActiveSession ? Color.fondrPrimary.opacity(0.08) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Sessions")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.horizontal)

            ForEach(sessionService.sessionHistory) { session in
                historyRow(session)
            }
        }
        .padding(.top, 8)
    }

    private func historyRow(_ session: SwipeSession) -> some View {
        HStack(spacing: 12) {
            if let list = listService.lists.first(where: { $0.id == session.listId }) {
                Text(list.emoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let list = listService.lists.first(where: { $0.id == session.listId }) {
                    Text(list.title)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                if let date = session.completedAt {
                    Text(date, style: .relative)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if session.matches.isEmpty {
                Text("No matches")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 2) {
                    Text("✨")
                        .font(.caption2)
                    Text("\(session.matches.count) match\(session.matches.count == 1 ? "" : "es")")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.fondrAccent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func navigateToLists() {
        // Post notification to switch to Lists tab
        NotificationCenter.default.post(name: .switchToTab, object: 1)
    }

    private func startSession(listId: String) {
        isStarting = true
        sessionError = nil
        Task {
            do {
                try await sessionService.startSession(listId: listId, items: listService.items)
                await MainActor.run {
                    isStarting = false
                    // Active session listener will pick it up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSession = true
                    }
                }
            } catch {
                await MainActor.run {
                    isStarting = false
                    sessionError = error.localizedDescription
                    HapticManager.shared.error()
                }
            }
        }
    }
}
