import UIKit

final class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"

    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = ChatAppearance.bodyFont
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let imageAttachmentView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.isHidden = true
        imageView.accessibilityIgnoresInvertColors = true
        return imageView
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ChatAppearance.captionFont
        label.adjustsFontForContentSizeCategory = true
        label.textColor = ChatAppearance.muted
        return label
    }()

    private let statusIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
        button.tintColor = ChatAppearance.primary
        button.isHidden = true
        button.accessibilityLabel = "Retry sending message"
        return button
    }()

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    private var onRetry: (() -> Void)?
    private var imageLoadTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        setupLayout()
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        imageAttachmentView.image = nil
        imageAttachmentView.isHidden = true
        messageLabel.text = nil
        messageLabel.isHidden = false
        statusIndicator.stopAnimating()
        retryButton.isHidden = true
        onRetry = nil
    }

    func configure(with item: ChatMessageItem, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry

        let timeText = item.createdAt.formatted(date: .omitted, time: .shortened)
        timestampLabel.text = timeText

        if let text = item.text, !text.isEmpty {
            messageLabel.text = text
            messageLabel.isHidden = false
        } else {
            messageLabel.text = nil
            messageLabel.isHidden = true
        }

        configureImage(for: item)
        configureBubbleStyle(isOutgoing: item.isOutgoing)
        configureStatus(item.status, isOutgoing: item.isOutgoing)

        let spokenText = item.text ?? (item.imageURL != nil || item.localImageData != nil ? "Image attachment" : "")
        isAccessibilityElement = true
        accessibilityLabel = "\(item.senderLabel). \(spokenText). \(timeText)"
        if item.status == .failed && item.isOutgoing {
            accessibilityTraits = [.button]
            accessibilityHint = "Double tap to retry sending"
        } else {
            accessibilityTraits = .staticText
        }
    }

    override func accessibilityActivate() -> Bool {
        if retryButton.isHidden == false {
            retryTapped()
            return true
        }
        return false
    }

    private func configureImage(for item: ChatMessageItem) {
        imageLoadTask?.cancel()

        if let localData = item.localImageData,
           let image = UIImage(data: localData, scale: UIScreen.main.scale) {
            imageAttachmentView.image = image
            imageAttachmentView.isHidden = false
            imageHeightConstraint?.constant = 180
            return
        }

        if let url = item.imageURL {
            imageAttachmentView.isHidden = false
            imageHeightConstraint?.constant = 180
            imageLoadTask = Task { [weak self] in
                guard let self else { return }
                let image = try? await ImageLoader.shared.load(from: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.imageAttachmentView.image = image
                }
            }
            return
        }

        imageAttachmentView.image = nil
        imageAttachmentView.isHidden = true
        imageHeightConstraint?.constant = 0
    }

    private func configureBubbleStyle(isOutgoing: Bool) {
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false

        if isOutgoing {
            bubbleView.backgroundColor = ChatAppearance.outgoingBubble
            messageLabel.textColor = .white
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: 64
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            )
        } else {
            bubbleView.backgroundColor = ChatAppearance.incomingBubble
            messageLabel.textColor = ChatAppearance.ink
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -64
            )
        }

        leadingConstraint?.isActive = true
        trailingConstraint?.isActive = true
    }

    private func configureStatus(_ status: MessageStatus, isOutgoing: Bool) {
        guard isOutgoing else {
            statusIndicator.stopAnimating()
            retryButton.isHidden = true
            return
        }

        switch status {
        case .sending:
            statusIndicator.startAnimating()
            retryButton.isHidden = true
        case .sent:
            statusIndicator.stopAnimating()
            retryButton.isHidden = true
        case .failed:
            statusIndicator.stopAnimating()
            retryButton.isHidden = false
        }
    }

    private func setupLayout() {
        contentView.addSubview(bubbleView)
        contentView.addSubview(statusIndicator)
        contentView.addSubview(retryButton)

        bubbleView.addSubview(imageAttachmentView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(timestampLabel)

        imageHeightConstraint = imageAttachmentView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            imageAttachmentView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            imageAttachmentView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            imageAttachmentView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            imageHeightConstraint!,

            messageLabel.topAnchor.constraint(equalTo: imageAttachmentView.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            timestampLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            timestampLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),

            statusIndicator.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            statusIndicator.trailingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: -8),

            retryButton.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            retryButton.trailingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: -8),
            retryButton.widthAnchor.constraint(equalToConstant: 28),
            retryButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}
