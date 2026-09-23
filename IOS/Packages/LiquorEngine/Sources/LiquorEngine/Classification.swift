import Foundation

/// What the bottle legally *is*, kept separate from how it was selected.
///
/// These are two independent axes and the app answers a different question with
/// each. "Do I have this bourbon, or do I have *this type*?" is a `ClassType`
/// question. "Is this the single barrel or the small batch?" is a
/// `ProductionType` one. Elijah Craig Barrel Proof is Kentucky Straight **and**
/// small batch **and** barrel proof; one enum would force a choice between three
/// true things.
///
/// The list is the label designation, not a marketing category. Tequila's
/// Blanco/Reposado/Añejo really are class designations; a rum's "aged" is not,
/// which is why rum has fewer cases than its shelf space suggests.
public enum ClassType: String, Sendable, CaseIterable, Codable {

    // MARK: American whiskey
    case bourbon
    case straightBourbon
    case kentuckyStraightBourbon
    case blendOfStraightBourbon
    case rye
    case straightRye
    case wheatWhiskey
    case straightWheatWhiskey
    case cornWhiskey
    case straightCornWhiskey
    case tennesseeWhiskey
    case americanSingleMalt
    case lightWhiskey
    case blendedWhiskey

    // MARK: Scotch
    case singleMaltScotch
    case blendedMaltScotch
    case singleGrainScotch
    case blendedScotch

    // MARK: Other whisky
    case irishWhiskey
    case singlePotStillIrish
    case singleMaltIrish
    case canadianWhisky
    case japaneseWhisky

    /// Whisky from somewhere without a class of its own here -- Taiwan,
    /// India, Australia, Sweden. Named for what it is rather than given a
    /// case per country, which would never stop growing. Kavalan is not
    /// Japanese whisky and saying so would be worse than saying nothing.
    case worldWhisky

    /// Honeyed, cinnamon and apple whiskey. TTB's Class 9 alongside
    /// flavoured rum, gin, vodka and brandy: at least 30%, which is why
    /// Jack Daniel's Tennessee Honey at 35% is not a weak whiskey. Kept in
    /// the whiskey family because that is where somebody looks for it.
    case flavoredWhiskey

    // MARK: Agave
    case tequilaBlanco
    case tequilaReposado
    case tequilaAnejo
    case tequilaExtraAnejo
    case mezcal

    // MARK: Rum
    case rum
    case rhumAgricole

    /// Spiced and flavoured rum. Its own TTB class, not a rum with
    /// something added: the standard of identity allows 30% where straight
    /// rum needs 40%, which is why Captain Morgan at 35% is not an
    /// under-strength rum but an ordinary flavoured one.
    case flavoredRum

    /// A distinctive product of Brazil, recognised by TTB since 2013:
    /// sugarcane juice rather than molasses, bottled between 38% and 48%.
    /// The 38% is why it carries its own floor.
    case cachaca

    // MARK: Juniper and neutral
    case londonDryGin
    case distilledGin
    case genever
    case vodka
    /// Citron, vanilla, raspberry. Class 9 again, so 30% rather than the
    /// family's 40%: Smirnoff's flavours are bottled at exactly 30.
    case flavoredVodka
    case aquavit

    // MARK: Grape and fruit
    /// Pomace brandy. Bottled at 37.5% in the EU, below the spirits floor
    /// its family carries, so it sets its own.
    case grappa
    case cognac
    case armagnac
    case calvados
    case brandy
    case pisco

    // MARK: Sugar-bearing, no strength floor
    case liqueur
    case amaro
    case vermouth
    case absinthe

    // MARK: Fortified wine
    //
    // Not spirits, and they live on the spirits shelf anyway. Each is a
    // wine with grape spirit added, which is what puts them between 15%
    // and 22% -- far under any spirits floor and exactly right for what
    // they are.
    case port
    case sherry
    case madeira

    // MARK: East Asia
    //
    // Grouped for a filter chip, not by any shared definition: soju is
    // usually diluted to 16-25%, shochu runs 20-45%, baijiu 35-65%, and
    // sake is brewed rather than distilled at all. No floor covers that
    // range honestly, so none is asserted.
    case soju
    case shochu
    case sake
    case baijiu

    // MARK: Beer
    case maltBeverage

