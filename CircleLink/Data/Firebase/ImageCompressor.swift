import UIKit

enum ImageCompressor {
    private static let avatarMaxDimension: CGFloat = 256
    private static let avatarJpegQuality: CGFloat = 0.55
    private static let avatarMaxBytes = 120_000

    private static let chatMaxDimension: CGFloat = 1_200
    private static let chatJpegQuality: CGFloat = 0.7
    private static let chatMaxBytes = 500_000

    /// Downscales and JPEG-compresses image data for Firestore avatar storage.
    static func compressForAvatar(_ data: Data) throws -> Data {
        try compress(
            data,
            maxDimension: avatarMaxDimension,
            jpegQuality: avatarJpegQuality,
            maxBytes: avatarMaxBytes
        )
    }

    /// Downscales and JPEG-compresses image data for chat attachments.
    static func compressForChat(_ data: Data) throws -> Data {
        try compress(
            data,
            maxDimension: chatMaxDimension,
            jpegQuality: chatJpegQuality,
            maxBytes: chatMaxBytes
        )
    }

    /// Downscales and JPEG-compresses a picked `UIImage` (handles HDR / HEIC).
    static func compressForChat(_ image: UIImage) throws -> Data {
        try encodeJPEG(
            image: image,
            maxDimension: chatMaxDimension,
            jpegQuality: chatJpegQuality,
            maxBytes: chatMaxBytes
        )
    }

    private static func compress(
        _ data: Data,
        maxDimension: CGFloat,
        jpegQuality: CGFloat,
        maxBytes: Int
    ) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw ImageCompressorError.invalidImageData
        }

        return try encodeJPEG(
            image: image,
            maxDimension: maxDimension,
            jpegQuality: jpegQuality,
            maxBytes: maxBytes
        )
    }

    private static func encodeJPEG(
        image: UIImage,
        maxDimension: CGFloat,
        jpegQuality: CGFloat,
        maxBytes: Int
    ) throws -> Data {
        let prepared = prepareForJPEG(image, maxDimension: maxDimension)
        guard let compressed = prepared.jpegData(compressionQuality: jpegQuality) else {
            throw ImageCompressorError.compressionFailed
        }

        guard compressed.count <= maxBytes else {
            throw ImageCompressorError.tooLarge
        }

        return compressed
    }

    /// Flattens HDR/extended-range photos into a standard bitmap before JPEG encoding.
    private static func prepareForJPEG(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        if #available(iOS 17.0, *) {
            format.preferredRange = .standard
        }

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
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
