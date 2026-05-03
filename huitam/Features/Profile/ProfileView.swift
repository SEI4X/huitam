import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
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
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))

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
                } else {
                    Section {
                        profileSkeleton
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
                    }

                    Section("Practice") {
                        ForEach(0..<5, id: \.self) { _ in
                            ProfileSkeletonRow()
                        }
                    }
                }
            }
            .premiumScrollBackground(glowPosition: .top, intensity: 0.66)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(container: container)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(PremiumTheme.surface, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(PremiumTheme.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                    .accessibilityLabel("Settings")
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func profileHeader(_ profile: UserProfile) -> some View {
        HStack(spacing: 14) {
            AvatarView(systemImage: profile.avatarSystemImage, size: 68, seed: profile.id)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PremiumTheme.textPrimary)
                Text("@\(profile.nickname)")
                    .font(.subheadline)
                    .foregroundStyle(PremiumTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var profileSkeleton: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(PremiumTheme.surfaceStrong)
                .frame(width: 68, height: 68)
                .overlay {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(PremiumTheme.textSecondary)
                }

            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(PremiumTheme.surfaceStrong)
                    .frame(width: 150, height: 18)
                Capsule()
                    .fill(PremiumTheme.surfaceStrong.opacity(0.72))
                    .frame(width: 96, height: 12)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
    }
}

private struct ProfileSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PremiumTheme.surfaceStrong)
                .frame(width: 30, height: 30)

            Capsule()
                .fill(PremiumTheme.surfaceStrong)
                .frame(width: 140, height: 14)

            Spacer()

            Capsule()
                .fill(PremiumTheme.surfaceStrong.opacity(0.72))
                .frame(width: 64, height: 14)
        }
        .redacted(reason: .placeholder)
    }
}
