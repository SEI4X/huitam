import SwiftUI

struct ProfileStreakCardView: View {
    @Environment(\.appTintColor) private var tintColor

    let streakDays: Int
    let goal: Int

    private var progress: Double {
        min(Double(streakDays) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            iconPanel
            progressPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .premiumSurface(cornerRadius: 22, strength: 1.12)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var iconPanel: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tintColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(streakDays) days")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(PremiumTheme.textPrimary)
                Text("Steps streak")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PremiumTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streakDays)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PremiumTheme.textPrimary)
                Text("/\(goal)")
                    .font(.caption)
                    .foregroundStyle(PremiumTheme.textSecondary)
                Spacer()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(tintColor.gradient)
                        .frame(width: max(proxy.size.width * progress, 8))
                }
            }
            .frame(height: 8)

            HStack(spacing: 0) {
                ForEach(Array(Self.weekdays.enumerated()), id: \.element) { index, day in
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(index < completedDays ? tintColor : Color.white.opacity(0.10))
                            if index < completedDays {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 16, height: 16)

                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(index < completedDays ? PremiumTheme.textPrimary : PremiumTheme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var completedDays: Int {
        min(streakDays, Self.weekdays.count)
    }

    private static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}
