import SwiftUI

struct SwipeTabView: View {
    @Environment(SessionService.self) private var sessionService
    @Environment(ListService.self) private var listService
    @Environment(AppState.self) private var appState
    @State private var showSession = false
    @State private var sessionError: String?
    @State private var isStarting = false
    @State private var showExistingSessionPrompt = false
    @State private var pendingListId: String?

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
                // Header
                VStack(spacing: 8) {
                    Text("Can't decide?")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Let's swipe it out")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Active session banner
                if let session = sessionService.activeSession {
                    activeSessionBanner(session)
                }

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

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Swipe")
        .alert("Unfinished Session", isPresented: $showExistingSessionPrompt) {
            Button("Continue") {
                showSession = true
            }
            Button("Start Fresh", role: .destructive) {
                if let id = sessionService.activeSession?.id {
                    sessionService.discardSession(sessionId: id)
                }
                if let listId = pendingListId {
                    startSession(listId: listId)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have an unfinished session. Continue it or start a new one?")
        }
    }

    // MARK: - Active Session Banner

    private func activeSessionBanner(_ session: SwipeSession) -> some View {
        Button {
            showSession = true
        } label: {
            FondrCard {
                HStack(spacing: 12) {
                    if let list = listService.lists.first(where: { $0.id == session.listId }) {
                        Text(list.emoji)
                            .font(.system(size: 28))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Session")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.fondrPrimary)
                        Text("\(sessionService.mySwipeCount(in: session)) of \(session.itemIds.count) swiped")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "play.fill")
                        .foregroundStyle(.fondrPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(ListCardButtonStyle())
        .padding(.horizontal)
    }

    // MARK: - List Launch Card

    private func listLaunchCard(list: SharedList) -> some View {
        let listId = list.id ?? ""
        let suggestedCount = listService.items.filter { $0.listId == listId && $0.status == .suggested }.count
        let isEnabled = suggestedCount >= 3

        return Button {
            guard isEnabled else { return }
            if sessionService.activeSession != nil {
                pendingListId = list.id
                showExistingSessionPrompt = true
            } else {
                startSession(listId: listId)
            }
        } label: {
            launchCardLabel(list: list, suggestedCount: suggestedCount, isEnabled: isEnabled)
        }
        .buttonStyle(ListCardButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal)
    }

    private func launchCardLabel(list: SharedList, suggestedCount: Int, isEnabled: Bool) -> some View {
        let subtitle: String = isEnabled ? "\(suggestedCount) ideas to swipe through" : "Need at least 3 items"
        let subtitleColor: Color = isEnabled ? .secondary : .red

        return FondrCard {
            HStack(spacing: 14) {
                Text(list.emoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(subtitleColor)
                }

                Spacer()

                if isEnabled {
                    Image(systemName: "hand.tap.fill")
                        .font(.title3)
                        .foregroundStyle(.fondrPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    }

    // MARK: - Actions

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
                }
            }
        }
    }
}
