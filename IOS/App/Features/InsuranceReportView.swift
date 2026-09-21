import SwiftUI
import UIKit
import LiquorData
import LiquorEngine

/// The collection as a PDF for an insurer or an executor.
///
/// Every line is what the owner recorded -- what was paid, when, where, and
/// a photo when there is one -- and the caveat that it is not an appraisal
/// sits on every page. The research lists this as one of the three things
/// people will pay for; the paywall does not exist yet, so for now it is
/// simply here.
struct InsuranceReportView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var document: InsuranceReport.Document?
    @State private var pdfURL: URL?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let document {
                    summary(document)
                }

                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        HStack(spacing: Space.s) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share the PDF")
                        }
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }
                } else {
                    Button(action: build) {
                        Text("Build the report")
                            .font(TypeScale.headline())
                            .foregroundStyle(Palette.onGold)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }
                    .disabled((document?.bottleCount ?? 0) == 0)
                    .opacity((document?.bottleCount ?? 0) == 0 ? 0.5 : 1)
                }

                Text(InsuranceReport.caveat + " Bottles on the shelf only; finished "
                     + "bottles are left out. Photos are included where you added one.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Insurance report")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .alert("Could not build the report", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func summary(_ document: InsuranceReport.Document) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("What goes in")
                .padding(.bottom, Space.xs)
            FactRow(label: "Bottles", value: "\(document.bottleCount)")
            FactRow(label: "With a price", value: "\(document.pricedCount)")
            FactRow(label: "Without", value: "\(document.unpricedCount)")
            FactRow(label: "Paid in total", value: Money.short(document.paidTotalCents), isLast: true)
        }
    }

    private func load() {
        do {
            let shelf = try env.bottles.summaries()
            document = InsuranceReport.build(shelf.map { line(for: $0) })
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func line(for summary: BottleSummary) -> InsuranceReport.Line {
        let bottle = summary.bottle
        return InsuranceReport.Line(
            id: bottle.id,
            name: env.name(for: bottle),
            distillery: env.distillery(for: bottle),
            detail: InsuranceReport.detail(
                barrel: bottle.barrelNumber,
                batch: bottle.batchNumber,
                pickStore: bottle.isStorePick ? bottle.pickStore : nil,
                bottleNumber: bottle.bottleNumber,
                bottlesInBatch: bottle.bottlesInBatch,
                topperLetter: bottle.topperLetter),
            sizeMilliliters: bottle.volumeMl,
            status: bottle.isOpen
                ? "Open · \(Int(summary.status.remainingMilliliters.rounded())) ml left"
                : "Sealed",
            purchasedAt: bottle.purchaseDate.map { Date(timeIntervalSince1970: Double($0) / 1000) },
            store: bottle.purchaseStore,
            paidCents: bottle.purchasePriceCents,
            photoFile: bottle.photoFile,
            storageLocation: bottle.storageLocation)
    }

    private func build() {
        guard let document else { return }
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("collection-inventory.pdf")
            try InsuranceReportPDF.write(document, photos: env.photos, to: url)
            pdfURL = url
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Draws the document. US Letter, one line per bottle with a thumbnail,
/// the caveat in the footer of every page, totals on the last.
enum InsuranceReportPDF {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48
    private static let rowHeight: CGFloat = 64
    private static let thumb: CGFloat = 48

    static func write(_ document: InsuranceReport.Document, photos: BottlePhotoStore?, to url: URL) throws {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let dateText = document.generatedAt.formatted(date: .long, time: .shortened)

        let data = renderer.pdfData { context in
            var pageNumber = 0
            var y: CGFloat = 0

            func startPage() {
                context.beginPage()
                pageNumber += 1
                y = margin
                draw(document.title, at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 18))
                y += 24
                draw("Generated \(dateText)", at: CGPoint(x: margin, y: y),
                     font: .systemFont(ofSize: 10), color: .darkGray)
                y += 22
                rule(at: y)
                y += 10
                footer(page: pageNumber, caveat: document.caveat)
            }

            startPage()
            for line in document.lines {
                if y + rowHeight > page.height - margin - 30 {
                    startPage()
                }
                drawLine(line, photos: photos, at: y)
                y += rowHeight
                rule(at: y - 6, light: true)
            }

            if y + 90 > page.height - margin - 30 { startPage() }
            y += 12
            rule(at: y)
            y += 12
            draw("Bottles on the shelf: \(document.bottleCount)", at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 11))
            y += 16
            draw("With a recorded price: \(document.pricedCount)   Without: \(document.unpricedCount)",
                 at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 11))
            y += 16
            draw("Total paid, priced bottles: \(Money.short(document.paidTotalCents))",
                 at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 12))
        }
        try data.write(to: url, options: .atomic)
    }

    private static func drawLine(_ line: InsuranceReport.Line, photos: BottlePhotoStore?, at y: CGFloat) {
        var x = margin
        if let image = BottlePhoto.load(line.photoFile, from: photos),
           let context = UIGraphicsGetCurrentContext() {
            let rect = CGRect(x: x, y: y, width: thumb * 0.72, height: thumb)
            context.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 4).addClip()
            image.draw(in: aspectFill(image.size, in: rect))
            context.restoreGState()
        }
        x += thumb * 0.72 + 10

        var textY = y
        let title = line.distillery.map { "\($0) — \(line.name)" } ?? line.name
        draw(title, at: CGPoint(x: x, y: textY), font: .boldSystemFont(ofSize: 11), width: 360)
        textY += 14
        if let detail = line.detail {
            draw(detail, at: CGPoint(x: x, y: textY), font: .systemFont(ofSize: 9), color: .darkGray, width: 360)
            textY += 12
        }
        var facts = ["\(Int(line.sizeMilliliters.rounded())) ml", line.status]
        if let location = line.storageLocation { facts.append(location) }
        draw(facts.joined(separator: " · "), at: CGPoint(x: x, y: textY),
             font: .systemFont(ofSize: 9), color: .darkGray, width: 360)
        textY += 12
        var purchase: [String] = []
        if let at = line.purchasedAt { purchase.append(at.formatted(date: .abbreviated, time: .omitted)) }
        if let store = line.store { purchase.append(store) }
        if !purchase.isEmpty {
            draw(purchase.joined(separator: " · "), at: CGPoint(x: x, y: textY),
                 font: .systemFont(ofSize: 9), color: .darkGray, width: 360)
        }

        let price = line.paidCents.map(Money.short) ?? "—"
        draw(price, at: CGPoint(x: page.width - margin - 80, y: y),
             font: .boldSystemFont(ofSize: 11), width: 80, alignment: .right)
    }

    private static func footer(page number: Int, caveat: String) {
        let y = page.height - margin + 6
        rule(at: y - 8, light: true)
        draw(caveat, at: CGPoint(x: margin, y: y), font: .italicSystemFont(ofSize: 8),
             color: .darkGray, width: page.width - margin * 2 - 60)
        draw("Page \(number)", at: CGPoint(x: page.width - margin - 50, y: y),
             font: .systemFont(ofSize: 8), color: .darkGray, width: 50, alignment: .right)
    }

    private static func rule(at y: CGFloat, light: Bool = false) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: page.width - margin, y: y))
        (light ? UIColor.lightGray.withAlphaComponent(0.5) : UIColor.darkGray).setStroke()
        path.lineWidth = light ? 0.5 : 1
        path.stroke()
    }

    private static func draw(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor = .black,
        width: CGFloat = 516,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(
            in: CGRect(x: point.x, y: point.y, width: width, height: font.lineHeight + 2),
            withAttributes: attributes)
    }

    private static func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        let scale = max(rect.width / max(size.width, 1), rect.height / max(size.height, 1))
        let w = size.width * scale
        let h = size.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