    // MARK: Cider and seltzer
    //
    // `hardCider` IS a defined class: TTB taxes it as a wine made from apples
    // or pears, still or lightly carbonated, under 8.5% ABV. Pear cider --
    // perry -- belongs here too, because the tax class covers it.
    //
    // `hardSeltzer` is NOT. It is a market category with two different bases:
    // some are flavoured malt beverages (Truly, Bud Light Seltzer) and some
    // are fermented from cane sugar with no malt at all (White Claw), which
    // are not even regulated by the same agency. The app keeps them as one
    // class because that is how a person holding the can thinks of them, and
    // does not claim a regulated class for any of them.
    case hardCider
    case hardSeltzer

    /// Broad grouping, for filters and for grouping a shelf. Not a legal
    /// concept — the legal concept is the case itself.
    public enum Family: String, Sendable, CaseIterable, Hashable {
        case whiskey, agave, rum, gin, vodka, brandy, liqueur
        case fortified, eastAsian, beer, cider, seltzer, other

        public var label: String {
            switch self {
            case .whiskey: return "Whiskey"
            case .agave: return "Agave"
            case .rum: return "Rum"
            case .gin: return "Gin"
            case .vodka: return "Vodka"
            case .brandy: return "Brandy"
            case .liqueur: return "Liqueur"
            case .fortified: return "Fortified wine"
            case .eastAsian: return "East Asian"
            case .beer: return "Beer"
            case .cider: return "Cider"
            case .seltzer: return "Seltzer"
            case .other: return "Other"
            }
        }
    }

    public var family: Family {
        switch self {
        case .bourbon, .straightBourbon, .kentuckyStraightBourbon, .blendOfStraightBourbon,
             .rye, .straightRye, .wheatWhiskey, .straightWheatWhiskey,
             .cornWhiskey, .straightCornWhiskey, .tennesseeWhiskey, .americanSingleMalt,
             .lightWhiskey, .blendedWhiskey,
             .singleMaltScotch, .blendedMaltScotch, .singleGrainScotch, .blendedScotch,
             .irishWhiskey, .singlePotStillIrish, .singleMaltIrish,
             .canadianWhisky, .japaneseWhisky, .worldWhisky, .flavoredWhiskey:
            return .whiskey
        case .tequilaBlanco, .tequilaReposado, .tequilaAnejo, .tequilaExtraAnejo, .mezcal:
            return .agave
        case .rum, .rhumAgricole, .flavoredRum, .cachaca:
            return .rum
        case .londonDryGin, .distilledGin, .genever:
            return .gin
        case .vodka, .flavoredVodka:
            return .vodka
        case .cognac, .armagnac, .calvados, .brandy, .pisco, .grappa:
            return .brandy
        case .liqueur, .amaro, .vermouth:
            return .liqueur
        case .port, .sherry, .madeira:
            return .fortified
        case .soju, .shochu, .sake, .baijiu:
            return .eastAsian
        case .maltBeverage:
            return .beer
        case .hardCider:
            return .cider
        case .hardSeltzer:
            return .seltzer
        case .aquavit, .absinthe:
            return .other
        }
    }

    /// "Straight" is a regulated claim, not a marketing word: at least two years
    /// in new charred oak, and an age statement if under four.
    public var isStraight: Bool {
        switch self {
        case .straightBourbon, .kentuckyStraightBourbon, .blendOfStraightBourbon,
             .straightRye, .straightWheatWhiskey, .straightCornWhiskey,
             // Tennessee whiskey meets the straight bourbon requirements and
             // then adds the Lincoln County Process. Leaving it out here said
             // that a bonded Tennessee whiskey cannot exist, which is
             // contradicted by two on the shelf: Jack Daniel's Bonded and
             // George Dickel Bottled in Bond.
             .tennesseeWhiskey:
            return true
        default:
            return false
        }
    }

