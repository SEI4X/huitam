import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ProfileViewModel
    private let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: ProfileViewModel(profileService: container.profileService))
    }

    var body: some View {
        NavigationStack {
            List {
                if let profile = viewModel.profile {
                    Section {
                        profileHeader(profile)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 2, trailing: 16))

                        ProfileStreakCardView(streakDays: profile.streakDays, goal: 30)
                    }

                    Section("Practice") {
                        ProfileStatRowView(title: "Messages practiced", value: "\(profile.stats.messagesPracticed)", systemImage: "message", iconColor: .blue)
                        ProfileStatRowView(title: "Cards saved", value: "\(profile.stats.cardsSaved)", systemImage: "graduationcap", iconColor: .purple)
                        ProfileStatRowView(title: "AI corrections", value: "\(profile.stats.correctionsUsed)", systemImage: "sparkles", iconColor: .yellow)
                        ProfileStatRowView(title: "Native language", value: profile.nativeLanguage.displayName, systemImage: "globe", iconColor: .green)
                        ProfileStatRowView(title: "Learning", value: profile.learningLanguage.displayName, systemImage: "text.book.closed", iconColor: .orange)
                    }

                    Section {
                        ProfileActivityChartView(points: profile.stats.dailyMessages)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.primary)
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(container: container)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                    .accessibilityLabel("Settings")
                }
            }
            .task {
                await viewModel.load()
            }
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.profile)
        }
    }

    private func profileHeader(_ profile: UserProfile) -> some View {
        HStack(spacing: 14) {
            AvatarView(systemImage: profile.avatarSystemImage, size: 68, seed: profile.id)
                .symbolEffect(.bounce, value: profile.streakDays)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.displayName)
                    .font(.title2.weight(.semibold))
                Text("@\(profile.nickname)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
