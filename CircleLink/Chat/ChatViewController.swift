import Combine
import PhotosUI
import UIKit

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.separatorStyle = .none
        table.backgroundColor = ChatAppearance.canvas
        table.keyboardDismissMode = .interactive
        table.dataSource = self
        table.delegate = self
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseIdentifier)
        table.transform = CGAffineTransform(scaleX: 1, y: -1)
        table.contentInsetAdjustmentBehavior = .always
        return table
    }()

    private lazy var inputBar = InputBarView()

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
        title = "Chat"
        view.backgroundColor = ChatAppearance.canvas
        setupLayout()
        bindViewModel()
        inputBar.delegate = self

        Task {
            await viewModel.loadInitialMessages()
        }
    }

    override var inputAccessoryView: UIView? {
        inputBar
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    private func setupLayout() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                if case let .error(message) = state {
                    self.presentError(message)
                }
            }
            .store(in: &cancellables)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Chat Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
        cell.configure(with: item) { [weak self] in
            guard let self else { return }
            Task {
                await self.viewModel.retry(clientMessageId: item.clientMessageId)
            }
        }
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
                let compressed: Data
                if let image = info[.originalImage] as? UIImage {
                    compressed = try ImageCompressor.compressForChat(image)
                } else if let url = info[.imageURL] as? URL {
                    let raw = try Data(contentsOf: url)
                    compressed = try ImageCompressor.compressForChat(raw)
                } else {
                    return
                }

                await viewModel.send(imageData: compressed)
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }
}
