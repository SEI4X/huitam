import CoreImage.CIFilterBuiltins
import SwiftUI

struct InviteQRCodeView: View {
    let url: URL

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Invite QR Code")
            } else {
                ProgressView()
            }
        }
        .frame(width: 180, height: 180)
        .padding(.vertical, 8)
        .task(id: url) {
            image = InviteQRCodeGenerator.image(from: url.absoluteString)
        }
    }
}

enum InviteQRCodeGenerator {
    private static let context = CIContext()

    static func image(from text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