    /// Minimum bottling strength, where the class has one.
    ///
    /// Most distilled spirits carry a 40% floor — US whiskey by the standards of
    /// identity, and Scotch, Irish, Canadian and Japanese whisky by their own
    /// rules, so the floor is the same wherever the bottle came from. Gin,
    /// vodka, rum, brandy and tequila are held to it too.
    ///
    /// The exceptions are the sugar-bearing classes. A liqueur, an amaro or a
    /// vermouth may sit well below 40% by design, and rejecting a 16% amaro as
    /// under-strength would be the app being wrong with confidence.
    public var minimumBottlingStrength: ABV? {
        // A few classes carry their own floor, lower than their family's.
        // TTB's flavoured spirits are bottled at 30% and calling one of
        // them under-strength would put a warning on a bottle that is
        // exactly what its label says it is.
        switch self {
        case .flavoredRum, .flavoredWhiskey, .flavoredVodka: return ABV(percent: 30)
        case .cachaca: return ABV(percent: 38)
        case .grappa: return ABV(percent: 37.5)
        default: break
        }

        switch family {
        case .liqueur, .beer, .cider, .seltzer, .fortified, .eastAsian:
            // A 5% cider is not under-strength; it is a cider. Asserting a
            // spirits floor here would make the app wrong with confidence.
            return nil
        case .whiskey, .agave, .rum, .gin, .vodka, .brandy:
            return ABV(percent: 40)
        case .other:
            // Aquavit and absinthe are bottled far above any floor in practice,
            // but their minimums vary by origin, so the app does not assert one.
            return nil
        }
    }

    /// What the UI prints. The raw value is a storage key, not English.
    public var label: String {
        switch self {
        case .bourbon: return "Bourbon Whiskey"
        case .straightBourbon: return "Straight Bourbon Whiskey"
        case .kentuckyStraightBourbon: return "Kentucky Straight Bourbon Whiskey"
        case .blendOfStraightBourbon: return "Blend of Straight Bourbon Whiskeys"
        case .rye: return "Rye Whiskey"
        case .straightRye: return "Straight Rye Whiskey"
        case .wheatWhiskey: return "Wheat Whiskey"
        case .straightWheatWhiskey: return "Straight Wheat Whiskey"
        case .cornWhiskey: return "Corn Whiskey"
        case .straightCornWhiskey: return "Straight Corn Whiskey"
        case .tennesseeWhiskey: return "Tennessee Whiskey"
        case .americanSingleMalt: return "American Single Malt Whiskey"
        case .lightWhiskey: return "Light Whiskey"
        case .blendedWhiskey: return "Blended Whiskey"
        case .singleMaltScotch: return "Single Malt Scotch Whisky"
        case .blendedMaltScotch: return "Blended Malt Scotch Whisky"
        case .singleGrainScotch: return "Single Grain Scotch Whisky"
        case .blendedScotch: return "Blended Scotch Whisky"
        case .irishWhiskey: return "Irish Whiskey"
        case .singlePotStillIrish: return "Single Pot Still Irish Whiskey"
        case .singleMaltIrish: return "Single Malt Irish Whiskey"
        case .canadianWhisky: return "Canadian Whisky"
        case .japaneseWhisky: return "Japanese Whisky"
        case .tequilaBlanco: return "Tequila Blanco"
        case .tequilaReposado: return "Tequila Reposado"
        case .tequilaAnejo: return "Tequila Añejo"
        case .tequilaExtraAnejo: return "Tequila Extra Añejo"
        case .mezcal: return "Mezcal"
        case .rum: return "Rum"
        case .rhumAgricole: return "Rhum Agricole"
        case .flavoredRum: return "Flavored Rum"
        case .flavoredWhiskey: return "Flavored Whiskey"
        case .flavoredVodka: return "Flavored Vodka"
        case .londonDryGin: return "London Dry Gin"
        case .distilledGin: return "Distilled Gin"
        case .genever: return "Genever"
        case .vodka: return "Vodka"
        case .aquavit: return "Aquavit"
        case .cognac: return "Cognac"
        case .armagnac: return "Armagnac"
        case .calvados: return "Calvados"
        case .brandy: return "Brandy"
        case .pisco: return "Pisco"
        case .liqueur: return "Liqueur"
        case .amaro: return "Amaro"
        case .vermouth: return "Vermouth"
        case .absinthe: return "Absinthe"
        case .worldWhisky: return "World Whisky"
        case .grappa: return "Grappa"
        case .cachaca: return "Cachaca"
        case .port: return "Port"
        case .sherry: return "Sherry"
        case .madeira: return "Madeira"
        case .soju: return "Soju"
        case .shochu: return "Shochu"
        case .sake: return "Sake"
        case .baijiu: return "Baijiu"
        case .maltBeverage: return "Malt Beverage"
        case .hardCider: return "Hard Cider"
        case .hardSeltzer: return "Hard Seltzer"
        }
    }
}

/// How the bottle was selected and combined. Orthogonal to `ClassType`.
public enum ProductionType: String, Sendable, CaseIterable, Codable {
    case singleBarrel
    case smallBatch
    case blend
    case singleCask
    case unspecified

