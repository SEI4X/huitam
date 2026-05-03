import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: SettingsViewModel
    @State private var isDeleteConfirmationPresented = false

    init(container: AppDependencyContainer) {
        _viewModel = State(initialValue: SettingsViewModel(
            settingsService: container.settingsService,
            authService: container.authService
        ))
    }

    var body: some View {
        Form {
            Section("Languages") {
                Picker("My language", selection: Binding(
                    get: { viewModel.settings.nativeLanguage },
                    set: { language in
                        Task { await viewModel.updateNativeLanguage(language) }
                    }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Picker("Learning", selection: Binding(
                    get: { viewModel.settings.learningLanguage },
                    set: { selection in
                        Task {
                            await viewModel.updateLearningLanguage(selection)
                        }
                    }
                )) {
                    Text("Not learning").tag(LearningLanguageSelection.none)
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(LearningLanguageSelection.language(language))
                    }
                }

                if viewModel.canUseStudyFeatures == false {
                    Text("Study actions are hidden while language learning is off.")
                        .font(.footnote)
                        .foregroundStyle(PremiumTheme.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .listRowBackground(PremiumTheme.surface)

            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { viewModel.settings.theme },
                    set: { theme in
                        Task { await viewModel.updateTheme(theme) }
                    }
                )) {
                    ForEach(AppThemePreference.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }

                Picker("Tint", selection: Binding(
                    get: { viewModel.settings.tint },
                    set: { tint in
                        Task { await viewModel.updateTint(tint) }
                    }
                )) {
                    ForEach(AppTintPreference.allCases) { tint in
                        Label {
                            Text(tint.displayName)
                        } icon: {
                            Circle()
                                .fill(tint.color)
                                .frame(width: 10, height: 10)
                        }
                        .tag(tint)
                    }
                }
            }
            .listRowBackground(PremiumTheme.surface)

            Section("Notifications") {
                Toggle("Practice reminders", isOn: Binding(
                    get: { viewModel.settings.notificationsEnabled },
                    set: { enabled in
                        Task { await viewModel.updateNotifications(enabled: enabled) }
                    }
                ))
            }
            .listRowBackground(PremiumTheme.surface)

            Section("Account") {
                Button {
                    Task { await viewModel.signOut() }
                } label: {
                    Label(viewModel.isSigningOut ? "Signing Out" : "Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
                .disabled(viewModel.isDeletingAccount)
            }
            .listRowBackground(PremiumTheme.surface)

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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isDeleteConfirmationPresented) {
            DeleteAccountConfirmationView(
                isDeleting: viewModel.isDeletingAccount,
                onConfirm: { reason in
                    Task {
                        await viewModel.deleteAccount(reason: reason)
                        if viewModel.errorMessage == nil {
                            isDeleteConfirmationPresented = false
                        }
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.load()
        }
        .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.canUseStudyFeatures)
    }
}

private struct DeleteAccountConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var remainingSeconds = 10

    let isDeleting: Bool
    let onConfirm: (String) -> Void

    private var canConfirm: Bool {
        remainingSeconds == 0 &&
            reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
            isDeleting == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This will permanently delete your account, chats, invites, study cards, settings, and profile data. This action cannot be undone.")
                        .font(.subheadline)
                        .foregroundStyle(PremiumTheme.textSecondary)

                    TextEditor(text: $reason)
                        .frame(minHeight: 90)
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .background(PremiumTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if reason.isEmpty {
                                Text("Reason for deleting")
                                    .foregroundStyle(PremiumTheme.textTertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                } header: {
                    Text("Before You Delete")
                }
                .listRowBackground(PremiumTheme.surface)

                Section {
                    Button(role: .destructive) {
                        onConfirm(reason)
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Label(
                                remainingSeconds > 0 ? "Delete in \(remainingSeconds)s" : "Delete My Account",
                                systemImage: "trash"
                            )
                        }
                    }
                    .disabled(canConfirm == false)
                }
                .listRowBackground(PremiumTheme.surface)
            }
            .premiumScrollBackground(glowPosition: .top, intensity: 0.7)
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                while remainingSeconds > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    guard Task.isCancelled == false else { return }
                    remainingSeconds -= 1
                }
            }
        }
    }
}
