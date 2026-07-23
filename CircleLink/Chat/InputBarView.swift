import UIKit

protocol InputBarViewDelegate: AnyObject {
    func inputBarDidTapSend(text: String)
    func inputBarDidTapAttach()
}

final class InputBarView: UIView {
    weak var delegate: InputBarViewDelegate?

    private let textField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Message"
        field.font = ChatAppearance.bodyFont
        field.textColor = ChatAppearance.ink
        field.adjustsFontForContentSizeCategory = true
        field.borderStyle = .none
        field.backgroundColor = ChatAppearance.surfaceSoft
        field.layer.cornerRadius = ChatAppearance.Radius.field
        field.layer.masksToBounds = true
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.rightViewMode = .always
        field.returnKeyType = .send
        field.accessibilityLabel = "Message text field"
        return field
    }()

    private let attachButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "photo.on.rectangle")
        button.setImage(image, for: .normal)
        button.tintColor = ChatAppearance.primary
        button.accessibilityLabel = "Attach image"
        return button
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "paperplane.fill")
        button.setImage(image, for: .normal)
        button.tintColor = ChatAppearance.primary
        button.accessibilityLabel = "Send message"
        return button
    }()

    private let topSeparator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = ChatAppearance.hairline
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChatAppearance.canvas
        autoresizingMask = .flexibleHeight
        setupLayout()
        setupActions()
        textField.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: max(ChatAppearance.Spacing.barMinHeight, AccessibilityHelpers.minimumTouchTarget + 12)
        )
    }

    func clearText() {
        textField.text = nil
    }

    private func setupLayout() {
        addSubview(topSeparator)
        addSubview(attachButton)
        addSubview(textField)
        addSubview(sendButton)

        let touch = AccessibilityHelpers.minimumTouchTarget
        let edge = ChatAppearance.Spacing.barEdge

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 1),

            attachButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edge),
            attachButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: touch),
            attachButton.heightAnchor.constraint(equalToConstant: touch),

            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -edge),
            sendButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: touch),
            sendButton.heightAnchor.constraint(equalToConstant: touch),

            textField.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: edge),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -edge),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: ChatAppearance.Spacing.fieldMinHeight)
        ])
    }

    private func setupActions() {
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        attachButton.addTarget(self, action: #selector(attachTapped), for: .touchUpInside)
    }

    @objc private func sendTapped() {
        let text = textField.text ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        delegate?.inputBarDidTapSend(text: text)
        clearText()
    }

    @objc private func attachTapped() {
        delegate?.inputBarDidTapAttach()
    }
}

extension InputBarView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}
