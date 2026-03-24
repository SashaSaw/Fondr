import SwiftUI
import Foundation

struct SwipeSessionView: View {
    let session: SwipeSession
    let items: [ListItem]
    let isWatchList: Bool
    let onDismiss: () -> Void

    @Environment(SessionService.self) private var sessionService
    @Environment(AppState.self) private var appState
    @State private var currentIndex = 0
    @State private var showMatchOverlay = false
    @State private var matchedItemTitle = ""
    @State private var showDiscardConfirmation = false
    @State private var showResults = false
    @State private var selectedMatchId: String?
    @State private var hasChosen = false
    @State private var buttonSwipeDirection: String?

    private var liveSession: SwipeSession {
        sessionService.activeSession ?? session
    }

    private var sortedItems: [ListItem] {
        session.itemIds.compactMap { itemId in
            items.first { $0.id == itemId }
        }
    }

    private var myProgress: Int {
        sessionService.mySwipeCount(in: liveSession)
    }

    private var partnerProgress: Int {
        sessionService.partnerSwipeCount(in: liveSession)
    }

    private var partnerName: String {
        appState.partnerName ?? "Partner"
    }

    private var isFinished: Bool {
        currentIndex >= sortedItems.count
    }

    var body: some View {
        ZStack {
            mainContent
            if showMatchOverlay {
                matchOverlay
            }
        }
        .onAppear {
            currentIndex = myProgress
        }
        .onChange(of: liveSession.status) { _, newValue in
            if newValue == .complete {
                showResults = true
            }
        }
        .onChange(of: liveSession.chosenItemId) { _, newValue in
            if let newValue {
                selectedMatchId = newValue
                hasChosen = true
            }
        }
        .onChange(of: liveSession.matches.count) { oldCount, newCount in
            if newCount > oldCount,
               let lastMatch = liveSession.matches.last,
               let item = items.first(where: { $0.id == lastMatch }) {
                matchedItemTitle = item.title
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showMatchOverlay = true
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
            partnerIndicator

            if showResults || liveSession.status == .complete {
                resultsView
            } else if isFinished {
                waitingView
            } else {
                cardStack
                swipeButtons
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                showDiscardConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.fondrSecondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close session")
            .accessibilityHint("Double-tap to leave or discard this swipe session")

            Spacer()

            Text("\(min(currentIndex + 1, liveSession.itemIds.count)) of \(liveSession.itemIds.count)")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Item \(min(currentIndex + 1, liveSession.itemIds.count)) of \(liveSession.itemIds.count)")

            Spacer()

            // Spacer for symmetry
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .confirmationDialog("Leave session?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard Session", role: .destructive) {
                sessionService.discardSession(sessionId: liveSession.id)
                onDismiss()
            }
            Button("Keep for Later", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text("You can come back to finish later, or discard this session entirely.")
        }
    }

    // MARK: - Partner Indicator

    private var partnerIndicator: some View {
        HStack(spacing: 6) {
            if partnerProgress == 0 {
                Text("\(partnerName) hasn't started yet")
            } else {
                Text("\(partnerName) has swiped \(partnerProgress) of \(liveSession.itemIds.count)")
            }
        }
        .font(.system(.caption, design: .rounded))
        .foregroundStyle(.tertiary)
        .padding(.vertical, 6)
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            // Show next 2 cards behind
            ForEach(Array(sortedItems.enumerated().reversed()), id: \.element.id) { index, item in
                if index >= currentIndex && index <= currentIndex + 2 {
                    let offset = index - currentIndex
                    if offset == 0 {
                        SwipeCardView(
                            item: item,
                            isWatchList: isWatchList,
                            onSwipe: { direction in handleSwipe(direction: direction) },
                            triggerDirection: buttonSwipeDirection
                        )
                        .accessibilityLabel("\(item.title)")
                        .accessibilityHint("Swipe right to say yes, swipe left to skip")
                    } else {
                        cardContent(for: item)
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                            .scaleEffect(1.0 - CGFloat(offset) * 0.05)
                            .offset(y: CGFloat(offset) * 8)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func cardContent(for item: ListItem) -> some View {
        if isWatchList, let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.fondrSecondary.opacity(0.2)
            }
        } else {
            ZStack {
                Color(UIColor.systemBackground)

                LinearGradient(
                    colors: [Color.fondrPrimary.opacity(0.15), Color.fondrSecondary.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(item.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }

    // MARK: - Swipe Buttons

    private var swipeButtons: some View {
        HStack(spacing: 32) {
            Button {
                buttonSwipeDirection = "left"
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "forward")
                        .font(.system(size: 18))
                    Text("Skip")
                        .font(.system(.headline, design: .rounded))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .foregroundStyle(.secondary)
                .overlay(
                    Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                )
            }
            .accessibilityLabel("Skip this idea")

            Button {
                buttonSwipeDirection = "right"
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                    Text("Yes!")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Color.fondrPrimary)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Yes, I like this idea")
        }
        .padding(.bottom, 24)
    }

    // MARK: - Match Overlay

    private var matchOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 72))

                Text("It's a match!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("You both want:")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))

                Text(matchedItemTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.fondrAccent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showMatchOverlay = false
                    }
                } label: {
                    Text("Keep Swiping")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.fondrPrimary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
                .accessibilityLabel("Dismiss match and keep swiping")
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("It's a match! You both want \(matchedItemTitle)")
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("⏳")
                .font(.system(size: 64))
            Text("You're done!")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Waiting for \(partnerName) to finish swiping...")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("\(partnerName) has swiped \(partnerProgress) of \(liveSession.itemIds.count)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)

            Button("Leave for Now") {
                onDismiss()
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(.fondrPrimary)
            .padding(.top, 8)
            .accessibilityHint("You'll be notified when your partner finishes")
            Spacer()
        }
        .padding()
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if liveSession.matches.isEmpty {
                    noMatchesView
                } else if hasChosen || liveSession.chosenItemId != nil {
                    chosenView
                } else {
                    pickMatchView
                }
            }
            .padding()
            .padding(.top, 20)
        }
    }

    private var noMatchesView: some View {
        VStack(spacing: 16) {
            Text("🤷")
                .font(.system(size: 64))
            Text("No matches this time")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Try adding more ideas and swiping again!")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    restartSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Start Over")
                    }
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .foregroundStyle(.fondrPrimary)
                    .overlay(
                        Capsule().strokeBorder(Color.fondrPrimary, lineWidth: 1.5)
                    )
                }

                FondrButton("Done") {
                    onDismiss()
                }
            }
            .padding(.top, 12)
        }
    }

