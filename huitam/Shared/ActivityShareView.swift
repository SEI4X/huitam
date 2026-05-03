import SwiftUI
import UIKit

struct ActivityShareItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

struct ActivityShareTextItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
}

struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
