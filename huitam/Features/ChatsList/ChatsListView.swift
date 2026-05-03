import SwiftUI

struct ChatsListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ChatsListViewModel
    @State private var path = NavigationPath()
    @Binding private var pendingInviteID: String?
    @Binding private var pendingAccountNickname: String?
    private let container: AppDependencyContainer
    private let defaultInviteRole: ChatParticipantRole
    private let currentNickname: String

    init(
        container: AppDependencyContainer,
        pendingInviteID: Binding<String?> = .constant(nil),
        pendingAccountNickname: Binding<String?> = .constant(nil),
        defaultInviteRole: ChatParticipantRole = .learner(.english),
        currentNickname: String = ""
    ) {
        self.container = container
        _pendingInviteID = pendingInviteID
        _pendingAccountNickname = pendingAccountNickname
        self.defaultInviteRole = defaultInviteRole
        self.currentNickname = currentNickname
        _viewModel = State(initialValue: ChatsListViewModel(
            chatService: container.chatService,
            presenceService: container.presenceService
        ))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(viewModel.filteredChats) { chat in
                    Button {
                        path.append(chat)
                    } label: {
                        ChatRowView(chat: chat, presence: viewModel.presenceStatus(for: chat))
                    }
                    .buttonStyle(.plain)
                    .premiumListRow(cornerRadius: 22)
                }
            }
            .listStyle(.plain)
            .premiumScrollBackground(intensity: 0.75)
            .searchable(
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.searchText = $0 }
                ),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search chats"
            )
            .overlay {
                if viewModel.chats.isEmpty && viewModel.isLoading == false {
                    EmptyChatsView {
                        withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                            viewModel.present(.addFriend)
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.filteredChats.isEmpty && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .transition(.opacity)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: ChatSummary.self) { chat in
                ChatView(chat: chat, container: container)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    ToolbarIconButton(title: "Profile", systemImage: "person.crop.circle") {
                        withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                            viewModel.present(.profile)
                        }
                    }
                    ToolbarIconButton(title: "Cards", systemImage: "graduationcap") {
                        withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                            viewModel.present(.studyCards)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarIconButton(title: "Add Friend", systemImage: "plus") {
                        withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                            viewModel.present(.addFriend)
                        }
                    }
                }
            }
            .sheet(item: Binding(
                get: { viewModel.presentedSheet },
                set: { viewModel.presentedSheet = $0 }
            )) { sheet in
                switch sheet {
                case .profile:
                    ProfileView(container: container)
                case .studyCards:
                    StudyCardsView(container: container)
                case .addFriend:
                    AddFriendView(
                        container: container,
                        defaultInviteRole: defaultInviteRole,
                        currentNickname: currentNickname,
                        onOpenChat: { chat in
                            viewModel.presentedSheet = nil
                            path.append(chat)
                        }
                    )
                }
            }
            .task {
                await viewModel.startObservingChats()
            }
            .onDisappear {
                viewModel.stopObservingPresence()
            }
            .task(id: pendingInviteID) {
                guard let inviteID = pendingInviteID else { return }
                await viewModel.acceptInvite(
                    id: inviteID,
                    role: defaultInviteRole,
                    friendService: container.friendService
                )
                pendingInviteID = nil
            }
            .task(id: pendingAccountNickname) {
                guard let nickname = pendingAccountNickname else { return }
                await viewModel.openAccountChat(
                    nickname: nickname,
                    role: defaultInviteRole,
                    friendService: container.friendService
                )
                pendingAccountNickname = nil
            }
            .onChange(of: viewModel.openedChat) { _, chat in
                guard let chat else { return }
                path.append(chat)
                viewModel.clearOpenedChat()
            }
        }
    }
}

private struct EmptyChatsView: View {
    let onAddFriend: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 36, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .background(PremiumTheme.surfaceStrong, in: Circle())
                .overlay {
                    Circle()
                        .stroke(PremiumTheme.hairline, lineWidth: 1)
                }

            VStack(spacing: 7) {
                Text("No chats yet")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Invite a friend and turn a real conversation into language practice.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button(action: onAddFriend) {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add Friend")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .premiumSurface(cornerRadius: 30, strength: 1.06)
    }
}
