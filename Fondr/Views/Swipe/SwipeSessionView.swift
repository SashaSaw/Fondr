import SwiftUI

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

    private var sortedItems: [ListItem] {
        session.itemIds.compactMap { itemId in
            items.first { $0.id == itemId }
        }
    }

    private var myProgress: Int {
        sessionService.mySwipeCount(in: session)
    }

    private var partnerProgress: Int {
        sessionService.partnerSwipeCount(in: session)
    }

    private var partnerName: String {
        appState.partnerName ?? "Partner"
    }

    private var isFinished: Bool {
        sessionService.hasUserFinished(session: session)
    }

    var body: some View {
        ZStack {
            mainContent
            if showMatchOverlay {
                matchOverlay
            }
        }
        .onChange(of: session.status) { _, newValue in
            if newValue == .complete {
                showResults = true
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
            partnerIndicator

            if showResults || session.status == .complete {
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

            Spacer()

            Text("\(myProgress + 1 > session.itemIds.count ? session.itemIds.count : myProgress + 1) of \(session.itemIds.count)")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            // Spacer for symmetry
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .confirmationDialog("Leave session?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard Session", role: .destructive) {
                if let id = session.id {
                    sessionService.discardSession(sessionId: id)
                }
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
                Text("\(partnerName) has swiped \(partnerProgress) of \(session.itemIds.count)")
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
                if index >= myProgress && index <= myProgress + 2 {
                    let offset = index - myProgress
                    if offset == 0 {
                        SwipeCardView(
                            item: item,
                            isWatchList: isWatchList,
                            onSwipe: { direction in handleSwipe(direction: direction) }
                        )
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
                handleSwipe(direction: "left")
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

            Button {
                handleSwipe(direction: "right")
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
            }
        }
        .transition(.opacity)
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

            Text("\(partnerName) has swiped \(partnerProgress) of \(session.itemIds.count)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)

            Button("Leave for Now") {
                onDismiss()
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(.fondrPrimary)
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if session.matches.isEmpty {
                    Text("🤷")
                        .font(.system(size: 64))
                    Text("No matches this time")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Add more ideas and try again!")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("✨")
                        .font(.system(size: 64))
                    Text("\(session.matches.count) Match\(session.matches.count == 1 ? "" : "es")!")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))

                    ForEach(session.matches, id: \.self) { matchId in
                        if let item = items.first(where: { $0.id == matchId }) {
                            HStack(spacing: 12) {
                                Text("✨")
                                Text(item.title)
                                    .font(.system(.headline, design: .rounded))
                                Spacer()
                            }
                            .padding()
                            .background(Color.fondrAccent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                FondrButton("Done") {
                    onDismiss()
                }
                .padding(.top, 12)
            }
            .padding()
            .padding(.top, 20)
        }
    }

    // MARK: - Actions

    private func handleSwipe(direction: String) {
        guard myProgress < sortedItems.count,
              let sessionId = session.id else { return }

        let currentItem = sortedItems[myProgress]
        guard let itemId = currentItem.id else { return }

        sessionService.submitSwipe(sessionId: sessionId, itemId: itemId, direction: direction)

        // Check if this might cause a match
        let partnerSwipes = sessionService.partnerSwipeCount(in: session) > 0
        if direction == "right" && partnerSwipes {
            // Check partner's swipe on this item
            let pair = appState.pairService.currentPair
            let isUserA = appState.authService.currentUser?.uid == pair?.userA
            let otherSwipes = isUserA ? session.swipesB : session.swipesA
            if otherSwipes[itemId] == "right" {
                matchedItemTitle = currentItem.title
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                withAnimation(.spring(response: 0.4)) {
                    showMatchOverlay = true
                }
            }
        }

        // Advance to next card
        withAnimation(.spring(response: 0.3)) {
            currentIndex = myProgress + 1
        }
    }
}
