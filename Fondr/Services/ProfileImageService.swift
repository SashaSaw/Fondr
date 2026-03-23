import Foundation
import UIKit

@Observable
final class ProfileImageService {
    var isUploading = false
    var errorMessage: String?

    func uploadProfileImage(_ image: UIImage) async throws -> String {
        await MainActor.run { isUploading = true }
        defer { Task { @MainActor in isUploading = false } }

        // Resize
        let maxDim = Constants.OurStory.maxImageDimension
        let resized = resizeImage(image, maxDimension: maxDim)

        guard let data = resized.jpegData(compressionQuality: Constants.OurStory.jpegCompression) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Upload to backend
        let result = try await APIClient.shared.upload("/users/me/profile-image", imageData: data)
        return result["profileImageUrl"] ?? ""
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
