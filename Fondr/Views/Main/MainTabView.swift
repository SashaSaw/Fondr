import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Vault", systemImage: "lock.shield") {
                VaultView()
            }

            Tab("Lists", systemImage: "list.bullet.rectangle") {
                EmptyStateView(
                    emoji: "📝",
                    title: "Shared Lists",
                    subtitle: "Plan dates, bucket lists, and more"
                )
            }

            Tab("Swipe", systemImage: "hand.tap") {
                EmptyStateView(
                    emoji: "🍿",
                    title: "Swipe Together",
                    subtitle: "Find movies, restaurants, and activities you both love"
                )
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
