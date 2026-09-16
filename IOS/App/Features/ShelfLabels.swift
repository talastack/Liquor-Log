import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import LiquorEngine
import LiquorData

/// A QR code as an image, for a link. Black on white, because it is
/// going onto a sticker or a card and a camera has to read it.
enum QRCode {
    static func image(for text: String, side: CGFloat = 240) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A sheet of stickers for the shelf: your number, the name, and a code
/// that opens the bottle in the app when the phone's camera reads it.
///
/// Collectors number their bottles -- "your number" is a field for that
/// reason -- and the sticker is what bridges the shelf to the record.
/// US Letter, thirty labels a sheet in the 2⅝ × 1 inch grid of the common
/// address-label sheets, bottles ordered by your number then by name.
enum ShelfLabelsPDF {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let columns = 3, rows = 10
    private static let labelWidth: CGFloat = 189, labelHeight: CGFloat = 72
    private static let sideMargin: CGFloat = 13.5, topMargin: CGFloat = 36
    private static let gutter: CGFloat = 9

    struct Label {
        let number: Int?
        let name: String
        let detail: String?
        let link: URL
    }

    static func write(_ labels: [Label], to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            for (index, label) in labels.enumerated() {
                let slot = index % (columns * rows)
                if slot == 0 { context.beginPage() }
                let column = slot % columns
                let row = slot / columns
                let origin = CGPoint(
                    x: sideMargin + CGFloat(column) * (labelWidth + gutter),
                    y: topMargin + CGFloat(row) * labelHeight)
                draw(label, in: CGRect(origin: origin, size: CGSize(width: labelWidth, height: labelHeight)))
            }
        }
        try data.write(to: url, options: .atomic)
    }

    private static func draw(_ label: Label, in frame: CGRect) {
        let inset = frame.insetBy(dx: 6, dy: 6)
        let qrSide = inset.height
        if let qr = QRCode.image(for: label.link.absoluteString, side: qrSide * 4) {
            qr.draw(in: CGRect(x: inset.minX, y: inset.minY, width: qrSide, height: qrSide))
        }
        let x = inset.minX + qrSide + 8
        var y = inset.minY
        let textWidth = inset.maxX - x
        if let number = label.number {
            let text = NSAttributedString(string: "#\(number)", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.black,
            ])
            text.draw(at: CGPoint(x: x, y: y))
            y += 24
        }
        let name = NSAttributedString(string: label.name, attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: UIColor.black,
        ])
        name.draw(with: CGRect(x: x, y: y, width: textWidth, height: 26),
                  options: [.usesLineFragmentOrigin], context: nil)
        y += 26
        if let detail = label.detail {
            let text = NSAttributedString(string: detail, attributes: [
                .font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray,
            ])
            text.draw(with: CGRect(x: x, y: y, width: textWidth, height: 12),
                      options: [.usesLineFragmentOrigin], context: nil)
        }
    }
}

/// Builds the sheet from the shelf and hands it to the share sheet.
struct ShelfLabelsView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var url: URL?
    @State private var count = 0
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Shelf labels")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("A sheet of stickers: your number, the name, and a code the camera reads to open the bottle here. Thirty to a US Letter sheet, the 2⅝ × 1 inch address-label grid.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let url {
                    ShareLink(item: url) {
                        Text("Share the PDF — \(count) \(count == 1 ? "label" : "labels")")
                            .font(TypeScale.headline())
                            .foregroundStyle(Palette.onGold)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }
                    Text("Print at 100%, no scaling. Bottles you have numbered come first.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                } else if count == 0, error == nil {
                    Text("Nothing on the shelf to label yet.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Shelf labels")
        .navigationBarTitleDisplayMode(.inline)
        .task { build() }
        .alert("Could not build the sheet", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func build() {
        let shelf = ((try? env.bottles.summaries()) ?? [])
            .sorted { a, b in
                switch (a.bottle.shelfNumber, b.bottle.shelfNumber) {
                case let (x?, y?): return x < y
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none):
                    return env.name(for: a.bottle).localizedCaseInsensitiveCompare(env.name(for: b.bottle)) == .orderedAscending
                }
            }
        count = shelf.count
        guard !shelf.isEmpty else { return }
        let labels = shelf.map { summary in
            ShelfLabelsPDF.Label(
                number: summary.bottle.shelfNumber,
                name: env.name(for: summary.bottle),
                detail: summary.bottle.releaseLabel ?? env.distillery(for: summary.bottle),
                link: URL(string: "liquorlog://bottle/\(summary.bottle.id)")!)
        }
        do {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-labels.pdf")
            try ShelfLabelsPDF.write(labels, to: file)
            url = file
        } catch {
            self.error = error.localizedDescription
        }
    }
}
