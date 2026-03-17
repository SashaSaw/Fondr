import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Vault", systemImage: "lock.shield") {
                VaultView()
            }

            Tab("Lists", systemImage: "list.bullet.rectangle") {
                SharedListsView()
            }

            Tab("Swipe", systemImage: "hand.tap") {
                SwipeTabView()
            }

            Tab("Calendar", systemImage: "calendar") {
                EmptyStateView(
                    emoji: "📅",
                    title: "Shared Calendar",
                    subtitle: "Countdowns, visits, and important dates"
                )
            }
        }
        .tint(.fondrPrimary)
    }
}
