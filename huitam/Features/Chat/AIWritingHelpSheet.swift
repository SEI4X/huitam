import SwiftUI

struct AIWritingHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestion: String
    let onUseSuggestion: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(suggestion.isEmpty ? "Ask for a phrase and keep writing." : suggestion)
                    .font(.title3)
                    .textSelection(.enabled)

                Button {
                    onUseSuggestion()
                    dismiss()
                } label: {
                    Label("Use Suggestion", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(suggestion.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("AI Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
