import SwiftUI

struct MessageAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTintColor) private var tintColor

    let analysis: MessageAnalysis
    let onToggleToken: (MessageToken) -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    selectionSummary
                    wordsSection
                    phrasesSection
                    grammarSection
                }
                .padding(16)
            }
            .background {
                PremiumScreenBackground(glowPosition: .top, intensity: 0.68)
                    .ignoresSafeArea()
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .disabled(analysis.selectedTokenIDs.isEmpty)
                }
            }
        }
    }

    private var selectionSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.title3)
                .foregroundStyle(tintColor)
                .frame(width: 36, height: 36)
                .background(tintColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Select words")
                    .font(.headline)
                    .foregroundStyle(PremiumTheme.textPrimary)
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(PremiumTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .premiumSurface(cornerRadius: 20, strength: 1.15)
    }

    private var summaryText: String {
        let selectedCount = analysis.selectedTokenIDs.count
        if selectedCount == 0 {
            return "Tap words below to save them for study."
        }
        return "\(selectedCount) selected for study"
    }

    private var wordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Words")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PremiumTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                ForEach(analysis.tokens) { token in
                    MessageTokenCard(
                        token: token,
                        isSelected: analysis.selectedTokenIDs.contains(token.id),
                        reduceMotion: reduceMotion
                    ) {
                        withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
                            onToggleToken(token)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var phrasesSection: some View {
        if analysis.phraseSuggestions.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("Phrases")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PremiumTheme.textSecondary)

                VStack(spacing: 8) {
                    ForEach(analysis.phraseSuggestions, id: \.self) { phrase in
                        HStack {
                            Text(phrase)
                                .font(.body)
                                .foregroundStyle(PremiumTheme.textPrimary)
                            Spacer()
                            Image(systemName: "quote.bubble")
                                .foregroundStyle(PremiumTheme.textTertiary)
                        }
                        .padding(12)
                        .premiumSurface(cornerRadius: 16, strength: 0.9)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var grammarSection: some View {
        if analysis.grammarNotes.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("Grammar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PremiumTheme.textSecondary)

                VStack(spacing: 8) {
                    ForEach(analysis.grammarNotes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(note.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(PremiumTheme.textPrimary)
                                Spacer()
                                Image(systemName: "text.book.closed")
                                    .foregroundStyle(PremiumTheme.textTertiary)
                            }
                            Text(note.explanation)
                                .font(.subheadline)
                                .foregroundStyle(PremiumTheme.textSecondary)
                        }
                        .padding(12)
                        .premiumSurface(cornerRadius: 16, strength: 0.9)
                    }
                }
            }
        }
    }
}

private struct MessageTokenCard: View {
    @Environment(\.appTintColor) private var tintColor

    let token: MessageToken
    let isSelected: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(token.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PremiumTheme.textPrimary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(PremiumTheme.textTertiary))
                        .contentTransition(.symbolEffect(.replace))
                }

                Text(token.translation)
                    .font(.subheadline)
                    .foregroundStyle(PremiumTheme.textSecondary)

                Text(token.partOfSpeech)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(PremiumTheme.textTertiary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isSelected ? tintColor.opacity(0.18) : Color.white.opacity(0.08)), in: Capsule())
            }
            .padding(12)
            .background(PremiumTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tintColor.opacity(0.55) : PremiumTheme.hairline, lineWidth: 1)
            }
            .scaleEffect(isSelected && reduceMotion == false ? 1.015 : 1)
        }
        .buttonStyle(.plain)
    }
}
