import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: AddFriendViewModel
    @State private var isPracticeChatPresented = false
    @State private var isQRScannerPresented = false

    private let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: AddFriendViewModel(friendService: container.friendService))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isPracticeChatPresented = true
                    } label: {
                        Label("Create Practice Chat", systemImage: "link.badge.plus")
                    }
                }

                Section {
                    TextField("Nickname", text: Binding(
                        get: { viewModel.query },
                        set: { viewModel.query = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                    Button {
                        Task { await viewModel.search() }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.loadSharePayload() }
                    } label: {
                        Label("Share My Nickname", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isQRScannerPresented = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                }

                if let payload = viewModel.sharePayload {
                    Section("Share") {
                        Text(payload)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let scannedInvite = viewModel.scannedInvite {
                    Section("Scanned Invite") {
                        NavigationLink {
                            InvitedFriendView(invite: scannedInvite, container: container)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scannedInvite.inviterDisplayName)
                                    .font(.body.weight(.medium))
                                Text("Practice \(scannedInvite.inviterLearningLanguage.displayName)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
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

                Section("Results") {
                    if viewModel.results.isEmpty && viewModel.hasSearched {
                        ContentUnavailableView("No Results", systemImage: "person.crop.circle.badge.questionmark")
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.results) { result in
                            FriendSearchRowView(result: result)
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.results)
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.sharePayload)
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.scannedInvite)
            .sheet(isPresented: $isPracticeChatPresented) {
                CreatePracticeChatView(container: container)
            }
            .sheet(isPresented: $isQRScannerPresented) {
                QRCodeScannerView(
                    onCodeScanned: { payload in
                        isQRScannerPresented = false
                        Task {
                            await viewModel.openScannedInvitePayload(payload)
                        }
                    },
                    onCancel: {
                        isQRScannerPresented = false
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}
