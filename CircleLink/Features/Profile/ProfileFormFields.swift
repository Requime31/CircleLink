import PhotosUI
import SwiftUI

/// Shared profile form chrome (avatar, name, interest chips). Soft Orbit UI only.
/// Selection / avatar data still owned by `ProfileViewModel`.
struct ProfileFormFields: View {
    @ObservedObject var viewModel: ProfileViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.lg) {
            avatarSection
            displayNameSection
            interestsSection
        }
    }

    private var avatarSection: some View {
        VStack(spacing: CLSpacing.md) {
            AvatarImageView(
                localPreview: viewModel.localAvatarPreview,
                avatarBase64: viewModel.profile?.avatarBase64,
                avatarURL: viewModel.profile?.avatarURL,
                size: 96
            )
            .accessibilityLabel(viewModel.hasAvatarToRemove ? "Profile photo" : "No profile photo")

            let photoButtonTitle = viewModel.localAvatarPreview == nil
                ? "Add Photo (Optional)"
                : "Change Photo"
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text(photoButtonTitle)
                    .font(CLTypography.buttonSmall)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .foregroundStyle(CLColor.ink)
                    .background(CLColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                            .stroke(CLColor.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose profile photo")

            if viewModel.hasAvatarToRemove {
                Button("Remove Photo", role: .destructive) {
                    viewModel.clearAvatarSelection()
                    selectedPhotoItem = nil
                }
                .font(CLTypography.buttonSmall)
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
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Display Name")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            TextField("Your name", text: $viewModel.displayName)
                .textContentType(.name)
                .autocorrectionDisabled()
                .foregroundStyle(CLColor.ink)
                .clTextFieldChrome()
                .accessibilityLabel("Display name")
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("Interests")
                .font(CLTypography.section)
                .foregroundStyle(CLColor.ink)

            Text(viewModel.interestCountHint)
                .font(CLTypography.caption)
                .foregroundStyle(CLColor.muted)
                .accessibilityLabel(viewModel.interestCountHint)

            FlowLayout(spacing: CLSpacing.sm) {
                ForEach(ProfileInterests.presets, id: \.self) { interest in
                    CLInterestChip(
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
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        let height = y + rowHeight
        return Arrangement(
            size: CGSize(width: maxWidth, height: height),
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
