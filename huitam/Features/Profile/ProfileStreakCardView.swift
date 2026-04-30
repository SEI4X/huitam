import SwiftUI

struct ProfileStreakCardView: View {
    @Environment(\.appTintColor) private var tintColor

    let streakDays: Int
    let goal: Int

    private var progress: Double {
        min(Double(streakDays) / Double(goal), 1)
    }

    var body: some View {
        HStack(spacing: 14) {
            iconPanel
            progressPanel
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var iconPanel: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.16))
                    .frame(width: 60, height: 60)
                Image(systemName: "flame.fill")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(tintColor)
            }

            Text("\(streakDays) days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Steps streak")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 88)
        .padding(.vertical, 12)
        .background(tintColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streakDays)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("/\(goal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(tintColor.gradient)
                        .frame(width: max(proxy.size.width * progress, 8))
                }
            }
            .frame(height: 8)

            HStack(spacing: 6) {
                ForEach(Array(Self.weekdays.enumerated()), id: \.element) { index, day in
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .fill(index < completedDays ? tintColor : Color(.tertiarySystemFill))
                            if index < completedDays {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 16, height: 16)

                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(index < completedDays ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(width: 24)
                    }
                    .frame(width: 24)
                }
            }
        }
    }

    private var completedDays: Int {
        min(streakDays, Self.weekdays.count)
    }

    private static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}
