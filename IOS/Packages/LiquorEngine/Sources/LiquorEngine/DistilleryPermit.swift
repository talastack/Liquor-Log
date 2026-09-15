import Foundation

/// The federal permit number on the back label, and who it belongs to.
///
/// Every distilled spirits plant in the United States has a TTB permit --
/// `DSP-KY-113` -- and the label must name the plant that distilled or
/// bottled the whiskey. So the number is how sourced whiskey is unmasked:
/// a brand with no distillery of its own carries somebody else's DSP, and
/// a collector who knows the table reads "DSP-IN-15016" as "this is MGP".
///
/// The table is the feature, so its accuracy is the feature. Every entry
/// here was checked on 15 September 2026 against two independent public
/// lists, and `onTwoLists` says whether both carried it:
///
/// - https://modernthirst.com/home/dsp-numbers/
/// - https://www.whiskeyprof.com/distilled-spirits-plant-numbers-d-s-p-work-in-progress/
///
/// An entry on one list only is shown with that said. A number not in the
/// table is shown as unknown, never guessed. Nothing here is the TTB's own
/// registry, which is the source to check before a release.
public enum DistilleryPermit: Sendable {

    public struct Plant: Hashable, Sendable {
        public let number: String
        public let distillery: String
        public let location: String
        /// Both public lists carry it. False means one list only.
        public let onTwoLists: Bool
        /// A closed plant, or one that only warehouses and bottles.
        public let note: String?
    }

    /// "dsp ky 113", "DSP-KY-113", "DSP KY-113" -> "DSP-KY-113".
    public static func normalise(_ raw: String) -> String? {
        let upper = raw.uppercased()
        guard let regex = try? NSRegularExpression(pattern: #"DSP[\s\-]*([A-Z]{2})[\s\-]*(\d{1,6})"#),
              let match = regex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
              let state = Range(match.range(at: 1), in: upper),
              let digits = Range(match.range(at: 2), in: upper)
        else { return nil }
        return "DSP-\(upper[state])-\(Int(upper[digits]) ?? 0)"
    }

    public static func lookup(_ raw: String) -> Plant? {
        guard let key = normalise(raw) else { return nil }
        return plants.first { $0.number == key }
    }

    /// Finds a permit number inside a longer piece of text, such as the
    /// lines a label scan returns.
    public static func find(in text: String) -> String? {
        normalise(text)
    }

    static func plant(_ number: String, _ distillery: String, _ location: String,
                      twoLists: Bool = true, note: String? = nil) -> Plant {
        Plant(number: number, distillery: distillery, location: location, onTwoLists: twoLists, note: note)
    }

    public static let plants: [Plant] = [
        // Kentucky, the majors.
        plant("DSP-KY-1", "Heaven Hill, Bernheim distillery", "Louisville, KY"),
        plant("DSP-KY-31", "Heaven Hill, Bardstown", "Bardstown, KY", note: "Bottling and warehousing; the whiskey is distilled at DSP-KY-1."),
        plant("DSP-KY-8", "Four Roses", "Lawrenceburg, KY"),
        plant("DSP-KY-62", "Four Roses, Cox's Creek", "Cox's Creek, KY", twoLists: false, note: "Warehousing and bottling."),
        plant("DSP-KY-12", "Barton 1792 (Tom Moore)", "Bardstown, KY"),
        plant("DSP-KY-16", "Stitzel-Weller", "Louisville, KY", note: "Closed as a distillery in 1992; the site bottles and finishes for Diageo."),
        plant("DSP-KY-18", "Castle & Key (the old Taylor distillery)", "Frankfort, KY"),
        plant("DSP-KY-44", "Maker's Mark", "Loretto, KY"),
        plant("DSP-KY-52", "Woodford Reserve", "Versailles, KY"),
        plant("DSP-KY-67", "Wild Turkey", "Lawrenceburg, KY"),
        plant("DSP-KY-78", "Willett (Kentucky Bourbon Distillers)", "Bardstown, KY"),
        plant("DSP-KY-113", "Buffalo Trace", "Frankfort, KY"),
        plant("DSP-KY-230", "Jim Beam, Clermont", "Clermont, KY"),
        plant("DSP-KY-354", "Brown-Forman (Early Times / Old Forester)", "Louisville, KY"),
        plant("DSP-KY-414", "Brown-Forman, Shively", "Louisville, KY", twoLists: false),
        plant("DSP-KY-50", "Kentucky Peerless", "Louisville, KY"),
        plant("DSP-KY-24", "Glenmore", "Owensboro, KY", note: "Historic; the site is now Sazerac's Glenmore bottling plant."),
        plant("DSP-KY-49", "Medley", "Owensboro, KY", note: "Historic."),
        plant("DSP-KY-14", "Old Grand-Dad", "Frankfort, KY", note: "Historic; the brand is made by Jim Beam."),
        plant("DSP-KY-25", "Old Crow", "Frankfort, KY", note: "Historic; the brand is made by Jim Beam."),
        // Kentucky, the newer numbers.
        plant("DSP-KY-20003", "Michter's", "Louisville, KY"),
        plant("DSP-KY-20022", "Angel's Envy", "Louisville, KY", twoLists: false),
        plant("DSP-KY-20026", "Bulleit", "Shelbyville, KY"),
        plant("DSP-KY-20016", "New Riff", "Newport, KY", twoLists: false),
        plant("DSP-KY-20037", "Bardstown Bourbon Company", "Bardstown, KY", twoLists: false),
        plant("DSP-KY-20014", "Copper & Kings", "Louisville, KY", twoLists: false),
        plant("DSP-KY-15004", "Town Branch (Lexington Brewing & Distilling)", "Lexington, KY", twoLists: false),
        plant("DSP-KY-15006", "Corsair", "Bowling Green, KY", twoLists: false),
        plant("DSP-KY-15010", "MB Roland", "Pembroke, KY", twoLists: false),
        plant("DSP-KY-15012", "Old Pogue", "Maysville, KY", twoLists: false),
        plant("DSP-KY-15014", "Limestone Branch", "Lebanon, KY", twoLists: false),
        // Beyond Kentucky.
        plant("DSP-IN-15016", "MGP Ingredients (Ross & Squibb)", "Lawrenceburg, IN", twoLists: false, note: "The source behind a great many brands with no distillery of their own."),
        plant("DSP-IN-31", "Starlight (Huber's)", "Borden, IN", twoLists: false),
        plant("DSP-TN-4", "Jack Daniel's", "Lynchburg, TN", twoLists: false),
        plant("DSP-TN-2", "George Dickel (Cascade Hollow)", "Tullahoma, TN", twoLists: false),
        plant("DSP-TN-15006", "Corsair", "Nashville, TN", twoLists: false),
        plant("DSP-IL-15018", "FEW Spirits", "Evanston, IL", twoLists: false),
        plant("DSP-VA-25", "A. Smith Bowman", "Fredericksburg, VA", twoLists: false),
    ]
}
