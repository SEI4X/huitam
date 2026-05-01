import SwiftUI

struct InviteLookupView: View {
    @State private var inviteID = ""
    @State private var invite: PracticeInvite?
    @State private var isLoading = false
    @State private var errorMessage: String?

    let friendService: FriendServicing

    var body: some View {
        Form {
            Section("Invite") {
                TextField("Invite Link or Code", text: $inviteID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task { await loadInvite() }
                } label: {
                    Label(isLoading ? "Loading" : "Open Invite", systemImage: "link")
                }
                .disabled(isLoading || inviteID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let invite {
                Section("Ready") {
                    NavigationLink {
                        InvitedFriendView(invite: invite, friendService: friendService)
                    } label: {
                        Label("Continue", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadInvite() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            invite = try await friendService.loadInvite(id: inviteID)
        } catch {
            errorMessage = AppErrorMessage.userFacing(error)
        }
    }
}
