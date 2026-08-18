import SwiftUI

/// Visual onboarding progress dots with a VoiceOver step cue.
/// `currentStep` is 1-based (e.g. AgeGate = 1, ProfileSetup = 2 of 3).
struct CLOnboardingStepIndicator: View {
    let currentStep: Int
    var totalSteps: Int = 3

    var body: some View {
        HStack(spacing: CLSpacing.xs) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? CLColor.primary : CLColor.primary.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, CLSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }
}
