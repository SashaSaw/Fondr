import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send APNs device token to our backend
        // AuthService will be available since it's initialized in AppState
        // We defer this to when the app state is set up
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            let body = APNsTokenRequest(token: tokenString)
            try? await APIClient.shared.post("/users/me/apns-token", body: body) as SuccessResponse
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(userInfo: userInfo)
        completionHandler()
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        let tab: Int
        switch type {
        case "ourStory", "vault":
            tab = 0
        case "listItem":
            tab = 1
        case "session", "match":
            tab = 2
        case "availability", "event":
            tab = 3
        default:
            tab = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .switchToTab, object: tab)
        }
    }
}

private struct APNsTokenRequest: Encodable {
    let token: String
}

@main
struct FondrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(appState.authService)
                .environment(appState.pairService)
                .environment(appState.ourStoryService)
                .environment(appState.profileImageService)
                .environment(appState.listService)
                .environment(appState.sessionService)
                .environment(appState.calendarService)
                .onAppear {
                    appState.authService.start()
                }
        }
    }
}
