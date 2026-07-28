import SwiftUI

struct ChatViewControllerWrapper: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ChatViewModel
    var onSenderAvatarTapped: ((String) -> Void)?

    func makeUIViewController(context: Context) -> ChatViewController {
        let controller = ChatViewController(viewModel: viewModel)
        controller.onSenderAvatarTapped = onSenderAvatarTapped
        return controller
    }

    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {
        uiViewController.onSenderAvatarTapped = onSenderAvatarTapped
    }
}
