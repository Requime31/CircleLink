import MessageUI
import SwiftUI
import UIKit

@MainActor
final class SupportViewModel {
    enum ContactAction: Equatable { case presentComposer, showFallback }

    let payload: SupportMailPayload
    private let mailPresenter: SupportMailPresenting

    init(mailPresenter: SupportMailPresenting, metadataProvider: SupportDeviceMetadataProviding) {
        self.mailPresenter = mailPresenter
        payload = SupportMailPayloadFactory.make(metadata: metadataProvider.metadata)
    }

    func contactAction() -> ContactAction {
        mailPresenter.canSendMail ? .presentComposer : .showFallback
    }
}

struct SupportView: View {
    private let viewModel: SupportViewModel
    @State private var showsComposer = false
    @State private var showsFallback = false
    @State private var showsCopiedConfirmation = false
    @Environment(\.openURL) private var openURL

    init(viewModel: SupportViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section {
                Text("Tell us what you need help with. The email includes app and device details, but no account or message information.")
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Email Support", systemImage: "envelope") { contactSupport() }
                    .foregroundStyle(CLColor.ink)
            } footer: {
                Text(viewModel.payload.recipient)
                    .font(CLTypography.footnote)
                    .textSelection(.enabled)
            }
            .listRowBackground(CLColor.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsComposer) {
            SupportMailComposeView(payload: viewModel.payload, isPresented: $showsComposer)
        }
        .confirmationDialog("Email is not available", isPresented: $showsFallback, titleVisibility: .visible) {
            Button("Copy Email Address") {
                UIPasteboard.general.string = viewModel.payload.recipient
                showsCopiedConfirmation = true
            }
            if let url = viewModel.payload.mailtoURL {
                Button("Open Mail App") { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Copy the support address or try another mail app.")
        }
        .alert("Email address copied", isPresented: $showsCopiedConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func contactSupport() {
        switch viewModel.contactAction() {
        case .presentComposer: showsComposer = true
        case .showFallback: showsFallback = true
        }
    }
}

private struct SupportMailComposeView: UIViewControllerRepresentable {
    let payload: SupportMailPayload
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([payload.recipient])
        controller.setSubject(payload.subject)
        controller.setMessageBody(payload.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private var isPresented: Binding<Bool>

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // Cancel is a normal completion state; the system composer owns any error UI.
            isPresented.wrappedValue = false
        }
    }
}
