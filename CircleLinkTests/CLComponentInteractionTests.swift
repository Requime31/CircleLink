import Testing
@testable import CircleLink

@MainActor
struct CLComponentInteractionTests {
    @Test func asyncButtonUsesLoadingCopyAndBlocksRepeatedActions() {
        let configuration = CLAsyncButtonConfiguration(title: "Save", loadingTitle: "Saving…")

        #expect(configuration.displayedTitle(isRunning: false) == "Save")
        #expect(configuration.displayedTitle(isRunning: true) == "Saving…")
        #expect(configuration.isInteractionDisabled(isRunning: true, isDisabled: false))
        #expect(configuration.isInteractionDisabled(isRunning: false, isDisabled: true))
        #expect(configuration.isInteractionDisabled(isRunning: false, isDisabled: false) == false)
    }

    @Test func asyncButtonFallsBackToStableAccessibleTitle() {
        let configuration = CLAsyncButtonConfiguration(title: "Continue", accessibilityLabel: "Continue setup")
        #expect(configuration.displayedTitle(isRunning: true) == "Continue")
        #expect(configuration.accessibilityLabel == "Continue setup")
    }

    @Test func photoPickerAvailabilityCoversAddRemoveAndDisabledStates() {
        let addOnly = CLPhotoPickerConfiguration(title: "Photo")
        let replaceable = CLPhotoPickerConfiguration(title: "Photo", actionTitle: "Replace Photo", removeTitle: "Remove Photo")
        let disabled = CLPhotoPickerConfiguration(title: "Photo", removeTitle: "Remove Photo", isDisabled: true)

        #expect(addOnly.canPick)
        #expect(addOnly.canRemove == false)
        #expect(replaceable.canPick)
        #expect(replaceable.canRemove)
        #expect(disabled.canPick == false)
        #expect(disabled.canRemove == false)
    }

    @Test func composerAcceptsTextOrMediaAndRejectsOverflowOrRepeatedSubmit() {
        let configuration = CLPostComposerConfiguration(characterLimit: 10)

        #expect(configuration.canSubmit(text: "Hello", hasMedia: false, isSubmitting: false))
        #expect(configuration.canSubmit(text: "  ", hasMedia: true, isSubmitting: false))
        #expect(configuration.canSubmit(text: "  ", hasMedia: false, isSubmitting: false) == false)
        #expect(configuration.canSubmit(text: "Too many characters", hasMedia: true, isSubmitting: false) == false)
        #expect(configuration.canSubmit(text: "Hello", hasMedia: false, isSubmitting: true) == false)
        #expect(configuration.validationMessage(for: "Too many characters") == "Post text must be 10 characters or fewer.")
    }
}
