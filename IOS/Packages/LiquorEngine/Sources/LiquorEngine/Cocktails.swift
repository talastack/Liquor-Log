import Foundation

/// What can be made tonight from what is open.
///
/// The specs are the International Bartenders Association's official
/// recipes (iba-world.com/cocktails), the one list that is a standard
/// rather than an opinion, transcribed as ingredient lists with the IBA's
/// own measures. A recipe is not copyrightable and these are the IBA's
/// to publish; nothing here is invented, and where the IBA names a
/// choice ("bourbon or rye") the choice is kept.
///
/// Matching is by what a bottle IS, from its class, never by name alone:
/// a Manhattan wants a rye or bourbon and a sweet vermouth, and any open
/// bottle of those classes fills the slot. The bottle picked for a slot
/// is the highest-rated open one, then the fullest. Bitters, citrus,
/// sugar and soda are pantry and are listed as things to have, not
/// matched. A recipe with every spirit slot filled is "ready"; one slot
/// short is "nearly", with what would fill it named.
public enum Cocktails: Sendable {

    /// What a slot in a recipe accepts. Each case is a test of a bottle's
    /// class, and for a few of the liqueur slots its name, since the
    /// catalogue does not split liqueurs finer than that.
    public enum Slot: String, Sendable, Hashable, CaseIterable {
        case bourbonOrRye, bourbon, rye, scotch, islayScotch, irishWhiskey, anyWhiskey
        case gin, vodka
        case whiteRum, darkRum, agricoleOrJamaicanRum
        case tequila, mezcal
        case cognac, brandy
        case sweetVermouth, dryVermouth
        case campari, aperol
        case orangeLiqueur, coffeeLiqueur, amaretto, drambuie, maraschino, greenChartreuse, blackberryLiqueur
        case absinthe

        public var label: String {
            switch self {
            case .bourbonOrRye: return "bourbon or rye"
            case .bourbon: return "bourbon"
            case .rye: return "rye"
            case .scotch: return "Scotch"
            case .islayScotch: return "Islay Scotch"
            case .irishWhiskey: return "Irish whiskey"
            case .anyWhiskey: return "whiskey"
            case .gin: return "gin"
            case .vodka: return "vodka"
            case .whiteRum: return "white rum"
            case .darkRum: return "dark rum"
            case .agricoleOrJamaicanRum: return "rhum agricole or Jamaican rum"
            case .tequila: return "tequila"
            case .mezcal: return "mezcal"
            case .cognac: return "cognac"
            case .brandy: return "brandy"
            case .sweetVermouth: return "sweet vermouth"
            case .dryVermouth: return "dry vermouth"
            case .campari: return "Campari"
            case .aperol: return "Aperol"
            case .orangeLiqueur: return "orange liqueur"
            case .coffeeLiqueur: return "coffee liqueur"
            case .amaretto: return "amaretto"
            case .drambuie: return "Drambuie"
            case .maraschino: return "maraschino liqueur"
            case .greenChartreuse: return "green Chartreuse"
            case .blackberryLiqueur: return "crème de mûre"
            case .absinthe: return "absinthe"
            }
        }

