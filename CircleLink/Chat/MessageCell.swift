import UIKit

/// Chat row assembler — owns outer layout, VoiceOver frames, and subview orchestration.
final class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"

    private let avatarImageView = MessageSenderAvatarView(frame: .zero)
    private let bubbleView = MessageBubbleView(frame: .zero)
    private let statusView = MessageSendStatusView(frame: .zero)

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var onRetry: (() -> Void)?
    private var canRetryViaAccessibility = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
        bubbleView.prepareForReuse()
        statusView.prepareForReuse()
        onRetry = nil
        canRetryViaAccessibility = false
        accessibilityElements = nil
    }

    func configure(
        with item: ChatMessageItem,
        onRetry: @escaping () -> Void,
        onAvatarTap: (() -> Void)? = nil
    ) {
        self.onRetry = onRetry
        statusView.onRetry = { [weak self] in
            self?.retryTapped()
        }

        let timeText = item.createdAt.formatted(date: .omitted, time: .shortened)

        avatarImageView.configure(
            base64: item.senderAvatarBase64,
            url: item.senderAvatarURL,
            isVisible: !item.isOutgoing,
            onTap: onAvatarTap
        )
        bubbleView.configure(
            text: item.text,
            timestamp: timeText,
            isOutgoing: item.isOutgoing,
            localImageData: item.localImageData,
            imageURL: item.imageURL
        )
        configureBubbleAlignment(isOutgoing: item.isOutgoing)
        statusView.configure(status: item.status, isOutgoing: item.isOutgoing)

        let spokenText = item.text
            ?? (item.imageURL != nil || item.localImageData != nil ? "Image attachment" : "Empty message")
        configureVoiceOver(
            senderLabel: item.senderLabel,
            spokenText: spokenText,
            timeText: timeText,
            isFailedOutgoing: item.status == .failed && item.isOutgoing,
            showsAvatar: !item.isOutgoing
        )
    }

    override func accessibilityActivate() -> Bool {
        guard canRetryViaAccessibility else { return false }
        retryTapped()
        return true
    }

    private func configureVoiceOver(
        senderLabel: String,
        spokenText: String,
        timeText: String,
        isFailedOutgoing: Bool,
        showsAvatar: Bool
    ) {
        isAccessibilityElement = false
        canRetryViaAccessibility = isFailedOutgoing

        var elements: [UIAccessibilityElement] = []

        if showsAvatar {
            let avatarElement = ActivatableAccessibilityElement(accessibilityContainer: self)
            avatarElement.accessibilityLabel = "\(senderLabel) profile"
            avatarElement.accessibilityTraits = .button
            avatarElement.accessibilityHint = "Opens profile"
            avatarElement.onActivate = { [weak self] in
                self?.avatarImageView.activateTap()
                return true
            }
            elements.append(avatarElement)
        }

        let senderElement = UIAccessibilityElement(accessibilityContainer: self)
        senderElement.accessibilityLabel = senderLabel
        senderElement.accessibilityTraits = .staticText
        elements.append(senderElement)

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
        elements.append(textElement)

        let timeElement = UIAccessibilityElement(accessibilityContainer: self)
        timeElement.accessibilityLabel = timeText
        timeElement.accessibilityTraits = .staticText
        elements.append(timeElement)

        accessibilityElements = elements
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let elements = accessibilityElements as? [UIAccessibilityElement] else {
            return
        }

        let bubbleFrame = contentView.convert(bubbleView.bounds, from: bubbleView)
        let avatarFrame = contentView.convert(avatarImageView.bounds, from: avatarImageView)
        var index = 0

        if !avatarImageView.isHidden, index < elements.count {
            elements[index].accessibilityFrameInContainerSpace = avatarFrame
            index += 1
        }

        let remaining = elements.count - index
        guard remaining >= 3 else { return }
        let third = bubbleFrame.height / 3
        elements[index].accessibilityFrameInContainerSpace = CGRect(
            x: bubbleFrame.minX,
            y: bubbleFrame.minY,
            width: bubbleFrame.width,
            height: max(third, 1)
        )
        elements[index + 1].accessibilityFrameInContainerSpace = CGRect(
            x: bubbleFrame.minX,
            y: bubbleFrame.minY + third,
            width: bubbleFrame.width,
            height: max(third, 1)
        )
        elements[index + 2].accessibilityFrameInContainerSpace = CGRect(
            x: bubbleFrame.minX,
            y: bubbleFrame.minY + 2 * third,
            width: bubbleFrame.width,
            height: max(bubbleFrame.height - 2 * third, 1)
        )
    }

    private func configureBubbleAlignment(isOutgoing: Bool) {
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false

        if isOutgoing {
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: ChatAppearance.oppositeGutter
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -ChatAppearance.sideGutter
            )
        } else {
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                equalTo: avatarImageView.trailingAnchor,
                constant: 8
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -ChatAppearance.oppositeGutter
            )
        }

        leadingConstraint?.isActive = true
        trailingConstraint?.isActive = true
        setNeedsLayout()
    }

    private func setupLayout() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(bubbleView)
        contentView.addSubview(statusView)

        let spacing = ChatAppearance.bubbleSpacingV

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChatAppearance.sideGutter
            ),
            avatarImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),

            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing),

            statusView.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            statusView.trailingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: -ChatAppearance.Spacing.statusGap
            )
        ])
    }

    private func retryTapped() {
        onRetry?()
    }
}
