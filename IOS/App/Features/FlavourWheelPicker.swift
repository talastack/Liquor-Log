import SwiftUI
import LiquorData
import LiquorEngine

/// The bourbon wheel. Tap a family, tap descriptors, they attach to one stage.
///
/// Families are the familiar generic ones. The structure underneath them is
/// ours, grouped by where a flavour comes from — see
/// `docs/06-flavour-wheel-provenance.md`.
struct FlavourWheelPicker: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let stage: TastingStage
    let onDone: ([String]) -> Void

    @State private var familyIndex = 0
    @State private var selected: [String]

    init(stage: TastingStage, selected: [String], onDone: @escaping ([String]) -> Void) {
        self.stage = stage
        self.onDone = onDone
        _selected = State(initialValue: selected)
    }

    private var families: [FlavorFamily] { env.wheel.families }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                wheel
                tray
                summary
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 48)
        }
        .background(Palette.background)
        .navigationTitle("Adding to the \(stage.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone(selected) }
                    .foregroundStyle(Palette.gold)
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Wheel

    private var wheel: some View {
        ZStack {
            ForEach(Array(families.enumerated()), id: \.offset) { index, family in
                let isActive = index == familyIndex
                WheelWedge(index: index, count: families.count)
                    .fill(isActive ? Palette.gold : Palette.surfaceRaised)
                    .overlay(
                        WheelWedge(index: index, count: families.count)
                            .stroke(Palette.background, lineWidth: 2))
                    .onTapGesture { familyIndex = index }
                    .accessibilityLabel(family.label)
                    .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)

                WedgeLabel(index: index, count: families.count) {
                    Text(family.label)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(isActive ? Palette.onGold : Palette.textSecondary)
                        .allowsHitTesting(false)
                }
            }

            Circle()
                .fill(Palette.surface)
                .overlay(Circle().stroke(Palette.line, lineWidth: 1))
                .frame(width: 118, height: 118)

            VStack(spacing: 2) {
                Text(stage.rawValue.uppercased())
                    .font(TypeScale.caption())
                    .foregroundStyle(Palette.textMuted)
                Text("\(selected.count)")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.gold)
            }
            .allowsHitTesting(false)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Descriptors

    private var tray: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if families.indices.contains(familyIndex) {
                let family = families[familyIndex]
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(family.label)
                    Spacer()
                    Text("Tap to add to the \(stage.rawValue)")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }

                // Sub-grouped rather than one flat run. A family can hold
                // forty descriptors now, and nobody opening "Fruit" wants to
                // scroll past thirty entries to reach "Lemon". The groups are
                // in data order, most common note first, so alphabetising
                // would bury "Caramel" under "Chocolate".
                ForEach(family.groups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(group.name)
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 118), spacing: Space.s)],
                            spacing: Space.s
                        ) {
                            ForEach(group.descriptors) { descriptor in
                                chip(descriptor)
                            }
                        }
                    }
                    .padding(.bottom, Space.s)
                }
            }
        }
    }

    private func chip(_ descriptor: FlavorDescriptor) -> some View {
        let isOn = selected.contains(descriptor.key)
        return Button {
            if let at = selected.firstIndex(of: descriptor.key) {
                selected.remove(at: at)
            } else {
                selected.append(descriptor.key)
            }
        } label: {
            Text(descriptor.label)
                .font(TypeScale.secondary())
                .foregroundStyle(isOn ? Palette.gold : Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                .padding(.horizontal, Space.s)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(isOn ? Palette.surface : Palette.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(isOn ? Palette.gold : .clear, lineWidth: 1))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("On the \(stage.rawValue)")
            Text(selected.isEmpty
                 ? "Nothing yet"
                 : selected.compactMap { env.wheel.descriptor($0)?.label ?? $0 }
                    .joined(separator: ", "))
                .font(TypeScale.body())
                .foregroundStyle(selected.isEmpty ? Palette.textMuted : Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One wedge of the wheel, from the top, clockwise.
struct WheelWedge: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.46
        let step = 360.0 / Double(count)
        let start = Angle(degrees: -90 + step * Double(index))
        let end = Angle(degrees: start.degrees + step)

        var path = Path()
        path.addArc(center: centre, radius: outer, startAngle: start, endAngle: end,
                    clockwise: false)
        path.addArc(center: centre, radius: inner, startAngle: end, endAngle: start,
                    clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// Places a label at the middle of a wedge.
struct WedgeLabel<Content: View>: View {
    let index: Int
    let count: Int
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width, geo.size.height) / 2
            let radius = outer * 0.73
            let step = 360.0 / Double(max(count, 1))
            let mid = (-90 + step * Double(index) + step / 2) * .pi / 180
            content
                .position(
                    x: geo.size.width / 2 + radius * cos(mid),
                    y: geo.size.height / 2 + radius * sin(mid))
        }
    }
}

#Preview {
    NavigationStack {
        FlavourWheelPicker(stage: .nose, selected: ["caramel", "vanilla"]) { _ in }
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
