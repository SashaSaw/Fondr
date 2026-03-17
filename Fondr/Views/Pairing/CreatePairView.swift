import SwiftUI

struct CreatePairView: View {
    @Environment(PairService.self) private var pairService
    @State private var showJoinView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let pair = pairService.currentPair, pair.status == .pending {
                    // Waiting for partner
                    VStack(spacing: 16) {
                        Text("🔗")
                            .font(.system(size: 56))

                        Text("Share this code with your partner")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .multilineTextAlignment(.center)

                        Text(pair.inviteCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .tracking(6)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        HStack(spacing: 16) {
                            Button {
                                UIPasteboard.general.string = pair.inviteCode
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.system(.body, design: .rounded))
                            }

                            ShareLink(item: "Join me on Fondr! Use code: \(pair.inviteCode)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(.body, design: .rounded))
                            }
                        }
                        .foregroundStyle(.fondrPrimary)

                        ProgressView("Waiting for your partner...")
                            .padding(.top, 8)
                    }

                    FondrButton("Back", variant: .outlined) {
                        pairService.cancelPair()
                    }
                } else {
                    // Create or join
                    VStack(spacing: 16) {
                        Text("💑")
                            .font(.system(size: 56))

                        Text("Connect with your partner")
                            .font(.system(.title2, design: .rounded, weight: .bold))

                        Text("Create an invite or enter a code to pair up")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    FondrButton("Create Invite Code") {
                        pairService.createPair()
                    }

                    FondrButton("I have a code", variant: .outlined) {
                        showJoinView = true
                    }
                }

                Spacer()

                if let error = pairService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .disabled(pairService.isLoading)
            .sheet(isPresented: $showJoinView) {
                JoinPairView()
            }
        }
    }
}