        /// Whether a bottle fills this slot. `name` is the product's full
        /// name, lowercased and folded, for the slots the class cannot
        /// settle alone.
        public func accepts(classType: ClassType, name: String) -> Bool {
            let bourbons: Set<ClassType> = [.bourbon, .straightBourbon, .kentuckyStraightBourbon, .blendOfStraightBourbon]
            let ryes: Set<ClassType> = [.rye, .straightRye]
            let scotches: Set<ClassType> = [.singleMaltScotch, .blendedMaltScotch, .singleGrainScotch, .blendedScotch]
            let irish: Set<ClassType> = [.irishWhiskey, .singlePotStillIrish, .singleMaltIrish]
            let tequilas: Set<ClassType> = [.tequilaBlanco, .tequilaReposado, .tequilaAnejo, .tequilaExtraAnejo]
            let gins: Set<ClassType> = [.londonDryGin, .distilledGin, .genever]
            let brandies: Set<ClassType> = [.cognac, .armagnac, .calvados, .brandy, .pisco]
            func named(_ words: [String]) -> Bool { words.contains { name.contains($0) } }

            switch self {
            case .bourbonOrRye: return bourbons.contains(classType) || ryes.contains(classType) || classType == .tennesseeWhiskey
            case .bourbon: return bourbons.contains(classType) || classType == .tennesseeWhiskey
            case .rye: return ryes.contains(classType)
            case .scotch: return scotches.contains(classType)
            case .islayScotch:
                return scotches.contains(classType)
                    && named(["ardbeg", "laphroaig", "lagavulin", "caol ila", "bowmore", "bunnahabhain", "kilchoman", "bruichladdich", "port charlotte", "octomore", "islay"])
            case .irishWhiskey: return irish.contains(classType)
            case .anyWhiskey: return classType.family == .whiskey
            case .gin: return gins.contains(classType)
            case .vodka: return classType == .vodka
            case .whiteRum:
                return classType == .rum && named(["white", "blanco", "silver", "light", "superior", "3 stars", "plata", "carta blanca"])
            case .darkRum:
                return classType == .rum && !named(["white", "blanco", "silver", "light", "superior", "3 stars", "plata", "carta blanca"])
            case .agricoleOrJamaicanRum:
                return classType == .rhumAgricole || (classType == .rum && named(["appleton", "jamaica", "smith & cross", "hampden", "worthy park", "myers"]))
            case .tequila: return tequilas.contains(classType)
            case .mezcal: return classType == .mezcal
            case .cognac: return classType == .cognac
            case .brandy: return brandies.contains(classType)
            case .sweetVermouth:
                return classType == .vermouth && !named(["dry", "blanc", "bianco", "extra dry"])
            case .dryVermouth:
                return classType == .vermouth && named(["dry", "extra dry"])
            case .campari: return named(["campari"])
            case .aperol: return named(["aperol"])
            case .orangeLiqueur: return named(["cointreau", "triple sec", "curacao", "curaçao", "grand marnier", "orange liqueur", "combier"])
            case .coffeeLiqueur: return named(["kahlua", "kahlúa", "coffee liqueur", "mr black", "tia maria"])
            case .amaretto: return named(["amaretto", "disaronno"])
            case .drambuie: return named(["drambuie"])
            case .maraschino: return named(["maraschino", "luxardo"])
            case .greenChartreuse: return named(["chartreuse"]) && !named(["yellow"])
            case .blackberryLiqueur: return named(["creme de mure", "crème de mûre", "blackberry"])
            case .absinthe: return classType == .absinthe
            }
        }
    }

    /// One line of a recipe: a slot to fill from the shelf, or something
    /// from the kitchen.
    public enum Ingredient: Sendable, Hashable {
        case bottle(Slot, milliliters: Double)
        case pantry(String)

        public var text: String {
            switch self {
            case let .bottle(slot, ml): return "\(Self.measure(ml)) \(slot.label)"
            case let .pantry(text): return text
            }
        }

        static func measure(_ ml: Double) -> String {
            ml == ml.rounded() ? "\(Int(ml)) ml" : String(format: "%.1f ml", ml)
        }
    }

    public struct Recipe: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let ingredients: [Ingredient]
        public let method: String
        public let glass: String

