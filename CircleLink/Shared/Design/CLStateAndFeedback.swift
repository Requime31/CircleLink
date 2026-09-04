import SwiftUI

struct CLErrorState: View {
    let title: String
    var message: String? = nil
    var retryTitle: String? = "Try Again"
    var retry: (() -> Void)? = nil
    var isCompact = false

    var body: some View {
        CLEmptyState(
            systemImage: "exclamationmark.triangle",
            title: title,
            message: message,
            actionTitle: retry == nil ? nil : retryTitle,
            actionAccessibilityLabel: retryTitle,
            titleAccessibilityLabel: "Error: \(title)",
            action: retry,
            layout: isCompact ? .compact : .fill
        )
    }
}

enum CLAsyncContentState<Value> {
    case idle
    case loading
    case content(Value)
    case empty
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension CLAsyncContentState: Equatable where Value: Equatable {}

struct CLAsyncContent<Value, Content: View, Empty: View, Failure: View>: View {
    let state: CLAsyncContentState<Value>
    private let content: (Value) -> Content
    private let empty: () -> Empty
    private let failure: (String) -> Failure
    var loadingMessage: String? = nil

    init(
        state: CLAsyncContentState<Value>,
        loadingMessage: String? = nil,
        @ViewBuilder content: @escaping (Value) -> Content,
        @ViewBuilder empty: @escaping () -> Empty,
        @ViewBuilder failure: @escaping (String) -> Failure
    ) {
        self.state = state
        self.loadingMessage = loadingMessage
        self.content = content
        self.empty = empty
        self.failure = failure
    }

    @ViewBuilder var body: some View {
        switch state {
        case .idle, .loading:
            CLLoadingState(message: loadingMessage)
        case let .content(value):
            content(value)
        case .empty:
            empty()
        case let .error(message):
            failure(message)
        }
    }
}

struct CLConfirmationConfiguration: Equatable {
    let title: String
    let message: String
    let confirmTitle: String
    var retryTitle: String? = nil
    var cancelTitle = "Cancel"
    var confirmHint: String? = nil
    var role: ButtonRole? = nil
}

struct CLConfirmationView<Illustration: View>: View {
    let configuration: CLConfirmationConfiguration
    var isPerforming = false
    var errorMessage: String? = nil
    let onCancel: () -> Void
    let onConfirm: () -> Void
    private let illustration: Illustration

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        configuration: CLConfirmationConfiguration,
        isPerforming: Bool = false,
        errorMessage: String? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.configuration = configuration
        self.isPerforming = isPerforming
        self.errorMessage = errorMessage
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.illustration = illustration()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.lg) {
                illustration
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 180 : 220)
                    .accessibilityHidden(true)

                VStack(spacing: CLSpacing.sm) {
                    Text(configuration.title)
                        .font(CLTypography.title)
                        .foregroundStyle(CLColor.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(configuration.message)
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    CLStatusBanner(message: errorMessage, style: .error, presentation: .inline, accessibilityPrefix: "Action failed")
                }

                VStack(spacing: CLSpacing.sm) {
                    Button(action: onConfirm) {
                        HStack(spacing: CLSpacing.xs) {
                            if isPerforming { ProgressView().tint(CLColor.onPrimaryStrong) }
                            Text(errorMessage == nil ? configuration.confirmTitle : configuration.retryTitle ?? configuration.confirmTitle)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AnyCLButtonStyle(
                        style: configuration.role == .destructive ? .destructive : .emphasis
                    ))
                    .disabled(isPerforming)
                    .modifier(CLAccessibilityHint(hint: configuration.confirmHint))

                    Button(configuration.cancelTitle, action: onCancel)
                        .buttonStyle(CLSecondaryButtonStyle())
                        .disabled(isPerforming)
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.lg)
        }
        .clCanvasBackground()
        .interactiveDismissDisabled(isPerforming)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

}
