import SwiftUI

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let subtitle: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 64))

            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ctaTitle, let ctaAction {
                FondrButton(ctaTitle, action: ctaAction)
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

#Preview {
    EmptyStateView(
        emoji: "💕",
        title: "Nothing here yet",
        subtitle: "Start adding moments to your vault",
        ctaTitle: "Add First Moment",
        ctaAction: {}
    )
}
