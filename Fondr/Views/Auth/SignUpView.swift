import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        && email.contains("@") && email.contains(".")
        && password.count >= 6
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Create Account")
                .font(.system(.title, design: .rounded, weight: .bold))

            VStack(spacing: 12) {
                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password (6+ characters)", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            FondrButton("Create Account") {
                authService.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.6)

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .disabled(authService.isLoading)
        .overlay {
            if authService.isLoading {
                ProgressView()
            }
        }
    }
}
