import UIKit

/// Chat bubble chrome: fill color, asymmetric tail mask, text / timestamp / image content.
final class MessageBubbleView: UIView {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = ChatAppearance.bodyFont
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ChatAppearance.captionFont
        label.adjustsFontForContentSizeCategory = true
        label.textColor = ChatAppearance.inkMuted
        return label
    }()

    private let imageAttachmentView = MessageImageAttachmentView(frame: .zero)
    private let bubbleMaskLayer = CAShapeLayer()
    private var isOutgoingBubble = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        layer.mask = bubbleMaskLayer
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBubbleMask()
    }

    func prepareForReuse() {
        imageAttachmentView.prepareForReuse()
        messageLabel.text = nil
        messageLabel.isHidden = false
        timestampLabel.text = nil
    }

    func configure(
        text: String?,
        timestamp: String,
        isOutgoing: Bool,
        localImageData: Data?,
        imageURL: URL?
    ) {
        timestampLabel.text = timestamp

        if let text, !text.isEmpty {
            messageLabel.text = text
            messageLabel.isHidden = false
        } else {
            messageLabel.text = nil
            messageLabel.isHidden = true
        }

        imageAttachmentView.configure(localImageData: localImageData, imageURL: imageURL)
        applyBubbleStyle(isOutgoing: isOutgoing)
    }

    private func applyBubbleStyle(isOutgoing: Bool) {
        isOutgoingBubble = isOutgoing
        backgroundColor = isOutgoing ? ChatAppearance.outgoingBubble : ChatAppearance.incomingBubble
        messageLabel.textColor = ChatAppearance.ink
        timestampLabel.textColor = ChatAppearance.inkMuted
        setNeedsLayout()
    }

    private func updateBubbleMask() {
        let bounds = bounds
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
        addSubview(imageAttachmentView)
        addSubview(messageLabel)
        addSubview(timestampLabel)

        let padH = ChatAppearance.bubblePaddingH
        let padV = ChatAppearance.bubblePaddingV

        NSLayoutConstraint.activate([
            imageAttachmentView.topAnchor.constraint(equalTo: topAnchor, constant: padV),
            imageAttachmentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padH),
            imageAttachmentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padH),

            messageLabel.topAnchor.constraint(equalTo: imageAttachmentView.bottomAnchor, constant: padV),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padH),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padH),

            timestampLabel.topAnchor.constraint(
                equalTo: messageLabel.bottomAnchor,
                constant: ChatAppearance.timestampSpacing
            ),
            timestampLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padH),
            timestampLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padH),
            timestampLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padV)
        ])
    }
}
