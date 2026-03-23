import SwiftUI
import Foundation

struct OnboardingView: View {
    @Environment(AuthService.self) private var authService

    @State private var step = 0
    @State private var displayName = ""
    @State private var partnerName = ""
    @State private var selectedTimezone: String = TimeZone.current.identifier
    @State private var isSaving = false

    private let timezones = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        VStack(spacing: 24) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index <= step ? Color.fondrPrimary : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)

            TabView(selection: $step) {
                // Step 1: Display Name
                stepView(
                    emoji: "👋",
                    title: "What should we call you?",
                    subtitle: "Your partner will see this name"
                ) {
                    TextField("Your name", text: $displayName)
                        .textContentType(.name)
                        .font(.system(.title3, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .tag(0)

                // Step 2: Partner's Name
                stepView(
                    emoji: "💕",
                    title: "What's your partner's name?",
                    subtitle: "We'll use this to personalize your experience"
                ) {
                    TextField("Partner's name", text: $partnerName)
                        .font(.system(.title3, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .tag(1)

                // Step 3: Timezone
                stepView(
                    emoji: "🌍",
                    title: "Your timezone",
                    subtitle: "Helps us show your partner's local time"
                ) {
                    Picker("Timezone", selection: $selectedTimezone) {
                        ForEach(timezones, id: \.self) { tz in
                            Text(tz.replacingOccurrences(of: "_", with: " "))
                                .tag(tz)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            Spacer()

            if step < 2 {
                FondrButton("Continue") {
                    withAnimation { step += 1 }
                }
                .disabled(step == 0 && displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(step == 0 && displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            } else {
                FondrButton("Get Started") {
                    saveOnboarding()
                }
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            displayName = authService.appUser?.displayName ?? ""
        }
    }

    private func stepView<Content: View>(
        emoji: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(emoji)
                .font(.system(size: 56))
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            content()
            Spacer()
        }
    }

    private func saveOnboarding() {
        guard !isSaving else { return }
        isSaving = true

        let updates: [String: Any] = [
            "displayName": displayName.trimmingCharacters(in: .whitespaces),
            "partnerName": partnerName.trimmingCharacters(in: .whitespaces),
            "timezone": selectedTimezone,
            "onboardingCompleted": true
        ]

        Task {
            do {
                let body = UserUpdateBody(updates)
                let _: AppUser = try await APIClient.shared.patch("/users/me", body: body)
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}
