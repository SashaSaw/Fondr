import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@Observable
final class ProfileImageService {
    var isUploading = false
    var errorMessage: String?

    private var db: Firestore { Firestore.firestore() }

    func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw URLError(.userAuthenticationRequired)
        }

        await MainActor.run { isUploading = true }
        defer { Task { @MainActor in isUploading = false } }

        // Resize
        let maxDim = Constants.OurStory.maxImageDimension
        let resized = resizeImage(image, maxDimension: maxDim)

        guard let data = resized.jpegData(compressionQuality: Constants.OurStory.jpegCompression) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Upload to Firebase Storage
        let storageRef = Storage.storage().reference().child("users/\(uid)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString

        // Update Firestore user doc
        try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .updateData(["profileImageUrl": urlString])

        return urlString
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
