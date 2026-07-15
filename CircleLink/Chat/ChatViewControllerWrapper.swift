import SwiftUI

struct ChatViewControllerWrapper: UIViewControllerRepresentable {
    let viewModel: ChatViewModel

    func makeUIViewController(context: Context) -> ChatViewController {
        ChatViewController(viewModel: viewModel)
    }

    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {}
}