        public var slots: [Slot] {
            ingredients.compactMap { if case let .bottle(slot, _) = $0 { return slot } else { return nil } }
        }
    }

    /// A bottle as the matcher sees it.
    public struct Candidate: Sendable, Hashable {
        public let id: String
        public let name: String
        public let classType: ClassType
        public let isOpen: Bool
        public let rating: Int?
        public let fillFraction: Double

        public init(id: String, name: String, classType: ClassType, isOpen: Bool, rating: Int? = nil, fillFraction: Double = 1) {
            self.id = id
            self.name = name
            self.classType = classType
            self.isOpen = isOpen
            self.rating = rating
            self.fillFraction = fillFraction
        }

        var folded: String { name.normalizedForMatching() }
    }

    public struct Match: Sendable, Hashable, Identifiable {
        public let recipe: Recipe
        /// The open bottle chosen for each slot, in recipe order; nil where
        /// nothing open fits.
        public let picks: [Slot: Candidate]
        /// Slots nothing open fits, with a sealed bottle that would, if any.
        public let missing: [(slot: Slot, sealed: Candidate?)]
        public var id: String { recipe.id }
        public var isReady: Bool { missing.isEmpty }

        public static func == (a: Match, b: Match) -> Bool { a.recipe.id == b.recipe.id && a.picks == b.picks }
        public func hash(into hasher: inout Hasher) { hasher.combine(recipe.id) }
    }

    /// Every recipe against the shelf: ready ones first, then those one
    /// bottle short, each group alphabetical. Two or more short are left
    /// out -- that is a shopping list, not tonight.
    public static func matches(shelf: [Candidate], recipes: [Recipe] = all) -> [Match] {
        let open = shelf.filter(\.isOpen)
        let sealed = shelf.filter { !$0.isOpen }
        var ready: [Match] = []
        var nearly: [Match] = []
        for recipe in recipes {
            var picks: [Slot: Candidate] = [:]
            var missing: [(slot: Slot, sealed: Candidate?)] = []
            for slot in recipe.slots {
                if let pick = best(for: slot, among: open) {
                    picks[slot] = pick
                } else {
                    missing.append((slot, best(for: slot, among: sealed)))
                }
            }
            let match = Match(recipe: recipe, picks: picks, missing: missing)
            if missing.isEmpty { ready.append(match) } else if missing.count == 1 { nearly.append(match) }
        }
        let byName: (Match, Match) -> Bool = { $0.recipe.name.localizedCaseInsensitiveCompare($1.recipe.name) == .orderedAscending }
        return ready.sorted(by: byName) + nearly.sorted(by: byName)
    }

    /// Highest rated, then fullest, then by name so the choice is stable.
    static func best(for slot: Slot, among bottles: [Candidate]) -> Candidate? {
        bottles
            .filter { slot.accepts(classType: $0.classType, name: $0.folded) }
            .sorted {
                if ($0.rating ?? 0) != ($1.rating ?? 0) { return ($0.rating ?? 0) > ($1.rating ?? 0) }
                if $0.fillFraction != $1.fillFraction { return $0.fillFraction > $1.fillFraction }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .first
    }

    // MARK: - The IBA list

    /// IBA official cocktails (iba-world.com), the measures as the IBA
    /// gives them. Methods paraphrased to one line.
    public static let all: [Recipe] = [
        Recipe(id: "old-fashioned", name: "Old Fashioned",
               ingredients: [.bottle(.bourbonOrRye, milliliters: 45), .pantry("1 sugar cube"), .pantry("a few dashes Angostura bitters"), .pantry("a few dashes plain water")],
               method: "Muddle the sugar with the bitters and water, add the whiskey and ice, stir. Orange twist.", glass: "old fashioned"),
        Recipe(id: "manhattan", name: "Manhattan",
               ingredients: [.bottle(.rye, milliliters: 50), .bottle(.sweetVermouth, milliliters: 20), .pantry("1 dash Angostura bitters")],
               method: "Stir with ice, strain into a chilled glass. Cherry.", glass: "cocktail"),
        Recipe(id: "whiskey-sour", name: "Whiskey Sour",
               ingredients: [.bottle(.bourbon, milliliters: 45), .pantry("25 ml lemon juice"), .pantry("20 ml sugar syrup"), .pantry("optional: egg white")],
               method: "Shake with ice, strain. Cherry and orange slice.", glass: "old fashioned"),
        Recipe(id: "boulevardier", name: "Boulevardier",
               ingredients: [.bottle(.bourbon, milliliters: 45), .bottle(.campari, milliliters: 30), .bottle(.sweetVermouth, milliliters: 30)],
               method: "Stir with ice, strain over fresh ice. Orange twist.", glass: "old fashioned"),
        Recipe(id: "sazerac", name: "Sazerac",
               ingredients: [.bottle(.rye, milliliters: 50), .bottle(.absinthe, milliliters: 10), .pantry("1 sugar cube"), .pantry("2 dashes Peychaud's bitters")],
               method: "Rinse a chilled glass with the absinthe. Stir the rest with ice, strain in. Lemon twist. The IBA gives cognac as the base too.", glass: "old fashioned"),
        Recipe(id: "mint-julep", name: "Mint Julep",
               ingredients: [.bottle(.bourbon, milliliters: 60), .pantry("4 mint sprigs"), .pantry("1 teaspoon powdered sugar"), .pantry("2 teaspoons water")],
               method: "Muddle mint, sugar and water, add the bourbon and crushed ice, stir until frosted.", glass: "julep cup"),
        Recipe(id: "rusty-nail", name: "Rusty Nail",
               ingredients: [.bottle(.scotch, milliliters: 45), .bottle(.drambuie, milliliters: 25)],
               method: "Stir over ice. Lemon twist.", glass: "old fashioned"),
        Recipe(id: "godfather", name: "Godfather",
               ingredients: [.bottle(.scotch, milliliters: 35), .bottle(.amaretto, milliliters: 35)],
               method: "Build over ice, stir.", glass: "old fashioned"),
        Recipe(id: "penicillin", name: "Penicillin",
               ingredients: [.bottle(.scotch, milliliters: 60), .bottle(.islayScotch, milliliters: 7.5), .pantry("22.5 ml lemon juice"), .pantry("22.5 ml honey-ginger syrup")],
               method: "Shake the blended Scotch, lemon and syrup with ice, strain over ice, float the Islay. Candied ginger.", glass: "old fashioned"),
        Recipe(id: "irish-coffee", name: "Irish Coffee",
               ingredients: [.bottle(.irishWhiskey, milliliters: 50), .pantry("120 ml hot coffee"), .pantry("50 ml cream"), .pantry("1 teaspoon sugar")],
               method: "Sugar and coffee in a warm glass, add the whiskey, float the cream.", glass: "Irish coffee glass"),
        Recipe(id: "negroni", name: "Negroni",
               ingredients: [.bottle(.gin, milliliters: 30), .bottle(.campari, milliliters: 30), .bottle(.sweetVermouth, milliliters: 30)],
               method: "Build over ice, stir. Orange slice.", glass: "old fashioned"),
        Recipe(id: "dry-martini", name: "Dry Martini",
               ingredients: [.bottle(.gin, milliliters: 60), .bottle(.dryVermouth, milliliters: 10)],
               method: "Stir with ice, strain into a chilled glass. Lemon twist or olive.", glass: "cocktail"),
        Recipe(id: "john-collins", name: "John Collins",
               ingredients: [.bottle(.gin, milliliters: 45), .pantry("30 ml lemon juice"), .pantry("15 ml sugar syrup"), .pantry("60 ml soda water")],
               method: "Build over ice in a tall glass, top with soda. Lemon slice and cherry.", glass: "collins"),
        Recipe(id: "french-75", name: "French 75",
               ingredients: [.bottle(.gin, milliliters: 30), .pantry("15 ml lemon juice"), .pantry("2 dashes sugar syrup"), .pantry("60 ml Champagne")],
               method: "Shake gin, lemon and syrup with ice, strain into a flute, top with Champagne.", glass: "flute"),
        Recipe(id: "bees-knees", name: "Bee's Knees",
               ingredients: [.bottle(.gin, milliliters: 52.5), .pantry("22.5 ml lemon juice"), .pantry("22.5 ml honey syrup")],
               method: "Shake with ice, strain into a chilled glass.", glass: "cocktail"),
        Recipe(id: "bramble", name: "Bramble",
               ingredients: [.bottle(.gin, milliliters: 40), .bottle(.blackberryLiqueur, milliliters: 15), .pantry("15 ml lemon juice"), .pantry("10 ml sugar syrup")],
               method: "Shake gin, lemon and syrup, strain over crushed ice, drizzle the crème de mûre.", glass: "old fashioned"),
        Recipe(id: "last-word", name: "Last Word",
               ingredients: [.bottle(.gin, milliliters: 22.5), .bottle(.greenChartreuse, milliliters: 22.5), .bottle(.maraschino, milliliters: 22.5), .pantry("22.5 ml lime juice")],
               method: "Shake with ice, strain into a chilled glass.", glass: "cocktail"),
        Recipe(id: "americano", name: "Americano",
               ingredients: [.bottle(.campari, milliliters: 30), .bottle(.sweetVermouth, milliliters: 30), .pantry("a splash of soda water")],
               method: "Build over ice, top with soda. Orange slice and lemon twist.", glass: "highball"),
        Recipe(id: "aperol-spritz", name: "Aperol Spritz",
               ingredients: [.bottle(.aperol, milliliters: 60), .pantry("90 ml Prosecco"), .pantry("a splash of soda water")],
               method: "Build over ice in a wine glass. Orange slice.", glass: "wine"),
        Recipe(id: "daiquiri", name: "Daiquiri",
               ingredients: [.bottle(.whiteRum, milliliters: 60), .pantry("20 ml lime juice"), .pantry("2 bar spoons sugar syrup")],
               method: "Shake with ice, strain into a chilled glass.", glass: "cocktail"),
        Recipe(id: "mojito", name: "Mojito",
               ingredients: [.bottle(.whiteRum, milliliters: 45), .pantry("20 ml lime juice"), .pantry("6 mint leaves"), .pantry("2 teaspoons sugar"), .pantry("soda water")],
               method: "Muddle mint with sugar and lime, add rum and crushed ice, top with soda.", glass: "highball"),
        Recipe(id: "dark-n-stormy", name: "Dark 'n' Stormy",
               ingredients: [.bottle(.darkRum, milliliters: 60), .pantry("100 ml ginger beer")],
               method: "Build over ice in a tall glass. Lime wedge.", glass: "highball"),
        Recipe(id: "mai-tai", name: "Mai Tai",
               ingredients: [.bottle(.agricoleOrJamaicanRum, milliliters: 30), .bottle(.darkRum, milliliters: 30), .bottle(.orangeLiqueur, milliliters: 15), .pantry("15 ml orgeat"), .pantry("30 ml lime juice"), .pantry("7.5 ml sugar syrup")],
               method: "Shake with ice, strain over crushed ice. Mint and lime. The IBA pairs a Jamaican rum with a Martinique rhum.", glass: "old fashioned"),
        Recipe(id: "margarita", name: "Margarita",
               ingredients: [.bottle(.tequila, milliliters: 50), .bottle(.orangeLiqueur, milliliters: 20), .pantry("15 ml lime juice")],
               method: "Shake with ice, strain into a salt-rimmed glass.", glass: "margarita"),
        Recipe(id: "tommys-margarita", name: "Tommy's Margarita",
               ingredients: [.bottle(.tequila, milliliters: 45), .pantry("15 ml lime juice"), .pantry("2 bar spoons agave nectar")],
               method: "Shake with ice, strain over fresh ice.", glass: "old fashioned"),
        Recipe(id: "paloma", name: "Paloma",
               ingredients: [.bottle(.tequila, milliliters: 50), .pantry("5 ml lime juice"), .pantry("a pinch of salt"), .pantry("grapefruit soda to top")],
               method: "Build over ice in a tall glass, top with grapefruit soda.", glass: "highball"),
        Recipe(id: "sidecar", name: "Sidecar",
               ingredients: [.bottle(.cognac, milliliters: 50), .bottle(.orangeLiqueur, milliliters: 20), .pantry("20 ml lemon juice")],
               method: "Shake with ice, strain into a chilled glass.", glass: "cocktail"),
        Recipe(id: "espresso-martini", name: "Espresso Martini",
               ingredients: [.bottle(.vodka, milliliters: 50), .bottle(.coffeeLiqueur, milliliters: 30), .pantry("1 shot espresso"), .pantry("10 ml sugar syrup")],
               method: "Shake hard with ice, strain into a chilled glass. Three coffee beans.", glass: "cocktail"),
        Recipe(id: "moscow-mule", name: "Moscow Mule",
               ingredients: [.bottle(.vodka, milliliters: 45), .pantry("120 ml ginger beer"), .pantry("10 ml lime juice")],
               method: "Build over ice in a copper mug. Lime wedge.", glass: "copper mug"),
    ]
}