    private var pickMatchView: some View {
        VStack(spacing: 20) {
            Text("✨")
                .font(.system(size: 64))
            Text("\(liveSession.matches.count) Match\(liveSession.matches.count == 1 ? "" : "es")!")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Pick the one you want to go with:")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)

            ForEach(liveSession.matches, id: \.self) { matchId in
                if let item = items.first(where: { $0.id == matchId }) {
                    Button {
                        HapticManager.shared.selection()
                        selectedMatchId = matchId
                    } label: {
                        HStack(spacing: 12) {
                            Text("✨")
                            Text(item.title)
                                .font(.system(.headline, design: .rounded))
                            Spacer()
                            if selectedMatchId == matchId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.fondrPrimary)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(
                            selectedMatchId == matchId
                                ? Color.fondrPrimary.opacity(0.15)
                                : Color.fondrAccent.opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    selectedMatchId == matchId ? Color.fondrPrimary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(item.title)")
                    .accessibilityAddTraits(selectedMatchId == matchId ? .isSelected : [])
                }
            }

            if let selectedId = selectedMatchId {
                FondrButton("Confirm Pick") {
                    confirmChoice(itemId: selectedId)
                }
                .padding(.top, 8)
            }

            Button {
                restartSession()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Not feeling any of these? Start Over")
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var chosenView: some View {
        VStack(spacing: 16) {
            let chosenId = liveSession.chosenItemId ?? selectedMatchId
            let chosenItem = items.first(where: { $0.id == chosenId })

            Text("🎉")
                .font(.system(size: 64))

            Text("You picked it!")
                .font(.system(.title, design: .rounded, weight: .bold))

            if let item = chosenItem {
                Text(item.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.fondrPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Head to your Lists tab to see your pick and mark it as done when you're finished!")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            FondrButton("Got it") {
                onDismiss()
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Result Actions

    private func confirmChoice(itemId: String) {
        let sessionId = liveSession.id
        sessionService.chooseMatch(
            sessionId: sessionId,
            chosenItemId: itemId,
            allMatchIds: liveSession.matches
        )
        HapticManager.shared.success()
        withAnimation(.spring(response: 0.4)) {
            hasChosen = true
        }
    }

    private func restartSession() {
        let sessionId = liveSession.id
        // Revert all matches back to suggested before discarding
        for matchId in liveSession.matches {
            Task {
                await revertItemStatus(itemId: matchId)
            }
        }
        sessionService.discardSession(sessionId: sessionId)
        onDismiss()
    }

    private func revertItemStatus(itemId: String) async {
        guard let pairId = appState.pairService.currentPair?.id else { return }
        let body = ItemStatusUpdate(status: ItemStatus.suggested.rawValue)
        let _: ListItem? = try? await APIClient.shared.patch("/pairs/\(pairId)/items/\(itemId)", body: body)
    }

    // MARK: - Actions

    private func handleSwipe(direction: String) {
        guard currentIndex < sortedItems.count else { return }
        let sessionId = liveSession.id

        let currentItem = sortedItems[currentIndex]
        let itemId = currentItem.id
        let previousIndex = currentIndex

        currentIndex += 1  // optimistic
        buttonSwipeDirection = nil

        Task {
            do {
                let _ = try await sessionService.submitSwipe(
                    sessionId: sessionId, itemId: itemId, direction: direction
                )
            } catch {
                await MainActor.run {
                    currentIndex = previousIndex
                    HapticManager.shared.error()
                }
            }
        }
    }
}
