import SwiftUI

struct StudyCardRowView: View {
    let card: StudyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.frontText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PremiumTheme.textPrimary)
                Spacer()
                Text(card.type.displayName)
                    .font(.caption)
                    .foregroundStyle(PremiumTheme.textTertiary)
            }
            Text(card.backText)
                .font(.subheadline)
                .foregroundStyle(PremiumTheme.textSecondary)
            if card.note.isEmpty == false {
                Text(card.note)
                    .font(.caption)
                    .foregroundStyle(PremiumTheme.textTertiary)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }
}
