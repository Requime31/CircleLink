import PhotosUI
import SwiftUI

struct ProfileFormFields: View {
    enum Mode: Equatable { case setup, edit }

    @ObservedObject var viewModel: ProfileViewModel
    let mode: Mode

    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName
        case age
        case aboutMe
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.lg) {
            avatarSection
            displayNameSection
            if mode == .edit {
                ageSection
            }
            aboutMeSection
            interestsSection
        }
    }

    private var avatarSection: some View {
        CLAvatarPicker(
            selection: $selectedPhotoItem,
            hasPhoto: viewModel.hasAvatarToRemove,
            onRemove: {
                viewModel.clearAvatarSelection()
                selectedPhotoItem = nil
            }
        ) {
            AvatarImageView(
                localPreview: viewModel.localAvatarPreview,
                avatarBase64: viewModel.profile?.avatarBase64,
                avatarURL: viewModel.profile?.avatarURL,
                size: 96
            )
            .accessibilityLabel(viewModel.hasAvatarToRemove ? "Profile photo" : "No profile photo")
        }
        .frame(maxWidth: .infinity)
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setAvatarData(data)
                }
            }
        }
    }

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text("Display Name")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            TextField("Your name", text: $viewModel.displayName)
                .textContentType(.name)
                .autocorrectionDisabled()
                .foregroundStyle(CLColor.ink)
                .focused($focusedField, equals: .displayName)
                .clTextFieldChrome(isFocused: focusedField == .displayName)
                .accessibilityLabel("Display name")
        }
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text(viewModel.usesBirthDate ? "Date of Birth" : "Age")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            if viewModel.usesBirthDate {
                if mode == .edit {
                    DatePicker(
                        "Date of birth",
                        selection: $viewModel.selectedBirthDate,
                        in: viewModel.minimumBirthDate...viewModel.maximumBirthDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .clTextFieldChrome(isFocused: false)
                    .accessibilityHint("Changing this date changes the public age after confirmation.")
                } else {
                    VStack(alignment: .leading, spacing: CLSpacing.xs) {
                        Text(viewModel.selectedBirthDate, format: .dateTime.year().month(.wide).day())
                        if let age = viewModel.calculatedAge {
                            Text("Age \(age)")
                                .foregroundStyle(CLColor.inkSecondary)
                        }
                    }
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .padding(.horizontal, CLSpacing.md)
                    .frame(minHeight: 56)
                    .background(CLColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Date of birth and calculated age")
                }
            } else {
                TextField("e.g. 28", text: $viewModel.ageText)
                    .keyboardType(.numberPad)
                    .foregroundStyle(CLColor.ink)
                    .focused($focusedField, equals: .age)
                    .clTextFieldChrome(isFocused: focusedField == .age)
                    .accessibilityLabel("Age")

                if mode == .edit {
                    Button("Add date of birth instead") {
                        viewModel.offerBirthDateEntry()
                    }
                    .font(CLTypography.callout)
                    .foregroundStyle(CLColor.primaryPressed)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .accessibilityHint("Uses your date of birth to calculate public age automatically.")
                }
            }
        }
    }

    private var aboutMeSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text("About Me")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            TextField("A short intro…", text: $viewModel.aboutMe, axis: .vertical)
                .lineLimit(3...6)
                .foregroundStyle(CLColor.ink)
                .focused($focusedField, equals: .aboutMe)
                .clTextFieldChrome(isFocused: focusedField == .aboutMe)
                .accessibilityLabel("About me")
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text("Interests")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            Text(viewModel.interestCountHint)
                .font(CLTypography.footnote)
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityLabel(viewModel.interestCountHint)

            CLFlowLayout(horizontalSpacing: CLSpacing.xs, verticalSpacing: CLSpacing.xs) {
                ForEach(ProfileInterests.presets, id: \.self) { interest in
                    let isSelected = viewModel.selectedInterests.contains(interest)
                    let isDisabled = !isSelected && viewModel.selectedInterests.count >= User.maxInterests
                    CLChip(
                        title: interest,
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                        accessibilityLabelText: "\(interest) interest",
                        accessibilityHintText: isDisabled
                            ? "Maximum interests selected"
                            : "Double tap to toggle"
                    ) {
                        viewModel.toggleInterest(interest)
                    }
                }
            }
        }
    }
}
