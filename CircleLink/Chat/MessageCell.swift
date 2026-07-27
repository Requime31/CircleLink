import UIKit

final class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"

    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
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
        imageView.layer.cornerRadius = ChatAppearance.bubbleImageRadius
        imageView.layer.cornerCurve = .continuous
        imageView.isHidden = true
        imageView.accessibilityIgnoresInvertColors = true
        return imageView
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ChatAppearance.captionFont
        label.adjustsFontForContentSizeCategory = true
        label.textColor = ChatAppearance.inkMuted
        return label
    }()

    private let statusIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = ChatAppearance.inkMuted
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
    private var isOutgoingBubble = false
    private let bubbleMaskLayer = CAShapeLayer()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.transform = CGAffineTransform(scaleX: 1, y: -1)
        bubbleView.layer.mask = bubbleMaskLayer
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
        updateBubbleMask()

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
        isOutgoingBubble = isOutgoing
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false

        if isOutgoing {
            bubbleView.backgroundColor = ChatAppearance.outgoingBubble
            messageLabel.textColor = ChatAppearance.ink
            timestampLabel.textColor = ChatAppearance.inkMuted
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: ChatAppearance.oppositeGutter
            )
            trailingConstraint = bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -ChatAppearance.sideGutter
            )
        } else {
            bubbleView.backgroundColor = ChatAppearance.incomingBubble
            messageLabel.textColor = ChatAppearance.ink
            timestampLabel.textColor = ChatAppearance.inkMuted
            leadingConstraint = bubbleView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: ChatAppearance.sideGutter
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

    /// Soft tail: corner nearest the edge is slightly tighter (~12), others ~18.
    private func updateBubbleMask() {
        let bounds = bubbleView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let maxRadius = min(bounds.width, bounds.height) / 2
        let large = min(ChatAppearance.bubbleRadius, maxRadius)
        let small = min(ChatAppearance.bubbleTailRadius, maxRadius)
        let topLeft = large
        let topRight = large
        let bottomLeft = isOutgoingBubble ? large : small
        let bottomRight = isOutgoingBubble ? small : large

        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.minX + topLeft, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - topRight, y: bounds.minY))
        path.addArc(
            withCenter: CGPoint(x: bounds.maxX - topRight, y: bounds.minY + topRight),
            radius: topRight,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - bottomRight))
        path.addArc(
            withCenter: CGPoint(x: bounds.maxX - bottomRight, y: bounds.maxY - bottomRight),
            radius: bottomRight,
            startAngle: 0,
            endAngle: .pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: bounds.minX + bottomLeft, y: bounds.maxY))
        path.addArc(
            withCenter: CGPoint(x: bounds.minX + bottomLeft, y: bounds.maxY - bottomLeft),
            radius: bottomLeft,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY + topLeft))
        path.addArc(
            withCenter: CGPoint(x: bounds.minX + topLeft, y: bounds.minY + topLeft),
            radius: topLeft,
            startAngle: .pi,
            endAngle: -.pi / 2,
            clockwise: true
        )
        path.close()

        bubbleMaskLayer.frame = bounds
        bubbleMaskLayer.path = path.cgPath
    }

    private func setupLayout() {
        contentView.addSubview(bubbleView)
        contentView.addSubview(statusIndicator)
        contentView.addSubview(retryButton)

        bubbleView.addSubview(imageAttachmentView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(timestampLabel)

        imageHeightConstraint = imageAttachmentView.heightAnchor.constraint(equalToConstant: 0)
        let padH = ChatAppearance.bubblePaddingH
        let padV = ChatAppearance.bubblePaddingV
        let spacing = ChatAppearance.bubbleSpacingV

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing),

            imageAttachmentView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: padV),
            imageAttachmentView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: padH),
            imageAttachmentView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -padH),
            imageHeightConstraint!,

            messageLabel.topAnchor.constraint(equalTo: imageAttachmentView.bottomAnchor, constant: padV),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: padH),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -padH),

            timestampLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: ChatAppearance.timestampSpacing),
            timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: padH),
            timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -padH),
            timestampLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -padV),

            statusIndicator.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            statusIndicator.trailingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: -8),

            retryButton.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            retryButton.trailingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: -8),
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
