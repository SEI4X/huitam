import SwiftUI

struct ChatsListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ChatsListViewModel
    private let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: ChatsListViewModel(chatService: container.chatService))
    }

    var body: some View {
        NavigationStack {
            List(viewModel.chats) { chat in
                NavigationLink {
                    ChatView(chat: chat, container: container)
                } label: {
                    ChatRowView(chat: chat)
                }
                .listRowSeparator(.visible)
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.chats.isEmpty && viewModel.isLoading == false {
                    ContentUnavailableView {
                        Label("No Chats", systemImage: "message")
                    } description: {
                        Text("Find a friend and start practicing.")
                    } actions: {
                        Button {
                            withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                                viewModel.present(.addFriend)
                            }
                        } label: {
                            Label("Add Friend", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Messages")
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
                    AddFriendView(container: container)
                }
            }
            .task {
                await viewModel.load()
            }
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.chats)
        }
    }
}
