import UIKit

/// Incoming-message sender avatar with reuse-safe remote loading.
final class MessageSenderAvatarView: UIImageView {
    static let avatarSize: CGFloat = 32

    private var avatarLoadTask: Task<Void, Never>?
    private var widthConstraint: NSLayoutConstraint?
    private var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        contentMode = .scaleAspectFill
        clipsToBounds = true
        layer.cornerRadius = Self.avatarSize / 2
        backgroundColor = ChatAppearance.primarySoft
        isUserInteractionEnabled = true
        isHidden = true
        accessibilityIgnoresInvertColors = true

        let width = widthAnchor.constraint(equalToConstant: 0)
        widthConstraint = width
        NSLayoutConstraint.activate([
            width,
            heightAnchor.constraint(equalTo: widthAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        avatarLoadTask?.cancel()
        avatarLoadTask = nil
        image = nil
        isHidden = true
        widthConstraint?.constant = 0
        onTap = nil
    }

    func configure(
        base64: String?,
        url: URL?,
        isVisible: Bool,
        onTap: (() -> Void)?
    ) {
        avatarLoadTask?.cancel()
        avatarLoadTask = nil
        self.onTap = onTap

        guard isVisible else {
            isHidden = true
            image = nil
            widthConstraint?.constant = 0
            return
        }

        isHidden = false
        widthConstraint?.constant = Self.avatarSize
        image = placeholderAvatarImage()

        if let base64,
           let data = Data(base64Encoded: base64),
           let decoded = UIImage(data: data) {
            image = decoded
            return
        }

        if let url {
            avatarLoadTask = Task { [weak self] in
                guard let self else { return }
                let loaded = try? await ImageLoader.shared.load(from: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.image = loaded ?? self.placeholderAvatarImage()
                }
            }
        }
    }

    private func placeholderAvatarImage() -> UIImage? {
        UIImage(systemName: "person.crop.circle.fill")?
            .withTintColor(ChatAppearance.inkMuted, renderingMode: .alwaysOriginal)
    }

    /// VoiceOver / programmatic activate — same path as a user tap.
    func activateTap() {
        onTap?()
    }

    @objc private func avatarTapped() {
        activateTap()
    }
}
