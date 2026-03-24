import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthService.self) private var authService

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        @Bindable var auth = authService

        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo area
                VStack(spacing: 8) {
                    Text("💕")
                        .font(.system(size: 64))
                    Text("Fondr")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.fondrPrimary)
                    Text("Distance makes the heart grow with Fondr.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    authService.handleSignInWithAppleRequest(request)
                } onCompletion: { result in
                    authService.handleSignInWithAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)

                dividerRow

                // Email sign in
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    FondrButton("Sign In") {
                        authService.signInWithEmail(email: email, password: password)
                    }
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                NavigationLink {
                    SignUpView()
                } label: {
                    Text("Don't have an account? **Sign Up**")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.fondrPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.fondrBackground)
            .disabled(authService.isLoading)
            .overlay {
                if authService.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private var dividerRow: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Text("or")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
        }
    }
}
