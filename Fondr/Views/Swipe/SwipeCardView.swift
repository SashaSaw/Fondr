import SwiftUI

struct SwipeCardView: View {
    let item: ListItem
    let isWatchList: Bool
    let onSwipe: (String) -> Void
    var triggerDirection: String? = nil

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    private let swipeThreshold: CGFloat = 150

    private var rotation: Double {
        Double(offset.width) / 20
    }

    private var swipeProgress: CGFloat {
        min(abs(offset.width) / swipeThreshold, 1.0)
    }

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .overlay {
                if offset.width > 0 {
                    rightOverlay
                } else if offset.width < 0 {
                    leftOverlay
                }
            }
            .rotationEffect(.degrees(rotation))
            .offset(x: offset.width)
            .gesture(dragGesture)
            .onChange(of: triggerDirection) { _, direction in
                guard let direction else { return }
                animateOffScreen(direction: direction)
            }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        if isWatchList, let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
            watchCard(url: url)
        } else {
            dateIdeaCard
        }
    }

    private func watchCard(url: URL) -> some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.fondrSecondary.opacity(0.2)
                    .overlay {
                        ProgressView()
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                if let meta = item.metadata {
                    HStack(spacing: 8) {
                        if let year = meta.year, !year.isEmpty {
                            Text(year)
                        }
                        if let genre = meta.genre, !genre.isEmpty {
                            Text("·")
                            Text(genre)
                        }
                        if let rating = meta.rating {
                            Text("·")
                            Text(String(format: "%.1f ★", rating))
                        }
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dateIdeaCard: some View {
        ZStack {
            Color(UIColor.systemBackground)

            LinearGradient(
                colors: [Color.fondrPrimary.opacity(0.15), Color.fondrSecondary.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Spacer()
                Text(item.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Overlays

    private var rightOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.green.opacity(0.2 * swipeProgress))
            .overlay(alignment: .topLeading) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                    Text("Yes!")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.green)
                .opacity(swipeProgress)
                .padding(24)
            }
    }

    private var leftOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.secondary.opacity(0.15 * swipeProgress))
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: "forward")
                        .font(.system(size: 28, weight: .medium))
                    Text("Skip")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .opacity(swipeProgress)
                .padding(24)
            }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
                isDragging = true
            }
            .onEnded { value in
                isDragging = false
                if value.translation.width > swipeThreshold {
                    animateOffScreen(direction: "right")
                } else if value.translation.width < -swipeThreshold {
                    animateOffScreen(direction: "left")
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
            }
    }

    private func animateOffScreen(direction: String) {
        let xOffset: CGFloat = direction == "right" ? 500 : -500
        if direction == "right" {
            HapticManager.shared.medium()
        } else {
            HapticManager.shared.light()
        }
        withAnimation(.easeOut(duration: 0.3)) {
            offset.width = xOffset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(direction)
            offset = .zero
        }
    }
}
