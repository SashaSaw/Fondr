import SwiftUI
import Foundation

struct OnboardingView: View {
    @Environment(AuthService.self) private var authService

    @State private var displayName = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("👋")
                .font(.system(size: 56))
            Text("What should we call you?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Your partner will see this name")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your name", text: $displayName)
                .textContentType(.name)
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            FondrButton("Get Started") {
                saveOnboarding()
            }
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
        }
        .padding(.horizontal, 24)
        .onAppear {
            displayName = authService.appUser?.displayName ?? ""
        }
    }

    private func saveOnboarding() {
        guard !isSaving else { return }
        isSaving = true

        let updates: [String: Any] = [
            "displayName": displayName.trimmingCharacters(in: .whitespaces),
            "timezone": TimeZone.current.identifier,
            "onboardingCompleted": true
        ]

        Task {
            do {
                let body = UserUpdateBody(updates)
                let updated: AppUser = try await APIClient.shared.patch("/users/me", body: body)
                await MainActor.run {
                    authService.appUser = updated
                }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}
