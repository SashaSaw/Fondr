import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Vault", systemImage: "lock.shield", value: 0) {
                VaultView()
            }

            Tab("Lists", systemImage: "list.bullet.rectangle", value: 1) {
                SharedListsView()
            }

            Tab("Swipe", systemImage: "hand.tap", value: 2) {
                SwipeTabView()
            }

            Tab("Calendar", systemImage: "calendar", value: 3) {
                SharedCalendarView()
            }

            Tab("Settings", systemImage: "gearshape", value: 4) {
                SettingsView()
            }
        }
        .tint(.fondrPrimary)
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notification in
            if let tab = notification.object as? Int {
                selectedTab = tab
            }
        }
    }
}
