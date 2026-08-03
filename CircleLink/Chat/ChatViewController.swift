import Combine
import PhotosUI
import UIKit

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    /// Incoming avatar tap → Peer Profile (wired from SwiftUI).
    var onSenderAvatarTapped: ((String) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var displayedMessages: [ChatMessageItem] = []
    private var keyboardBottomConstraint: NSLayoutConstraint?

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.separatorStyle = .none
        table.backgroundColor = ChatAppearance.canvas
        table.keyboardDismissMode = .interactive
        table.dataSource = self
        table.delegate = self
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseIdentifier)
        // Inverted chat list: newest messages near the input bar.
        table.transform = CGAffineTransform(scaleX: 1, y: -1)
        // Manual insets — automatic adjustment fights inverted transform + SwiftUI sheet.
        table.contentInsetAdjustmentBehavior = .never
        return table
    }()

    private lazy var inputBar: InputBarView = {
        let bar = InputBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    private lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        return picker
    }()

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Title / info live in SwiftUI toolbar (ChatThreadView).
        title = nil
        navigationItem.largeTitleDisplayMode = .never
        view.accessibilityLabel = "Chat with \(viewModel.chatTitle)"
        view.backgroundColor = ChatAppearance.canvas
        setupLayout()
        bindViewModel()
        observeKeyboard()
        inputBar.delegate = self

        Task {
            await viewModel.loadInitialMessages()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.onAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.onDisappear()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(inputBar)

        let bottomConstraint = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        keyboardBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.heightAnchor.constraint(equalToConstant: 56),
            bottomConstraint
        ])
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else {
            return
        }

        let keyboardFrameInView = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY - view.safeAreaInsets.bottom)

        keyboardBottomConstraint?.constant = -overlap
        animateAlongsideKeyboard(duration: duration, userInfo: notification.userInfo) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        keyboardBottomConstraint?.constant = 0
        animateAlongsideKeyboard(duration: duration, userInfo: notification.userInfo) {
            self.view.layoutIfNeeded()
        }
    }

    /// Match system keyboard curve so the composer rides up smoothly (not a flashy snap).
    private func animateAlongsideKeyboard(
        duration: TimeInterval,
        userInfo: [AnyHashable: Any]?,
        animations: @escaping () -> Void
    ) {
        // Curve key is UIView.AnimationCurve raw value; shift into AnimationOptions.
        let curveRaw = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue
            ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: animations)
    }

    private func bindViewModel() {
        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.applyMessageUpdates(messages)
            }
            .store(in: &cancellables)

        viewModel.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                if case let .error(message) = state {
                    self.presentError(message, title: "Chat Error")
                }
            }
            .store(in: &cancellables)

        viewModel.$participantLoadErrorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message, title: "Some chat details are unavailable") {
                    self?.viewModel.clearParticipantLoadError()
                }
            }
            .store(in: &cancellables)
    }

    private func presentError(
        _ message: String,
        title: String = "Chat Error",
        onDismiss: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { _ in
                onDismiss?()
            }
        )
        present(alert, animated: true)
    }

    private func applyMessageUpdates(_ messages: [ChatMessageItem]) {
        let previous = displayedMessages
        displayedMessages = messages

        guard isViewLoaded, tableView.window != nil else {
            tableView.reloadData()
            return
        }

        if previous.isEmpty {
            tableView.reloadData()
            return
        }

        if messages.count == previous.count + 1,
           let insertedIndex = messages.firstIndex(where: { newItem in
               !previous.contains(where: { $0.clientMessageId == newItem.clientMessageId })
           }) {
            tableView.insertRows(at: [IndexPath(row: insertedIndex, section: 0)], with: .none)
            return
        }

        if messages.count == previous.count {
            var changedIndexPaths: [IndexPath] = []
            for index in messages.indices where messages[index] != previous[index] {
                changedIndexPaths.append(IndexPath(row: index, section: 0))
            }

            if !changedIndexPaths.isEmpty {
                tableView.reloadRows(at: changedIndexPaths, with: .none)
            }
            return
        }

        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MessageCell.reuseIdentifier,
            for: indexPath
        ) as? MessageCell else {
            return UITableViewCell()
        }

        let item = viewModel.messages[indexPath.row]
        cell.configure(
            with: item,
            onRetry: { [weak self] in
                guard let self else { return }
                Task {
                    await self.viewModel.retry(clientMessageId: item.clientMessageId)
                }
            },
            onAvatarTap: item.isOutgoing
                ? nil
                : { [weak self] in
                    self?.onSenderAvatarTapped?(item.senderId)
                }
        )
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Task {
            await viewModel.loadMoreMessagesIfNeeded(currentIndex: indexPath.row)
        }
    }
}

// MARK: - InputBarViewDelegate

extension ChatViewController: InputBarViewDelegate {
    func inputBarDidTapSend(text: String) {
        Task {
            await viewModel.send(text: text)
        }
    }

    func inputBarDidTapAttach() {
        present(imagePicker, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        Task {
            do {
                // Pass original/intermediate bytes only — repository compresses once off-main.
                let raw = try await Self.rawImageData(from: info)
                await viewModel.send(imageData: raw)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    /// Loads picker bytes off the main actor without applying upload size policy.
    private static func rawImageData(
        from info: [UIImagePickerController.InfoKey: Any]
    ) async throws -> Data {
        if let url = info[.imageURL] as? URL {
            return try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
        }

        if let image = info[.originalImage] as? UIImage {
            return try await Task.detached(priority: .userInitiated) {
                guard let data = image.jpegData(compressionQuality: 1.0) else {
                    throw ImageCompressorError.invalidImageData
                }
                return data
            }.value
        }

        throw ImageCompressorError.invalidImageData
    }
}
