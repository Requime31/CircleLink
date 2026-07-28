import SwiftUI

struct CreateCommunitySheet: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var interestTag = ProfileInterests.presets.first ?? "Sports"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityLabel("Community name")
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Community description")
                }

                Section("Interest") {
                    Picker("Interest", selection: $interestTag) {
                        ForEach(ProfileInterests.presets, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Community interest")
                }

                if let createErrorMessage = viewModel.createErrorMessage {
                    Section {
                        Text(createErrorMessage)
                            .font(CLTypography.callout)
                            .foregroundStyle(CLColor.error)
                            .accessibilityLabel("Create error: \(createErrorMessage)")
                    }
                }
            }
            .navigationTitle("New community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .disabled(viewModel.isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let didCreate = await viewModel.createCommunity(
                                name: name,
                                description: description,
                                interestTag: interestTag
                            )
                            if didCreate {
                                onDismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isCreating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Create community")
                }
            }
            .overlay {
                if viewModel.isCreating {
                    ProgressView("Creating…")
                        .padding(CLSpacing.base)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CLRadius.md))
                }
            }
            .onAppear {
                viewModel.clearCreateError()
            }
        }
    }
}
