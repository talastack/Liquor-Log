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

    // MARK: Agave
    case tequilaBlanco
    case tequilaReposado
    case tequilaAnejo
    case tequilaExtraAnejo
    case mezcal

    // MARK: Rum
    case rum
    case rhumAgricole

    // MARK: Juniper and neutral
    case londonDryGin
    case distilledGin
    case genever
    case vodka
    case aquavit

    // MARK: Grape and fruit
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

    // MARK: Beer
    case maltBeverage

    /// Broad grouping, for filters and for grouping a shelf. Not a legal
    /// concept — the legal concept is the case itself.
    public enum Family: String, Sendable, CaseIterable, Hashable {
        case whiskey, agave, rum, gin, vodka, brandy, liqueur, beer, other

        public var label: String {
            switch self {
            case .whiskey: return "Whiskey"
            case .agave: return "Agave"
            case .rum: return "Rum"
            case .gin: return "Gin"
            case .vodka: return "Vodka"
            case .brandy: return "Brandy"
            case .liqueur: return "Liqueur"
            case .beer: return "Beer"
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
             .canadianWhisky, .japaneseWhisky:
            return .whiskey
        case .tequilaBlanco, .tequilaReposado, .tequilaAnejo, .tequilaExtraAnejo, .mezcal:
            return .agave
        case .rum, .rhumAgricole:
            return .rum
        case .londonDryGin, .distilledGin, .genever:
            return .gin
        case .vodka:
            return .vodka
        case .cognac, .armagnac, .calvados, .brandy, .pisco:
            return .brandy
        case .liqueur, .amaro, .vermouth:
            return .liqueur
        case .maltBeverage:
            return .beer
        case .aquavit, .absinthe:
            return .other
        }
    }

    /// "Straight" is a regulated claim, not a marketing word: at least two years
    /// in new charred oak, and an age statement if under four.
    public var isStraight: Bool {
        switch self {
        case .straightBourbon, .kentuckyStraightBourbon, .blendOfStraightBourbon,
             .straightRye, .straightWheatWhiskey, .straightCornWhiskey:
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
        switch family {
        case .liqueur, .beer:
            return nil
        case .whiskey, .agave, .rum, .gin, .vodka, .brandy:
            return ABV(percent: 40)
        case .other:
            // Aquavit and absinthe are bottled far above any floor in practice,
            // but their minimums vary by origin, so the app does not assert one.
            return nil
        }
    }

    /// Kept for call sites that only ask the yes/no question.
    public var hasMinimumStrength: Bool { minimumBottlingStrength != nil }

    public var isBeer: Bool { self == .maltBeverage }

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
        case .maltBeverage: return "Malt Beverage"
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
    /// `ClassType.minimumBottlingStrength`.
    public static let americanMinimumABV = ABV(percent: 40.0)

    /// Minimum barrel time for a "straight" designation.
    public static let straightMinimumYears = 2

    /// Below this, a straight whiskey must carry an age statement.
    public static let ageStatementRequiredBelowYears = 4

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

        if isBottledInBond, !classType.isStraight {
            issues.append(Issue(
                rule: "bond.requiresStraight",
                detail: "bottled in bond applies to straight whiskey; got \(classType.rawValue)"
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
