import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if !appState.isAuthenticated {
                SignInView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else if !appState.isPaired {
                CreatePairView()
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
        .onChange(of: appState.pairService.currentPair?.id) { _, _ in
            appState.setupVaultListener()
        }
    }
}
