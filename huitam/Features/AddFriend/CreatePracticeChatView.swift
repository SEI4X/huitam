import SwiftUI

struct CreatePracticeChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreatePracticeChatViewModel
    @State private var shareItem: ActivityShareItem?

    private let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: CreatePracticeChatViewModel(friendService: container.friendService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        Task { await shareInvite() }
                    } label: {
                        Label(
                            viewModel.isCreating ? "Creating" : "Share Invite Link",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .foregroundStyle(.white)
                    .disabled(viewModel.isCreating)
                }
                .listRowBackground(PremiumTheme.surfaceStrong)

                if let invite = viewModel.invite {
                    Section("Invite") {
                        HStack {
                            Spacer()
                            InviteQRCodeView(url: invite.shareURL)
                            Spacer()
                        }

                        Text(invite.shareURL.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(PremiumTheme.textSecondary)
                            .textSelection(.enabled)
                    }
                    .listRowBackground(PremiumTheme.surface)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    .listRowBackground(PremiumTheme.surface)
                }
            }
            .premiumScrollBackground(glowPosition: .top, intensity: 0.66)
            .navigationTitle("Practice Chat")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $shareItem) { item in
                ActivityShareView(items: [item.url])
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func shareInvite() async {
        await viewModel.createInvite()
        if let invite = viewModel.invite {
            shareItem = ActivityShareItem(url: invite.shareURL)
        }
    }
}
