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
        print("[ProfileImage] Resizing image...")
        let maxDim = Constants.OurStory.maxImageDimension
        let resized = resizeImage(image, maxDimension: maxDim)
        print("[ProfileImage] Resized to \(resized.size)")

        print("[ProfileImage] Compressing to JPEG...")
        guard let data = resized.jpegData(compressionQuality: Constants.OurStory.jpegCompression) else {
            print("[ProfileImage] ERROR: Failed to compress image to JPEG")
            throw URLError(.cannotDecodeContentData)
        }
        print("[ProfileImage] Compressed size: \(data.count) bytes")

        // Upload to Firebase Storage
        let storageRef = Storage.storage().reference().child("users/\(uid)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        print("[ProfileImage] Uploading to Firebase Storage...")
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        print("[ProfileImage] Upload complete. Getting download URL...")

        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString
        print("[ProfileImage] Download URL: \(urlString)")

        // Update Firestore user doc
        print("[ProfileImage] Updating Firestore user doc...")
        try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .updateData(["profileImageUrl": urlString])
        print("[ProfileImage] Firestore updated successfully")

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
