import Foundation

/// What a distillery says about the building a bottle aged in.
///
/// A Blanton's label prints "Warehouse H" and most people who buy one have
/// heard why that matters. This is the why, in one line, from the producer
/// -- never from a forum. Every entry carries the page it came from (all
/// read 15 September 2026), and a warehouse with nothing sourced about it
/// gets no line at all, which is the correct amount to say.
public enum WarehouseLore: Sendable {

    public struct Note: Hashable, Sendable {
        public let text: String
        public let source: String
    }

    /// The best line for a bottle, given its distillery and the warehouse
    /// the label printed (if any). Specific building first, then anything
    /// the distillery says about its warehouses in general.
    public static func note(distillery: String, warehouse: String?) -> Note? {
        let d = distillery.normalizedForMatching()
        let w = (warehouse ?? "").normalizedForMatching()

        if d.contains("buffalo trace") {
            if w == "h" {
                return Note(
                    text: "Warehouse H is the only metal-clad warehouse at Buffalo Trace, "
                        + "built in 1935 by Albert B. Blanton. The metal walls swing "
                        + "temperature faster, so the bourbon works the oak harder — and it "
                        + "is where Blanton's has aged since Elmer T. Lee bottled the first "
                        + "single barrel from it in 1984.",
                    source: "https://www.buffalotracedistillery.com/our-brands/blantons-single-barrel/")
            }
            return nil
        }

        if d.contains("four roses") {
            return Note(
                text: "Four Roses ages in single-story rack warehouses at Cox's Creek, one "
                    + "of very few major distilleries to do so. Top rack to bottom varies "
                    + "by about 8 °F, against up to 30 °F in a multi-storey warehouse, "
                    + "which is why a Four Roses barrel's floor matters less than most.",
                source: "https://www.fourrosesbourbon.com/our-process")
        }

        if d.contains("wild turkey") {
            if w.contains("camp nelson") {
                return Note(
                    text: "Camp Nelson is Wild Turkey's older rickhouse campus; Camp Nelson B "
                        + "dates from the 1940s and is one of five still standing there. "
                        + "Russell's Reserve's Single Rickhouse series is drawn one building "
                        + "at a time from these, which is the distillery's own statement "
                        + "that the building shapes the whiskey.",
                    source: "https://www.russellsreserve.com/our-products/single-rickhouse/")
            }
            return Note(
                text: "Wild Turkey bottles its Single Rickhouse series one building at a "
                    + "time — the distillery's own statement that where a barrel rested "
                    + "shows in the glass.",
                source: "https://www.russellsreserve.com/our-products/single-rickhouse/")
        }

        if d.contains("maker") {
            return Note(
                text: "Maker's finishes its Private Select and wood-finishing releases in "
                    + "a limestone cellar rather than a rickhouse — cold and steady, ten "
                    + "staves in the barrel for nine weeks.",
                source: "https://www.makersmark.com/en-us/bourbons/makers-mark-private-selection")
        }

        return nil
    }
}
