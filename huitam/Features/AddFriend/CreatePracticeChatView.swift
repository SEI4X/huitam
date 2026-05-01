import SwiftUI

struct CreatePracticeChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreatePracticeChatViewModel

    private let friendService: FriendServicing

    init(friendService: FriendServicing) {
        self.friendService = friendService
        _viewModel = State(initialValue: CreatePracticeChatViewModel(friendService: friendService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Friend") {
                    Picker("Their Language", selection: Binding(
                        get: { viewModel.guestNativeLanguage },
                        set: { viewModel.guestNativeLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }

                    Picker("They Practice", selection: Binding(
                        get: { viewModel.guestLearningLanguage },
                        set: { viewModel.guestLearningLanguage = $0 }
                    )) {
                        Text("Not Learning")
                            .tag(LearningLanguageSelection.none)

                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(LearningLanguageSelection.language(language))
                        }
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.createInvite() }
                    } label: {
                        Label(
                            viewModel.isCreating ? "Creating" : "Create Invite Link",
                            systemImage: "link.badge.plus"
                        )
                    }
                    .disabled(viewModel.isCreating)
                }

                if let invite = viewModel.invite {
                    Section("Invite") {
                        Text(invite.shareURL.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        ShareLink(item: invite.shareURL) {
                            Label("Share Invite", systemImage: "square.and.arrow.up")
                        }

                        NavigationLink {
                            InvitedFriendView(invite: invite, friendService: friendService)
                        } label: {
                            Label("Preview Invitation", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Practice Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
