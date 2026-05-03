import SwiftUI

enum PremiumTheme {
    static let background = Color.black
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let textTertiary = Color.white.opacity(0.42)
    static let surface = Color.white.opacity(0.075)
    static let surfaceStrong = Color.white.opacity(0.12)
    static let surfacePressed = Color.white.opacity(0.16)
    static let hairline = Color.white.opacity(0.11)
    static let blue = Color(red: 0.27, green: 0.48, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.20, blue: 0.54)

    static var calmGradient: LinearGradient {
        LinearGradient(
            colors: [
                PremiumTheme.blue.opacity(0.74),
                PremiumTheme.pink.opacity(0.68)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum PremiumGlowPosition {
    case top
    case bottom
}

struct PremiumScreenBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var glowPosition: PremiumGlowPosition = .bottom
    var intensity: Double = 1
    var isAnimated = false

    var body: some View {
        GeometryReader { proxy in
            if isAnimated && reduceMotion == false {
                TimelineView(.animation) { timeline in
                    background(size: proxy.size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                background(size: proxy.size, time: 0)
            }
        }
    }

    private func background(size: CGSize, time: TimeInterval) -> some View {
        let drift = CGFloat(sin(time * 0.38)) * 72
        let verticalDrift = CGFloat(cos(time * 0.31)) * 42
        let counterDrift = CGFloat(cos(time * 0.24)) * 58
        let breathingScale = 1 + CGFloat(sin(time * 0.42)) * 0.08
        let secondaryScale = 1 + CGFloat(cos(time * 0.36)) * 0.07
        let width = size.width
        let height = size.height
        let glowDiameter = max(width, height) * 0.84
        let bandHeight = max(260, height * 0.34)

        return ZStack {
            PremiumTheme.background

            LinearGradient(
                colors: [
                    Color.white.opacity(0.045 * intensity),
                    Color.clear,
                    PremiumTheme.blue.opacity(0.10 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width * 1.6, height: height * 1.35)
            .hueRotation(.degrees(sin(time * 0.16) * 8))
            .offset(x: counterDrift * 0.18, y: verticalDrift * 0.16)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PremiumTheme.blue.opacity(0.22 * intensity),
                            PremiumTheme.pink.opacity(0.10 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: glowDiameter * 0.52
                    )
                )
                .blur(radius: 42)
                .frame(width: glowDiameter, height: glowDiameter)
                .scaleEffect(secondaryScale)
                .position(x: width * 0.12 + counterDrift, y: height * 0.12 + verticalDrift * 0.36)
                .allowsHitTesting(false)

            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            PremiumTheme.pink.opacity(0.46 * intensity),
                            PremiumTheme.blue.opacity(0.38 * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: max(width, bandHeight) * 0.62
                    )
                )
                .blur(radius: 52)
                .frame(width: width * 1.8, height: bandHeight)
                .scaleEffect(breathingScale)
                .hueRotation(.degrees(cos(time * 0.18) * 10))
                .position(
                    x: width * 0.5 + drift,
                    y: glowPosition == .bottom
                        ? height + bandHeight * 0.18 + verticalDrift
                        : -bandHeight * 0.18 + verticalDrift
                )
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

struct PremiumSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var strength: Double = 1

    func body(content: Content) -> some View {
        content
            .background(PremiumTheme.surface.opacity(strength), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PremiumTheme.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 12, y: 7)
    }
}

extension View {
    func premiumSurface(cornerRadius: CGFloat = 22, strength: Double = 1) -> some View {
        modifier(PremiumSurfaceModifier(cornerRadius: cornerRadius, strength: strength))
    }

    func premiumListRow(cornerRadius: CGFloat = 22) -> some View {
        padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .premiumSurface(cornerRadius: cornerRadius)
    }

    func premiumScrollBackground(glowPosition: PremiumGlowPosition = .bottom, intensity: Double = 1) -> some View {
        scrollContentBackground(.hidden)
            .background {
                PremiumScreenBackground(glowPosition: glowPosition, intensity: intensity)
                    .ignoresSafeArea()
            }
            .preferredColorScheme(.dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func premiumEntrance(delay: Double, edge: Edge = .bottom) -> some View {
        modifier(PremiumEntranceModifier(delay: delay, edge: edge))
    }
}

private struct PremiumEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    let delay: Double
    let edge: Edge

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.965)
            .offset(offset)
            .onAppear {
                isVisible = reduceMotion
                guard reduceMotion == false else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                        isVisible = true
                    }
                }
            }
    }

    private var offset: CGSize {
        guard isVisible == false, reduceMotion == false else { return .zero }
        switch edge {
        case .top:
            return CGSize(width: 0, height: -18)
        case .bottom:
            return CGSize(width: 0, height: 24)
        case .leading:
            return CGSize(width: -22, height: 0)
        case .trailing:
            return CGSize(width: 22, height: 0)
        }
    }
}
