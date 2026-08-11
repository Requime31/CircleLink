import PhotosUI
import SwiftUI

struct ProfileFormFields: View {
    @ObservedObject var viewModel: ProfileViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.lg) {
            avatarSection
            displayNameSection
            ageSection
            aboutMeSection
            interestsSection
        }
    }

    private var avatarSection: some View {
        VStack(spacing: CLSpacing.sm) {
            AvatarImageView(
                localPreview: viewModel.localAvatarPreview,
                avatarBase64: viewModel.profile?.avatarBase64,
                avatarURL: viewModel.profile?.avatarURL,
                size: 96
            )
            .accessibilityLabel(viewModel.hasAvatarToRemove ? "Profile photo" : "No profile photo")

            if viewModel.localAvatarPreview == nil {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("Add Photo (Optional)")
                        .font(CLTypography.button)
                        .foregroundStyle(CLColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        .background(CLColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                                .stroke(CLColor.hairlineStrong, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                }
                .accessibilityLabel("Choose profile photo")
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("Change Photo")
                        .font(CLTypography.button)
                        .foregroundStyle(CLColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                        .background(CLColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                                .stroke(CLColor.hairlineStrong, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                }
                .accessibilityLabel("Choose profile photo")
            }

            if viewModel.hasAvatarToRemove {
                Button("Remove Photo", role: .destructive) {
                    viewModel.clearAvatarSelection()
                    selectedPhotoItem = nil
                }
                .foregroundStyle(CLColor.error)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                .accessibilityLabel("Remove selected profile photo")
            }
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
                .clTextFieldChrome()
                .accessibilityLabel("Display name")
        }
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xs) {
            Text("Age")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)

            TextField("e.g. 28", text: $viewModel.ageText)
                .keyboardType(.numberPad)
                .foregroundStyle(CLColor.ink)
                .clTextFieldChrome()
                .accessibilityLabel("Age")
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
                .clTextFieldChrome()
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

            FlowLayout(spacing: CLSpacing.xs) {
                ForEach(ProfileInterests.presets, id: \.self) { interest in
                    InterestTagButton(
                        title: interest,
                        isSelected: viewModel.selectedInterests.contains(interest),
                        isDisabled: !viewModel.selectedInterests.contains(interest)
                            && viewModel.selectedInterests.count >= User.maxInterests
                    ) {
                        viewModel.toggleInterest(interest)
                    }
                }
            }
        }
    }
}

private struct InterestTagButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CLTypography.subheadline)
                .foregroundStyle(isSelected ? CLColor.ink : CLColor.inkSecondary)
                .padding(.horizontal, CLSpacing.sm)
                .padding(.vertical, CLSpacing.xs)
                .frame(
                    minWidth: AccessibilityHelpers.minimumTouchTarget,
                    minHeight: AccessibilityHelpers.minimumTouchTarget
                )
                .background(isSelected ? CLColor.primarySoft : CLColor.surfaceSoft)
                .clipShape(Capsule(style: .continuous))
                .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.45 : 1)
        .clSoftSpring(value: isSelected)
        .accessibilityLabel("\(title) interest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isDisabled ? "Maximum interests selected" : "Double tap to toggle")
    }
}

/// Simple wrapping layout for interest tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        // Bounded width only — `.infinity` as layout size causes CoreGraphics NaN.
        let boundedWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        let maxWidth = boundedWidth ?? .greatestFiniteMagnitude
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if boundedWidth != nil, x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, x + size.width)
            x += size.width + spacing
        }

        let height = y + rowHeight
        return Arrangement(
            size: CGSize(width: boundedWidth ?? contentWidth, height: height),
            positions: positions,
            sizes: sizes
        )
    }

    private struct Arrangement {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
