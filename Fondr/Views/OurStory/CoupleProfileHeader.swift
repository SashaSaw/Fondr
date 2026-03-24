import SwiftUI
import PhotosUI
import Foundation

struct CoupleProfileHeader: View {
    @Environment(ProfileImageService.self) private var profileImageService
    let yourName: String
    let partnerName: String
    let yourImageUrl: String?
    let partnerImageUrl: String?
    var onImageUploaded: (String) -> Void
    var onImageRemoved: (() -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @State private var localImage: UIImage?
    @State private var showPhotoOptions = false
    @State private var showPhotoPicker = false
    @State private var showUploadError = false

    private let circleSize: CGFloat = 90
    private let overlap: CGFloat = 20

    private var hasPhoto: Bool {
        localImage != nil || yourImageUrl != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Your photo — left
                yourProfileCircle
                    .offset(x: -((circleSize - overlap) / 2))
                    .onTapGesture { showPhotoOptions = true }

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
        .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Choose Photo") { showPhotoPicker = true }
            if hasPhoto {
                Button("Remove Photo", role: .destructive) { removePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await handleImageSelection(newItem) }
        }
        .alert("Upload Failed", isPresented: $showUploadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(profileImageService.errorMessage ?? "Could not upload photo. It will be saved locally until the next attempt.")
        }
    }

    @ViewBuilder
    private var yourProfileCircle: some View {
        Group {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let yourImageUrl, let imageURL = URL(string: yourImageUrl) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderIcon(tint: .fondrSecondary)
                    }
                }
            } else {
                placeholderIcon(tint: .fondrSecondary)
            }
        }
        .frame(width: circleSize, height: circleSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(alignment: .bottomLeading) {
            if !hasPhoto {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.fondrSecondary)
                    .offset(x: -2, y: 2)
            }
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
            .background(Color(.secondarySystemBackground))
            .clipShape(Circle())
    }

    private func handleImageSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        // Show the image immediately
        await MainActor.run { localImage = uiImage }

        do {
            let url = try await profileImageService.uploadProfileImage(uiImage)
            await MainActor.run { onImageUploaded(url) }
        } catch {
            print("[ProfileImage] Upload failed: \(error)")
            await MainActor.run {
                // Keep localImage so the user still sees their photo
                profileImageService.errorMessage = error.localizedDescription
                showUploadError = true
            }
        }
    }

    private func removePhoto() {
        localImage = nil
        selectedItem = nil
        onImageRemoved?()
    }

}
