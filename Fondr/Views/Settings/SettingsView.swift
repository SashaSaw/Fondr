import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var unpairText = ""
    @State private var deleteText = ""
    @State private var editingName = false
    @State private var nameField = ""
    @State private var notificationsEnabled = true

    private var appUser: AppUser? { appState.authService.appUser }

    private var pairedSinceText: String? {
        guard let pair = appState.pairService.currentPair else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: pair.createdAt)
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                partnerSection
                notificationsSection
                aboutSection
                signOutSection
                dangerSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            if editingName {
                HStack {
                    TextField("Display Name", text: $nameField)
                        .textInputAutocapitalization(.words)
                        .onSubmit { saveName() }
                    Button("Save") { saveName() }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.fondrPrimary)
                }
            } else {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(appUser?.displayName ?? "—")
                        .foregroundStyle(.secondary)
                    Button {
                        nameField = appUser?.displayName ?? ""
                        editingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.fondrPrimary)
                    }
                    .accessibilityLabel("Edit display name")
                }
            }

            if let email = appUser?.email, !email.isEmpty {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(email)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Timezone", selection: Binding(
                get: { appUser?.timezone ?? TimeZone.current.identifier },
                set: { newValue in
                    appState.authService.updateUserDoc(["timezone": newValue])
                }
            )) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { tz in
                    Text(tz.replacingOccurrences(of: "_", with: " "))
                        .tag(tz)
                }
            }
            .accessibilityLabel("Select your timezone")
        } header: {
            Text("Profile")
        }
    }

    // MARK: - Partner

    private var partnerSection: some View {
        Section {
            if let partner = appState.partnerName {
                HStack {
                    Text("Connected to")
                    Spacer()
                    Text(partner)
                        .foregroundStyle(.fondrPrimary)
                        .fontWeight(.medium)
                }
            }
            if let since = pairedSinceText {
                HStack {
                    Text("Paired since")
                    Spacer()
                    Text(since)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Partner")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle("Push Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        requestNotifications()
                    }
                }
        } header: {
            Text("Notifications")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button {
                HapticManager.shared.light()
                appState.authService.signOut()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "person.slash")
                    Text("Leave Partnership")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Account")
                }
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Leaving a partnership ends it for both partners. Deleting your account permanently removes all your data.")
        }
        .alert("Leave Partnership", isPresented: $showLeaveConfirmation) {
            TextField("Type UNPAIR to confirm", text: $unpairText)
                .textInputAutocapitalization(.characters)
            Button("Leave", role: .destructive) {
                guard unpairText.uppercased() == "UNPAIR" else { return }
                HapticManager.shared.heavy()
                appState.leavePartnership()
                unpairText = ""
            }
            Button("Cancel", role: .cancel) { unpairText = "" }
        } message: {
            Text("This will end the partnership for both partners. Type UNPAIR to confirm.")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteText)
                .textInputAutocapitalization(.characters)
            Button("Delete Forever", role: .destructive) {
                guard deleteText.uppercased() == "DELETE" else { return }
                HapticManager.shared.heavy()
                deleteAccount()
                deleteText = ""
            }
            Button("Cancel", role: .cancel) { deleteText = "" }
        } message: {
            Text("This will permanently delete your account and all associated data. Type DELETE to confirm.")
        }
    }

    // MARK: - Actions

    private func saveName() {
        let trimmed = nameField.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.authService.updateUserDoc(["displayName": trimmed])
        appState.authService.appUser?.displayName = trimmed
        editingName = false
        HapticManager.shared.success()
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await appState.authService.deleteAccount()
            } catch {
                appState.authService.signOut()
            }
        }
    }
}
