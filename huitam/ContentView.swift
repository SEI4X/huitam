import SwiftUI

struct ContentView: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        ChatsListView(container: dependencies)
    }
}

#Preview {
    ContentView()
        .environment(\.appDependencies, .mock())
}
