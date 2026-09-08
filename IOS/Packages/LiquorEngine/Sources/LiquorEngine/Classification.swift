import Foundation

/// What the bottle legally *is*, kept separate from how it was selected.
///
/// These are two independent axes and the app answers a different question with
/// each. "Do I have this bourbon, or do I have *this type*?" is a `ClassType`
/// question. "Is this the single barrel or the small batch?" is a
/// `ProductionType` one. Elijah Craig Barrel Proof is Kentucky Straight **and**
/// small batch **and** barrel proof; one enum would force a choice between three
/// true things.
public enum ClassType: String, Sendable, CaseIterable, Codable {
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
    case singleMaltScotch
    case blendedScotch
    case irishWhiskey
    case canadianWhisky
    case japaneseWhisky
    case maltBeverage

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

    /// American whiskey classes carry a 40% ABV minimum bottling strength.
    public var hasAmericanMinimumStrength: Bool {
        switch self {
        case .maltBeverage, .singleMaltScotch, .blendedScotch, .irishWhiskey,
             .canadianWhisky, .japaneseWhisky:
            return false
        default:
            return true
        }
    }

    public var isBeer: Bool { self == .maltBeverage }
}

/// How the bottle was selected and combined. Orthogonal to `ClassType`.
public enum ProductionType: String, Sendable, CaseIterable, Codable {
    case singleBarrel
    case smallBatch
    case blend
    case singleCask
    case unspecified
}

// MARK: - Validation

/// Rules that are federal regulation rather than opinion, so they are checkable
/// rather than arguable.
///
/// They live here, in compiled code, and a test asserts the shipped catalog JSON
/// agrees with them -- the same arrangement Reef-Ledger uses for `SafetyClamps`.
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

    /// Minimum bottling strength for American whiskey.
    public static let americanMinimumABV = ABV(percent: 40.0)

    /// Minimum barrel time for a "straight" designation.
    public static let straightMinimumYears = 2

    /// Below this, a straight whiskey must carry an age statement.
    public static let ageStatementRequiredBelowYears = 4

    /// Bonded whiskey must be at least four years old.
    public static let bottledInBondMinimumYears = 4

    /// Note on a rule that is NOT here: bourbon's 125-proof cap is an *entry*
    /// proof -- the strength going into the barrel. Whiskey gains strength in a
    /// hot warehouse, so barrel-proof bottlings legitimately exceed it; several
    /// well-known ones bottle above 70% ABV. Validating bottled ABV against 62.5%
    /// would reject real whiskey, so it is deliberately absent.
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
            if classType.hasAmericanMinimumStrength, abv < americanMinimumABV {
                issues.append(Issue(
                    rule: "abv.americanMinimum",
                    detail: "\(classType.rawValue) bottles at no less than 80 proof; got \(abv.proof)"
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
