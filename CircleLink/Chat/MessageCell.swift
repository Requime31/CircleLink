import UIKit

final class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"

    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = ChatAppearance.Radius.bubble
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
        imageView.layer.cornerRadius = ChatAppearance.Radius.image
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
    private var canRetryViaAccessibility = false

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
        canRetryViaAccessibility = false
        accessibilityElements = nil
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

        let spokenText = item.text ?? (item.imageURL != nil || item.localImageData != nil ? "Image attachment" : "Empty message")
        configureVoiceOver(
            senderLabel: item.senderLabel,
            spokenText: spokenText,
            timeText: timeText,
            isFailedOutgoing: item.status == .failed && item.isOutgoing
        )
    }

    override func accessibilityActivate() -> Bool {
        guard canRetryViaAccessibility else { return false }
        retryTapped()
        return true
    }

    /// VoiceOver order: sender → text → time (separate elements, not one combined label).
    private func configureVoiceOver(
        senderLabel: String,
        spokenText: String,
        timeText: String,
        isFailedOutgoing: Bool
    ) {
        isAccessibilityElement = false
        canRetryViaAccessibility = isFailedOutgoing

        let senderElement = UIAccessibilityElement(accessibilityContainer: self)
        senderElement.accessibilityLabel = senderLabel
        senderElement.accessibilityTraits = .staticText

        let textElement = ActivatableAccessibilityElement(accessibilityContainer: self)
        textElement.accessibilityLabel = spokenText
        if isFailedOutgoing {
            textElement.accessibilityTraits = .button
            textElement.accessibilityHint = "Double tap to retry sending"
            textElement.onActivate = { [weak self] in
                self?.retryTapped()
                return true
            }
        } else {
            textElement.accessibilityTraits = .staticText
        }

        let timeElement = UIAccessibilityElement(accessibilityContainer: self)
        timeElement.accessibilityLabel = timeText
        timeElement.accessibilityTraits = .staticText

        // Frames updated in layoutSubviews so VoiceOver hit-testing stays correct.
        accessibilityElements = [senderElement, textElement, timeElement]
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let elements = accessibilityElements as? [UIAccessibilityElement], elements.count == 3 else {
            return
        }

        let bubbleFrame = contentView.convert(bubbleView.bounds, from: bubbleView)
        let third = bubbleFrame.height / 3

        elements[0].accessibilityFrameInContainerSpace = CGRect(
            x: bubbleFrame.minX,
            y: bubbleFrame.minY,
            width: bubbleFrame.width,
            height: max(third, 1)
        )
        elements[1].accessibilityFrameInContainerSpace = CGRect(
            x: bubbleFrame.minX,
            y: bubbleFrame.minY + third,
            width: bubbleFrame.width,
            height: max(third, 1)
        )
        elements[2].accessibilityFrameInContainerSpace = CGRect(
            x: bubbleFrame.minX,
            y: bubbleFrame.minY + 2 * third,
            width: bubbleFrame.width,
            height: max(bubbleFrame.height - 2 * third, 1)
        )
    }

    private func configureImage(for item: ChatMessageItem) {
        imageLoadTask?.cancel()

        if let localData = item.localImageData,
           let image = UIImage(data: localData, scale: UIScreen.main.scale) {
            imageAttachmentView.image = image
            imageAttachmentView.isHidden = false
            imageHeightConstraint?.constant = ChatAppearance.Spacing.imageHeight
            return
        }

        if let url = item.imageURL {
            imageAttachmentView.isHidden = false
            imageHeightConstraint?.constant = ChatAppearance.Spacing.imageHeight
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
            messageLabel.textColor = ChatAppearance.onPrimary
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: ChatAppearance.Spacing.bubbleOppositeInset
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -ChatAppearance.Spacing.bubbleHorizontalInset
            )
        } else {
            bubbleView.backgroundColor = ChatAppearance.incomingBubble
            messageLabel.textColor = ChatAppearance.ink
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChatAppearance.Spacing.bubbleHorizontalInset
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -ChatAppearance.Spacing.bubbleOppositeInset
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
            bubbleView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: ChatAppearance.Spacing.bubbleVertical
            ),
            bubbleView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -ChatAppearance.Spacing.bubbleVertical
            ),

            imageAttachmentView.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: ChatAppearance.Spacing.bubblePaddingV
            ),
            imageAttachmentView.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: ChatAppearance.Spacing.bubblePaddingH
            ),
            imageAttachmentView.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -ChatAppearance.Spacing.bubblePaddingH
            ),
            imageHeightConstraint!,

            messageLabel.topAnchor.constraint(
                equalTo: imageAttachmentView.bottomAnchor,
                constant: ChatAppearance.Spacing.bubblePaddingV
            ),
            messageLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: ChatAppearance.Spacing.bubblePaddingH
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -ChatAppearance.Spacing.bubblePaddingH
            ),

            timestampLabel.topAnchor.constraint(
                equalTo: messageLabel.bottomAnchor,
                constant: ChatAppearance.Spacing.timestampGap
            ),
            timestampLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: ChatAppearance.Spacing.bubblePaddingH
            ),
            timestampLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -ChatAppearance.Spacing.bubblePaddingH
            ),
            timestampLabel.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -ChatAppearance.Spacing.bubblePaddingV
            ),

            statusIndicator.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            statusIndicator.trailingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: -ChatAppearance.Spacing.statusGap
            ),

            retryButton.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            retryButton.trailingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: -ChatAppearance.Spacing.statusGap
            ),
            retryButton.widthAnchor.constraint(equalToConstant: AccessibilityHelpers.minimumTouchTarget),
            retryButton.heightAnchor.constraint(equalToConstant: AccessibilityHelpers.minimumTouchTarget)
        ])
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}

/// UIAccessibilityElement that can handle double-tap activate (retry failed send).
private final class ActivatableAccessibilityElement: UIAccessibilityElement {
    var onActivate: (() -> Bool)?

    override func accessibilityActivate() -> Bool {
        if let onActivate {
            return onActivate()
        }
        return super.accessibilityActivate()
    }
}
