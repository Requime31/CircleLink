import SwiftUI

struct ChatViewControllerWrapper: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ChatViewModel
    var onSenderAvatarTapped: ((String) -> Void)?
    var onImageAttachmentTapped: ((URL?, Data?) -> Void)?

    func makeUIViewController(context: Context) -> ChatViewController {
        let controller = ChatViewController(viewModel: viewModel)
        controller.onSenderAvatarTapped = onSenderAvatarTapped
        controller.onImageAttachmentTapped = onImageAttachmentTapped
        return controller
    }

    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {
        uiViewController.onSenderAvatarTapped = onSenderAvatarTapped
        uiViewController.onImageAttachmentTapped = onImageAttachmentTapped
    }
}
