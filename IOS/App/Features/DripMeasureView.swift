import SwiftUI
import PhotosUI
import LiquorData
import LiquorEngine

/// Measure the wax drip on a Maker's Mark from a photo.
///
/// Four taps on the picture -- the base of the bottle, the top of the cap,
/// the bottom edge of the wax band, the tip of the longest drip -- and the
/// drip comes out as a fraction of the bottle's height, which is the
/// number that survives different phones and distances. Type the bottle's
/// real height and it is millimetres as well. The app never guesses a
/// height.
///
/// The measuring is the engine's; this is the tapping. Nothing is written
/// until Save.
struct DripMeasureView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let bottleId: String
    let bottleName: String
    var existingColor: WaxDrip.Color?
    var onSave: (() -> Void)?

    private enum Step: Int, CaseIterable {
        case base, top, waxEdge, dripTip

        var prompt: String {
            switch self {
            case .base: return "Tap the base of the bottle"
            case .top: return "Tap the top of the cap"
            case .waxEdge: return "Tap the bottom edge of the wax band"
            case .dripTip: return "Tap the tip of the longest drip"
            }
        }
    }

    @State private var image: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var isTakingPhoto = false
    @State private var points: [CGPoint] = []
    @State private var color: WaxDrip.Color = .red
    @State private var heightText = ""
    @State private var error: String?

    private var step: Step? { Step(rawValue: points.count) }

    private var measurement: WaxDrip.Measurement? {
        guard points.count == 4 else { return nil }
        return WaxDrip.measure(
            bottleBase: wax(points[0]), bottleTop: wax(points[1]),
            waxEdge: wax(points[2]), dripTip: wax(points[3]),
            bottleHeightMillimeters: Double(heightText))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    SectionLabel(bottleName)
                    Text("Measure the drip")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                }

                if let image {
                    picture(image)
                    guidance
                } else {
                    pickers
                }

                if let measurement {
                    result(measurement)
                    colourRow
                    heightRow
                    saveButton(measurement)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Wax")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .onAppear { if let existingColor { color = existingColor } }
        .sheet(isPresented: $isTakingPhoto) {
            ImagePicker(source: .camera) { picked in
                image = picked
                points = []
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    image = picked
                    points = []
                } else {
                    error = "That photo could not be loaded."
                }
                libraryItem = nil
            }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Pieces

    private var pickers: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("A photo of the whole bottle, straight on, with the drip in view. "
                 + "The wax and the bottle are measured on the same picture, so "
                 + "distance and phone do not matter.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { isTakingPhoto = true } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "camera")
                    Text("Take a photo")
                }
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                HStack(spacing: Space.s) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from library")
                }
                .font(TypeScale.headline())
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    /// The photo with the two lines drawn on it. Taps land in the image's
    /// own coordinate space, which is all the measurement needs.
    private func picture(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geometry in
                    Canvas { context, _ in
                        if points.count >= 2 {
                            var bottle = Path()
                            bottle.move(to: points[0]); bottle.addLine(to: points[1])
                            context.stroke(bottle, with: .color(.white.opacity(0.9)), lineWidth: 2)
                        }
                        if points.count >= 4 {
                            var drip = Path()
                            drip.move(to: points[2]); drip.addLine(to: points[3])
                            context.stroke(drip, with: .color(Color(red: 0.85, green: 0.15, blue: 0.15)), lineWidth: 3)
                        }
                        for (index, point) in points.enumerated() {
                            let dot = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                            context.fill(dot, with: .color(index < 2 ? .white : Color(red: 0.85, green: 0.15, blue: 0.15)))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard points.count < 4 else { return }
                        let clamped = CGPoint(
                            x: min(max(0, location.x), geometry.size.width),
                            y: min(max(0, location.y), geometry.size.height))
                        points.append(clamped)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity)
    }

    private var guidance: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(step?.prompt ?? "Measured. Adjust below, or start over.")
                .font(TypeScale.body())
                .foregroundStyle(step == nil ? Palette.good : Palette.gold)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if !points.isEmpty {
                Button {
                    points.removeLast()
                } label: {
                    Text("Undo")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .frame(minHeight: Space.tapTarget)
                }
            }
            Button {
                image = nil
                points = []
            } label: {
                Text("New photo")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .frame(minHeight: Space.tapTarget)
            }
        }
    }

    private func result(_ measurement: WaxDrip.Measurement) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text("\(measurement.percent)%")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.gold)
                Text("of the bottle's height")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }
            if let mm = measurement.millimeters {
                Text(String(format: "About %.0f mm, from the height you typed", mm))
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
    }

    private var colourRow: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Wax colour")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(WaxDrip.Color.allCases, id: \.self) { option in
                        Button { color = option } label: {
                            Text(option.label)
                                .font(TypeScale.secondary())
                                .foregroundStyle(color == option ? Palette.onGold : Palette.textSecondary)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(color == option ? Palette.gold : Palette.surfaceRaised))
                        }
                    }
                }
            }
        }
    }

    private var heightRow: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Bottle height, if you measured it")
            TextField("mm, base to cap top", text: $heightText)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, Space.m)
                .frame(minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
            Text("Optional. With it the drip is in millimetres as well; without it, "
                 + "the fraction is the number that compares between bottles.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func saveButton(_ measurement: WaxDrip.Measurement) -> some View {
        Button {
            save(measurement)
        } label: {
            Text("Save the measurement")
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
        }
    }

    // MARK: - Work

    private func wax(_ point: CGPoint) -> WaxDrip.Point {
        WaxDrip.Point(x: point.x, y: point.y)
    }

    private func save(_ measurement: WaxDrip.Measurement) {
        do {
            try env.bottles.setWax(
                bottleId: bottleId,
                color: color,
                dripFraction: measurement.fraction,
                dripLengthMm: measurement.millimeters)
            onSave?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
