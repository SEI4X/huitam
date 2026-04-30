import SwiftUI

struct StudyCardRowView: View {
    let card: StudyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.frontText)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(card.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(card.backText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if card.note.isEmpty == false {
                Text(card.note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
