import SwiftUI
import UIKit

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: AddFriendViewModel
    @State private var shareItem: ActivityShareItem?
    @State private var isQRScannerPresented = false
    @State private var didCopyInviteLink = false

    private let container: AppDependencyContainer
    private let defaultInviteRole: ChatParticipantRole
    private let accountLink: AccountShareLink
    private let onOpenChat: (ChatSummary) -> Void

    init(
        container: AppDependencyContainer,
        defaultInviteRole: ChatParticipantRole = .learner(.english),
        currentNickname: String = "",
        onOpenChat: @escaping (ChatSummary) -> Void = { _ in }
    ) {
        self.container = container
        self.defaultInviteRole = defaultInviteRole
        self.accountLink = AccountShareLink(nickname: currentNickname)
        self.onOpenChat = onOpenChat
        _viewModel = State(initialValue: AddFriendViewModel(friendService: container.friendService))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Invite") {
                    HStack {
                        Spacer()
                        InviteQRCodeView(url: accountLink.url)
                        Spacer()
                    }

                    Button {
                        copyInviteLink(accountLink.url)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: didCopyInviteLink ? "checkmark.circle.fill" : "link")
                                .font(.callout.weight(.semibold))
                            Text(accountLink.url.absoluteString)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(didCopyInviteLink ? .green : PremiumTheme.textSecondary)

                    Button {
                        shareItem = ActivityShareItem(url: accountLink.url)
                    } label: {
                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                }
                .listRowBackground(PremiumTheme.surface)
                .transition(.opacity.combined(with: .move(edge: .top)))

                Section {
                    TextField("Nickname", text: Binding(
                        get: { viewModel.query },
                        set: { viewModel.query = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .tint(.white)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                    Button {
                        Task { await viewModel.search() }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .foregroundStyle(.white)

                    Button {
                        isQRScannerPresented = true
                    } label: {
                        Label(viewModel.isAcceptingInvite ? "Opening Chat" : "Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                    .foregroundStyle(.white)
                    .disabled(viewModel.isAcceptingInvite)
                }
                .listRowBackground(PremiumTheme.surface)

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.42))
                                .padding(.top, 1)

                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.82))
                                .lineSpacing(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 0.22, green: 0.04, blue: 0.06).opacity(0.64))
                }

                if viewModel.results.isEmpty && viewModel.hasSearched {
                    Section("Results") {
                        ContentUnavailableView("No Results", systemImage: "person.crop.circle.badge.questionmark")
                            .listRowSeparator(.hidden)
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(PremiumTheme.surface)
                } else if viewModel.results.isEmpty == false {
                    Section("Results") {
                        ForEach(viewModel.results) { result in
                            FriendSearchRowView(result: result)
                        }
                    }
                    .listRowBackground(PremiumTheme.surface)
                }
            }
            .premiumScrollBackground(glowPosition: .top, intensity: 0.7)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.results)
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.isAcceptingInvite)
            .sheet(item: $shareItem) { item in
                ActivityShareView(items: [item.url])
            }
            .sheet(isPresented: $isQRScannerPresented) {
                QRCodeScannerView(
                    onCodeScanned: { payload in
                        isQRScannerPresented = false
                        Task {
                            await viewModel.acceptInvitePayload(payload, as: defaultInviteRole)
                        }
                    },
                    onCancel: {
                        isQRScannerPresented = false
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: viewModel.openedChat) { _, chat in
                guard let chat else { return }
                viewModel.clearOpenedChat()
                dismiss()
                onOpenChat(chat)
            }
        }
    }

    private func copyInviteLink(_ url: URL) {
        UIPasteboard.general.string = url.absoluteString
        withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
            didCopyInviteLink = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
                didCopyInviteLink = false
            }
        }
    }
}
