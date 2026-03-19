import SwiftUI
import PhotosUI
import FirebaseFirestore

struct CoupleProfileHeader: View {
    @Environment(ProfileImageService.self) private var profileImageService
    let yourName: String
    let partnerName: String
    let yourImageUrl: String?
    @Binding var partnerImageUrl: String?
    let partnerUid: String?
    var onImageUploaded: (String) -> Void

    @State private var selectedItem: PhotosPickerItem?

    private let circleSize: CGFloat = 90
    private let overlap: CGFloat = 20

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Your photo — left
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    profileCircle(url: yourImageUrl, tint: .fondrSecondary)
                        .offset(x: -((circleSize - overlap) / 2))
                }

                // Partner photo — right
                profileCircle(url: partnerImageUrl, tint: .fondrPartner)
                    .offset(x: (circleSize - overlap) / 2)
            }
            .frame(height: circleSize + 6)

            Text("\(yourName) & \(partnerName)")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)

            if profileImageService.isUploading {
                ProgressView("Uploading...")
                    .font(.caption)
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleImageSelection(newItem) }
        }
        .task {
            await fetchPartnerImage()
        }
    }

    @ViewBuilder
    private func profileCircle(url: String?, tint: Color) -> some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderIcon(tint: tint)
                    }
                }
            } else {
                placeholderIcon(tint: tint)
            }
        }
        .frame(width: circleSize, height: circleSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func placeholderIcon(tint: Color) -> some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(tint)
            .background(Color(.systemBackground))
            .clipShape(Circle())
    }

    private func handleImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        do {
            let url = try await profileImageService.uploadProfileImage(uiImage)
            await MainActor.run { onImageUploaded(url) }
        } catch {
            await MainActor.run {
                profileImageService.errorMessage = error.localizedDescription
            }
        }
    }

    private func fetchPartnerImage() async {
        guard let partnerUid, partnerImageUrl == nil else { return }
        do {
            let doc = try await Firestore.firestore()
                .collection(Constants.Firestore.usersCollection)
                .document(partnerUid)
                .getDocument()
            let url = doc.data()?["profileImageUrl"] as? String
            await MainActor.run { partnerImageUrl = url }
        } catch {
            // Silently fail — placeholder will show
        }
    }
}
