import SwiftUI

struct ProfileActivityChartView: View {
    @Environment(\.appTintColor) private var tintColor
    @State private var selectedIndex: Int?

    let points: [DailyMessagePoint]

    private var activeIndex: Int? {
        selectedIndex ?? points.indices.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            GeometryReader { proxy in
                let chartPoints = normalizedPoints(in: proxy.size)
                ZStack(alignment: .topLeading) {
                    ProfileChartFill(points: chartPoints)
                        .fill(
                            LinearGradient(
                                colors: [tintColor.opacity(0.30), tintColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    ProfileChartLine(points: chartPoints)
                        .stroke(
                            LinearGradient(
                                colors: [tintColor.opacity(0.60), tintColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )

                    if let activeIndex, chartPoints.indices.contains(activeIndex) {
                        selectionOverlay(point: chartPoints[activeIndex], pointData: points[activeIndex], size: proxy.size)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateSelection(for: value.location.x, width: proxy.size.width)
                        }
                )
            }
            .frame(height: 136)
            .sensoryFeedback(.selection, trigger: selectedIndex)

            dateAxis
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Messages per day")
                    .font(.subheadline.weight(.semibold))
                if let activeIndex, points.indices.contains(activeIndex) {
                    Text(shortDateFormatter.string(from: points[activeIndex].date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let activeIndex, points.indices.contains(activeIndex) {
                Text("\(points[activeIndex].count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tintColor)
                    .contentTransition(.numericText())
            }
        }
    }

    private var dateAxis: some View {
        HStack {
            ForEach(points) { point in
                Text(weekdayFormatter.string(from: point.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func selectionOverlay(point: CGPoint, pointData: DailyMessagePoint, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(tintColor.opacity(0.18))
                .frame(width: 1, height: size.height)
                .position(x: point.x, y: size.height / 2)

            Circle()
                .fill(.background)
                .frame(width: 17, height: 17)
                .overlay {
                    Circle()
                        .fill(tintColor)
                        .frame(width: 9, height: 9)
                }
                .shadow(color: tintColor.opacity(0.38), radius: 8)
                .position(point)

            Text("\(pointData.count) messages")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .position(x: clampedCalloutX(for: point.x, width: size.width), y: max(point.y - 26, 14))
        }
    }

    private func clampedCalloutX(for x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 58), width - 58)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard points.isEmpty == false else { return [] }
        let maxCount = max(points.map(\.count).max() ?? 1, 1)
        let step = points.count == 1 ? 0 : size.width / CGFloat(points.count - 1)
        return points.enumerated().map { index, point in
            let x = CGFloat(index) * step
            let ratio = CGFloat(point.count) / CGFloat(maxCount)
            let y = size.height - (ratio * (size.height - 18)) - 9
            return CGPoint(x: x, y: y)
        }
    }

    private func updateSelection(for x: CGFloat, width: CGFloat) {
        guard points.isEmpty == false else { return }
        let step = points.count == 1 ? width : width / CGFloat(points.count - 1)
        let index = Int(round(x / step))
        selectedIndex = min(max(index, 0), points.count - 1)
    }

    private var accessibilitySummary: String {
        guard let activeIndex, points.indices.contains(activeIndex) else {
            return "Messages per day chart"
        }
        let point = points[activeIndex]
        return "\(point.count) messages on \(shortDateFormatter.string(from: point.date))"
    }

    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }
}

private struct ProfileChartLine: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        smoothPath(points: points)
    }
}

private struct ProfileChartFill: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = smoothPath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: first.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private func smoothPath(points: [CGPoint]) -> Path {
    var path = Path()
    guard points.count > 1, let first = points.first else {
        if let point = points.first {
            path.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        }
        return path
    }

    path.move(to: first)
    for index in 0..<(points.count - 1) {
        let current = points[index]
        let next = points[index + 1]
        let previous = index == 0 ? current : points[index - 1]
        let following = index + 2 < points.count ? points[index + 2] : next
        let control1 = CGPoint(
            x: current.x + (next.x - previous.x) / 6,
            y: current.y + (next.y - previous.y) / 6
        )
        let control2 = CGPoint(
            x: next.x - (following.x - current.x) / 6,
            y: next.y - (following.y - current.y) / 6
        )
        path.addCurve(to: next, control1: control1, control2: control2)
    }

    return path
}
