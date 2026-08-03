import UIKit

/// Outgoing send-status chrome: spinner while sending, retry when failed.
final class MessageSendStatusView: UIView {
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

    var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        isUserInteractionEnabled = false
        addSubview(statusIndicator)
        addSubview(retryButton)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            statusIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: AccessibilityHelpers.minimumTouchTarget),
            retryButton.heightAnchor.constraint(equalToConstant: AccessibilityHelpers.minimumTouchTarget),

            widthAnchor.constraint(equalToConstant: AccessibilityHelpers.minimumTouchTarget),
            heightAnchor.constraint(equalToConstant: AccessibilityHelpers.minimumTouchTarget)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        statusIndicator.stopAnimating()
        retryButton.isHidden = true
        isHidden = true
        isUserInteractionEnabled = false
        onRetry = nil
    }

    func configure(status: MessageStatus, isOutgoing: Bool) {
        guard isOutgoing else {
            statusIndicator.stopAnimating()
            retryButton.isHidden = true
            isHidden = true
            isUserInteractionEnabled = false
            return
        }

        switch status {
        case .sending:
            statusIndicator.startAnimating()
            retryButton.isHidden = true
            isHidden = false
            isUserInteractionEnabled = false
        case .sent:
            statusIndicator.stopAnimating()
            retryButton.isHidden = true
            isHidden = true
            isUserInteractionEnabled = false
        case .failed:
            statusIndicator.stopAnimating()
            retryButton.isHidden = false
            isHidden = false
            isUserInteractionEnabled = true
        }
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}
