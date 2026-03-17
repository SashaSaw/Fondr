import SwiftUI

struct JoinPairView: View {
    @Environment(PairService.self) private var pairService
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("🔑")
                    .font(.system(size: 56))

                Text("Enter Invite Code")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("Ask your partner for their 6-character code")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("ABC123", text: $code)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.prefix(Constants.Pairing.codeLength)).uppercased()
                    }

                FondrButton("Join Partner") {
                    pairService.joinPair(inviteCode: code)
                }
                .disabled(code.count != Constants.Pairing.codeLength)
                .opacity(code.count == Constants.Pairing.codeLength ? 1 : 0.6)

                if let error = pairService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .disabled(pairService.isLoading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
