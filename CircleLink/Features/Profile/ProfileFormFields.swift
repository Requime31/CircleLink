import PhotosUI
import SwiftUI

struct ProfileFormFields: View {
    @ObservedObject var viewModel: ProfileViewModel

    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            avatarSection
            displayNameSection
            interestsSection
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            avatarPreview

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text(viewModel.localAvatarPreview == nil ? "Add Photo (Optional)" : "Change Photo")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Choose profile photo")

            if viewModel.hasAvatarToRemove {
                Button("Remove Photo", role: .destructive) {
                    viewModel.clearAvatarSelection()
                    selectedPhotoItem = nil
                }
                .accessibilityLabel("Remove selected profile photo")
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setAvatarData(data)
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        AvatarImageView(
            localPreview: viewModel.localAvatarPreview,
            avatarBase64: viewModel.profile?.avatarBase64,
            avatarURL: viewModel.profile?.avatarURL,
            size: 96
        )
        .accessibilityLabel(viewModel.hasAvatarToRemove ? "Profile photo" : "No profile photo")
    }

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Name")
                .font(.headline)

            TextField("Your name", text: $viewModel.displayName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .autocorrectionDisabled()
                .accessibilityLabel("Display name")
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interests")
                .font(.headline)

            Text(viewModel.interestCountHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel(viewModel.interestCountHint)

            FlowLayout(spacing: 8) {
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

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
        }
        .disabled(isDisabled)
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
