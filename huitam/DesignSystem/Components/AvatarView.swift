import SwiftUI

struct AvatarView: View {
    let systemImage: String
    let size: CGFloat
    var seed: UUID?

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            Image(systemName: avatarSymbol)
                .font(.system(size: size * 0.56, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary.opacity(0.58))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var avatarSymbol: String {
        systemImage.contains("person") ? "person.fill" : systemImage
    }

    private var backgroundColor: Color {
        let palette: [Color] = [
            Color(red: 0.88, green: 0.94, blue: 1.0),
            Color(red: 0.91, green: 0.96, blue: 0.90),
            Color(red: 0.98, green: 0.92, blue: 0.96),
            Color(red: 0.95, green: 0.93, blue: 1.0),
            Color(red: 1.0, green: 0.94, blue: 0.86),
            Color(red: 0.90, green: 0.96, blue: 0.96)
        ]
        guard let seed else {
            return Color(.tertiarySystemFill)
        }
        let index = seed.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        } % palette.count
        return palette[index]
    }
}
