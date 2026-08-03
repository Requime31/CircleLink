import UIKit

/// Message image attachment with reuse-safe remote loading.
final class MessageImageAttachmentView: UIImageView {
    private var imageLoadTask: Task<Void, Never>?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        contentMode = .scaleAspectFill
        clipsToBounds = true
        layer.cornerRadius = ChatAppearance.bubbleImageRadius
        layer.cornerCurve = .continuous
        isHidden = true
        accessibilityIgnoresInvertColors = true

        // Keep media from being crushed by the timestamp’s intrinsic width.
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)

        let height = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint = height
        height.isActive = true

        let width = widthAnchor.constraint(equalToConstant: ChatAppearance.bubbleImageWidth)
        widthConstraint = width
        width.isActive = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        imageLoadTask?.cancel()
        imageLoadTask = nil
        image = nil
        applyImageSizeConstraints(isVisible: false)
    }

    func configure(localImageData: Data?, imageURL: URL?) {
        imageLoadTask?.cancel()
        imageLoadTask = nil

        if let localData = localImageData,
           let image = UIImage(data: localData, scale: UIScreen.main.scale) {
            self.image = image
            applyImageSizeConstraints(isVisible: true)
            return
        }

        if let url = imageURL {
            applyImageSizeConstraints(isVisible: true)
            imageLoadTask = Task { [weak self] in
                guard let self else { return }
                let image = try? await ImageLoader.shared.load(from: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.image = image
                }
            }
            return
        }

        image = nil
        applyImageSizeConstraints(isVisible: false)
    }

    /// Explicit width+height for media — without width, Auto Layout collapses the bubble
    /// to the timestamp intrinsic size (thin vertical strip).
    private func applyImageSizeConstraints(isVisible: Bool) {
        isHidden = !isVisible
        if isVisible {
            heightConstraint?.constant = ChatAppearance.bubbleImageHeight
            widthConstraint?.constant = ChatAppearance.bubbleImageWidth
            widthConstraint?.isActive = true
        } else {
            heightConstraint?.constant = 0
            widthConstraint?.isActive = false
        }
    }
}
