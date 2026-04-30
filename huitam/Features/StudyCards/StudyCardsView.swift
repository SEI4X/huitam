import SwiftUI

struct StudyCardsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: StudyCardsViewModel

    init(container: AppDependencyContainer) {
        _viewModel = State(initialValue: StudyCardsViewModel(studyCardService: container.studyCardService))
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: Binding(
                    get: { viewModel.selectedFilter },
                    set: { filter in
                        withAnimation(AppMotion.quickStateChange(reduceMotion: reduceMotion)) {
                            viewModel.selectedFilter = filter
                        }
                    }
                )) {
                    ForEach(StudyCardFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                ForEach(viewModel.visibleCards) { card in
                    StudyCardRowView(card: card)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .onDelete { offsets in
                    for index in offsets {
                        let card = viewModel.visibleCards[index]
                        Task { await viewModel.remove(card) }
                    }
                }
            }
            .overlay {
                if viewModel.visibleCards.isEmpty {
                    ContentUnavailableView {
                        Label("No Cards", systemImage: "graduationcap")
                    } description: {
                        Text("Saved words and phrases from chats will appear here.")
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.visibleCards)
        }
    }
}
