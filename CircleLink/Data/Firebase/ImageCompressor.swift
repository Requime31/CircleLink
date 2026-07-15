import UIKit

enum ImageCompressor {
    private static let maxDimension: CGFloat = 256
    private static let jpegQuality: CGFloat = 0.55
    private static let maxBytes = 120_000

    /// Downscales and JPEG-compresses image data for Firestore avatar storage.
    static func compressForAvatar(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw ImageCompressorError.invalidImageData
        }

        let resized = resize(image, maxDimension: maxDimension)
        guard let compressed = resized.jpegData(compressionQuality: jpegQuality) else {
            throw ImageCompressorError.compressionFailed
        }

        guard compressed.count <= maxBytes else {
            throw ImageCompressorError.tooLarge
        }

        return compressed
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum ImageCompressorError: LocalizedError {
    case invalidImageData
    case compressionFailed
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Selected image could not be processed."
        case .compressionFailed:
            return "Failed to compress image for upload."
        case .tooLarge:
            return "Image is too large after compression. Try a smaller photo."
        }
    }
}
