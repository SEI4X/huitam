import SwiftUI

struct InvitedFriendView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: InvitedFriendViewModel

    init(invite: PracticeInvite, friendService: FriendServicing) {
        _viewModel = State(initialValue: InvitedFriendViewModel(
            invite: invite,
            friendService: friendService
        ))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("From", value: viewModel.invite.inviterDisplayName)
                LabeledContent("They practice", value: viewModel.invite.inviterLearningLanguage.displayName)
                LabeledContent("Your language", value: viewModel.invite.guestNativeLanguage.displayName)
            }

            Section("Your mode") {
                Picker("Practice too", selection: Binding(
                    get: { viewModel.guestLearningLanguage },
                    set: { viewModel.guestLearningLanguage = $0 }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Button {
                    Task { await viewModel.acceptAsCompanion() }
                } label: {
                    Label("Continue Without Learning", systemImage: "message")
                }

                Button {
                    Task { await viewModel.acceptAsLearner() }
                } label: {
                    Label("Practice Too", systemImage: "arrow.left.arrow.right")
                }
            }

            if let createdChat = viewModel.createdChat {
                Section("Ready") {
                    LabeledContent("Chat", value: createdChat.participant.displayName)
                    LabeledContent("Mode", value: createdChat.currentUserRole.displayName)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isAccepting)
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.createdChat)
    }
}

#Preview {
    NavigationStack {
        InvitedFriendView(
            invite: MockAppData.sampleInvite,
            friendService: MockFriendService()
        )
    }
}
