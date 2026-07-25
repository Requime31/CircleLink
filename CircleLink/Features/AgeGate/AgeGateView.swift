import SwiftUI

/// Soft age confirmation in Soft Orbit language. ViewModel bindings unchanged.
///
/// Data flow:
/// User confirm + Continue → AgeGateViewModel → UserRepository.confirmAge()
///   → fetchProfile → onAgeConfirmed → AppCoordinator → Profile Setup / MainTab
struct AgeGateView: View {
    @ObservedObject var viewModel: AgeGateViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, CLSpacing.lg)
                .padding(.top, CLSpacing.xxl)
                .padding(.bottom, CLSpacing.xl)
                .frame(maxWidth: .infinity)
                .clAppear()
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            SoftOrbitCanvas(intensity: .quiet)
                .ignoresSafeArea()
        }
        .navigationTitle("Age Gate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LogoutButton(action: onSignOut)
            }
        }
    }

    private var content: some View {
        VStack(spacing: CLSpacing.lg) {
            Image(systemName: "18.circle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(CLColor.muted)
                .padding(CLSpacing.base)
                .background(
                    Circle()
                        .fill(CLColor.companionSoft)
                )
                .accessibilityHidden(true)

            VStack(spacing: CLSpacing.sm) {
                Text("Age Verification")
                    .font(CLTypography.title)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("CircleLink is for people 18 and older. Confirm your age to continue — gently, and only once.")
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: CLSpacing.md) {
                Toggle(isOn: $viewModel.isAgeConfirmed) {
                    Text("I am 18 or older")
                        .font(CLTypography.bodyMedium)
                        .foregroundStyle(CLColor.ink)
                }
                .tint(CLColor.primary)
                .clCardStyle(padded: true)
                .clSoftSpring(value: viewModel.isAgeConfirmed)
                .accessibilityLabel("I am 18 or older")

                Button {
                    Task { await viewModel.confirmAge() }
                } label: {
                    Text("Continue")
                        .font(CLTypography.button)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        .foregroundStyle(viewModel.canContinue ? CLColor.onPrimary : CLColor.muted)
                        .background(viewModel.canContinue ? CLColor.primary : CLColor.primaryDisabled)
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canContinue)
                .accessibilityLabel("Continue after confirming age")
                .clSoftSpring(value: viewModel.canContinue)

                statusBlock
            }
            .clAppear(delay: 0.06)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusBlock: some View {
        if case .loading = viewModel.state {
            ProgressView("Saving…")
                .tint(CLColor.primary)
                .foregroundStyle(CLColor.muted)
                .clAppear()
        }

        if case let .error(message) = viewModel.state {
            Text(message)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.error)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Error: \(message)")
                .clAppear()
        }
    }
}

// MARK: - Atmosphere (view-local)

private enum SoftOrbitIntensity {
    case splash
    case quiet
}

/// Soft blush canvas with faint orbit rings. Shared look with Auth; quieter for AgeGate.
private struct SoftOrbitCanvas: View {
    var intensity: SoftOrbitIntensity = .splash

    var body: some View {
        ZStack {
            CLColor.canvas

            Circle()
                .fill(CLColor.companionSoft.opacity(intensity == .quiet ? 0.4 : 0.55))
                .frame(width: intensity == .quiet ? 220 : 280, height: intensity == .quiet ? 220 : 280)
                .blur(radius: 36)
                .offset(x: -80, y: -160)

            Circle()
                .stroke(CLColor.hairlineSoft.opacity(0.85), lineWidth: 1)
                .frame(width: 180, height: 180)
                .offset(x: 100, y: -100)

            if intensity == .splash {
                Circle()
                    .fill(CLColor.surfaceStrong.opacity(0.45))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .offset(x: 80, y: 320)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Age Gate") {
    NavigationStack {
        AgeGateView(
            viewModel: AgeGateViewModel(
                authRepository: StubAuthRepository(),
                userRepository: StubUserRepository(),
                onAgeConfirmed: { _ in }
            ),
            onSignOut: {}
        )
    }
}
