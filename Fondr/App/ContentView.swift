import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: appState.ourStoryService.significantDates) { _, _ in
            scheduleReminders()
        }
        .onChange(of: appState.calendarService.events) { _, _ in
            scheduleReminders()
        }
        .onChange(of: appState.authService.appUser?.partnerUid) { _, _ in
            appState.setupCalendarListener()
            appState.setupNotificationListener()
            appState.fetchPartnerDisplayName()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appState.isAuthenticated {
                // Reconnect WebSocket and reload state on foreground
                WebSocketManager.shared.reconnect()
                Task {
                    await appState.authService.loadCurrentUser()
                    if let pairId = appState.pairService.currentPair?.id {
                        appState.setupListListener()
                        appState.setupCalendarListener()
                        appState.setupOurStoryListener()
                        appState.setupSessionListener()
                    }
                }
            }
        }
    }

    private func scheduleReminders() {
        appState.notificationService.scheduleReminders(
            significantDates: appState.ourStoryService.significantDates,
            calendarEvents: appState.calendarService.events,
            anniversary: appState.pairService.currentPair?.anniversary
        )
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