    public var label: String {
        switch self {
        case .singleBarrel: return "Single barrel"
        case .smallBatch: return "Small batch"
        case .blend: return "Blend"
        case .singleCask: return "Single cask"
        case .unspecified: return "Not stated on the label"
        }
    }
}

// MARK: - Validation

/// Rules that are regulation rather than opinion, so they are checkable rather
/// than arguable.
///
/// They live here, in compiled code, and a test asserts the shipped catalog JSON
/// agrees with them — the same arrangement Reef-Ledger uses for `SafetyClamps`.
/// A remotely-updatable data file is exactly where a bad value could otherwise
/// arrive without review, so the authority stays in the binary.
public enum Classification: Sendable {

    public struct Issue: Hashable, Sendable, CustomStringConvertible {
        public let rule: String
        public let detail: String

        public init(rule: String, detail: String) {
            self.rule = rule
            self.detail = detail
        }

        public var description: String { "\(rule): \(detail)" }
    }

    /// Bottled-in-bond is exactly 100 proof, by definition.
    public static let bottledInBondABV = ABV(percent: 50.0)

    /// The floor most distilled spirits share. Per-class values live on
    /// `ClassType.minimumBottlingStrength`. Read by scripts/check_catalog.py,
    /// which takes the federal rules from this file rather than restating
    /// them -- so it stays even though no Swift references it.
    public static let americanMinimumABV = ABV(percent: 40.0)

    /// Minimum barrel time for a "straight" designation.
    public static let straightMinimumYears = 2

    /// Bonded whiskey must be at least four years old.
    public static let bottledInBondMinimumYears = 4

    /// Note on a rule that is NOT here: bourbon's 125-proof cap is an *entry*
    /// proof — the strength going into the barrel. Whiskey gains strength in a
    /// hot warehouse, so barrel-proof bottlings legitimately exceed it; several
    /// well-known ones bottle above 70% ABV. Validating bottled ABV against
    /// 62.5% would reject real whiskey, so it is deliberately absent.
    public static func validate(
        classType: ClassType,
        abv: ABV?,
        statedAgeYears: Int?,
        isBottledInBond: Bool,
        volumeMilliliters: Double?
    ) -> [Issue] {
        var issues: [Issue] = []

        if let abv {
            if !abv.isPlausible {
                issues.append(Issue(
                    rule: "abv.plausible",
                    detail: "\(abv.percent)% is outside 0.5-95%; likely a decimal slip"
                ))
            }
            if let floor = classType.minimumBottlingStrength, abv < floor {
                issues.append(Issue(
                    rule: "abv.americanMinimum",
                    detail: "\(classType.rawValue) bottles at no less than \(floor.proof) proof; "
                        + "got \(abv.proof)"
                ))
            }
            if isBottledInBond, abv != bottledInBondABV {
                issues.append(Issue(
                    rule: "bond.proof",
                    detail: "bottled in bond is exactly 100 proof; got \(abv.proof)"
                ))
            }
        } else {
            issues.append(Issue(rule: "abv.missing", detail: "no ABV recorded"))
        }

        if let age = statedAgeYears {
            if classType.isStraight, age < straightMinimumYears {
                issues.append(Issue(
                    rule: "straight.minimumAge",
                    detail: "straight requires \(straightMinimumYears) years; got \(age)"
                ))
            }
            if isBottledInBond, age < bottledInBondMinimumYears {
                issues.append(Issue(
                    rule: "bond.minimumAge",
                    detail: "bottled in bond requires \(bottledInBondMinimumYears) years; got \(age)"
                ))
            }
        }

        // 27 CFR 5.88 lets any distilled spirit be bonded -- Laird's bottles a
        // bonded apple brandy -- but a bonded whiskey has spent four years in
        // wood, so it is a straight whiskey and is labelled as one.
        if isBottledInBond, classType.family == .whiskey, !classType.isStraight {
            issues.append(Issue(
                rule: "bond.requiresStraight",
                detail: "a bottled in bond whiskey is a straight whiskey; got \(classType.rawValue)"
            ))
        }

        if let volume = volumeMilliliters, !Volume.isStandardFill(milliliters: volume) {
            issues.append(Issue(
                rule: "volume.standardOfFill",
                detail: "\(volume) ml is not an authorised standard of fill"
            ))
        }

        return issues
    }
}
