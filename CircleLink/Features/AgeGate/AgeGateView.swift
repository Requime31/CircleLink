import SwiftUI

struct AgeGateView: View {
    @ObservedObject var viewModel: AgeGateViewModel
    let onSignOut: () -> Void

    var body: some View {
        ZStack {
            CLColor.canvas.ignoresSafeArea()
            ambientBackground

            ScrollView {
                VStack(spacing: CLSpacing.xl) {
                    Text("CircleLink")
                        .font(CLTypography.display)
                        .foregroundStyle(CLColor.primaryPressed)
                        .padding(.top, CLSpacing.xxl)
                        .accessibilityHidden(true)

                    contentCard
                        .clAppear(delay: 0.04)

                    CLOnboardingStepIndicator(currentStep: 1)
                }
                .padding(.horizontal, CLSpacing.screenHorizontal)
                .padding(.bottom, CLSpacing.xl)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LogoutButton(action: onSignOut)
            }
        }
    }

    // MARK: - Sections

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(CLColor.primarySoft.opacity(0.55))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 130, y: -200)

            Circle()
                .fill(CLColor.surfaceSoft.opacity(0.9))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -140, y: 320)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var contentCard: some View {
        VStack(spacing: CLSpacing.md) {
            Image(systemName: "birthday.cake")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(CLColor.primaryPressed)
                .frame(width: 64, height: 64)
                .background(CLColor.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: CLSpacing.xs) {
                Text("How old are you?")
                    .font(CLTypography.largeTitle)
                    .foregroundStyle(CLColor.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("CircleLink is for people 18 and older.")
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            DatePicker(
                "Date of birth",
                selection: $viewModel.selectedBirthDate,
                in: viewModel.minimumBirthDate...viewModel.maximumBirthDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(CLTypography.body)
            .foregroundStyle(CLColor.ink)
            .padding(.vertical, CLSpacing.sm)
            .padding(.horizontal, CLSpacing.md)
            .frame(minHeight: 56)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                    .stroke(fieldBorderColor, lineWidth: 1)
            )
            .accessibilityHint("Choose your full date of birth. You must be at least 18.")

            Button {
                Task { await viewModel.confirmAge() }
            } label: {
                Text("Continue")
            }
            .buttonStyle(CLPrimaryButtonStyle())
            .disabled(!viewModel.canContinue || isBusy)
            .accessibilityLabel("Continue after confirming age")
            .accessibilityHint(viewModel.canContinue ? "Saves your date of birth and confirms you are 18 or older" : "Choose a valid date of birth first")
            .clSoftSpring(value: viewModel.canContinue)

            statusBlock

            VStack(spacing: CLSpacing.xxs) {
                Text("By continuing, you confirm that you meet our age requirements and agree to:")
                    .font(CLTypography.caption)
                    .foregroundStyle(CLColor.inkMuted)
                    .multilineTextAlignment(.center)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CLSpacing.xs) { legalLinks }
                    VStack(spacing: CLSpacing.xs) { legalLinks }
                }
            }
        }
        .padding(CLSpacing.lg)
        .clCardStyle(padded: false)
    }

    @ViewBuilder
    private var legalLinks: some View {
        NavigationLink("Terms of Service") {
            LegalDocumentView(document: LegalDocuments.termsOfService)
        }
        .accessibilityLabel("Read Terms of Service")

        Text("and")
            .font(CLTypography.caption)
            .foregroundStyle(CLColor.inkMuted)
            .accessibilityHidden(true)

        NavigationLink("Privacy Policy") {
            LegalDocumentView(document: LegalDocuments.privacyPolicy)
        }
        .accessibilityLabel("Read Privacy Policy")
    }

    @ViewBuilder
    private var statusBlock: some View {
        if case .loading = viewModel.state {
            ProgressView("Saving…")
                .tint(CLColor.primary)
                .foregroundStyle(CLColor.inkMuted)
        }

        if case let .error(message) = viewModel.state {
            Text(message)
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.error)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Error: \(message)")
        }
    }

    private var fieldBorderColor: Color {
        if case .error = viewModel.state { return CLColor.error }
        return CLColor.hairline
    }

    private var isBusy: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }
}
