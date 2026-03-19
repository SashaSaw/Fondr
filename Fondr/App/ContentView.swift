import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var dismissedEventRequests = false

    private var hasPendingRequests: Bool {
        !appState.calendarService.pendingPartnerEvents.isEmpty
    }

    var body: some View {
        Group {
            if !appState.isAuthenticated {
                SignInView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else if !appState.isPaired {
                CreatePairView()
            } else if hasPendingRequests && !dismissedEventRequests {
                EventRequestView {
                    dismissedEventRequests = true
                }
                .environment(appState.calendarService)
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.needsOnboarding)
        .animation(.easeInOut, value: appState.isPaired)
        .onChange(of: appState.authService.appUser?.pairId) { _, _ in
            appState.setupPairListener()
        }
        .onChange(of: appState.calendarService.pendingPartnerEvents.count) { oldCount, newCount in
            // Reset dismissal if new requests arrive
            if newCount > 0 && oldCount == 0 {
                dismissedEventRequests = false
            }
        }
        .onChange(of: appState.pairService.currentPair?.id) { oldValue, newValue in
            appState.setupOurStoryListener()
            appState.setupListListener()
            appState.setupSessionListener()
            appState.setupCalendarListener()
            appState.setupNotificationListener()

            // Pair was removed (either we left or partner left)
            if oldValue != nil && newValue == nil {
                appState.handlePairRemoved()
            }

            // Request notification permissions after pairing
            if oldValue == nil && newValue != nil {
                requestNotificationPermissions()
            }
        }
        .onChange(of: appState.authService.appUser?.partnerUid) { _, _ in
            // partnerUid may arrive after the pair listener fires;
            // re-trigger calendar & notification listeners that depend on it
            appState.setupCalendarListener()
            appState.setupNotificationListener()
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
