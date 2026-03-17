import SwiftUI

struct ListCardView: View {
    let list: SharedList
    let itemCount: Int
    let matchedCount: Int

    var body: some View {
        FondrCard {
            VStack(spacing: 8) {
                Text(list.emoji)
                    .font(.system(size: 36))

                Text(list.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)

                if matchedCount > 0 {
                    HStack(spacing: 2) {
                        Text("✨")
                            .font(.caption2)
                        Text("\(matchedCount) matched")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(.fondrAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
}

struct ListCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
