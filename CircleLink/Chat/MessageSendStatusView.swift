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
        onRetry = nil
    }

    func configure(status: MessageStatus, isOutgoing: Bool) {
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

    @objc private func retryTapped() {
        onRetry?()
    }
}
