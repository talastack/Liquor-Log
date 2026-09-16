import Foundation

/// Who really makes a tequila: the NOM on the label, looked up in the
/// CRT's own registry.
///
/// Every bottle of tequila carries a four-digit NOM naming the distillery
/// that produced it, and the Consejo Regulador del Tequila publishes the
/// registry of authorised producers with the brands registered to each.
/// That is the agave world's DSP, and it answers the two questions
/// collectors ask: *who makes this brand*, and *what else comes out of
/// that plant* -- the store's own-label tequila and a premium one sharing
/// a still is the kind of fact the registry makes plain.
///
/// The data is the CRT's, rebuilt by `scripts/build_tequila_registry.py`
/// from crt.org.mx and shipped as `tequila-nom.v1.json`. Names are as the
/// CRT lists them, in capitals; nothing is edited or added.
public struct TequilaRegistry: Sendable {

    public struct Producer: Hashable, Sendable, Codable, Identifiable {
        public let nom: String
        public let company: String
        public let brands: [String]
        public var id: String { nom }

        public init(nom: String, company: String, brands: [String]) {
            self.nom = nom
            self.company = company
            self.brands = brands
        }
    }

    public let producers: [Producer]
    private let byNOM: [String: Producer]
    /// Every brand, folded the way the rest of the app matches text --
    /// lowercase, accents stripped, punctuation dropped -- so "el tequileno"
    /// finds EL TEQUILEÑO and "trader joes" finds TRADER JOE´S.
    private let brands: [(folded: String, brand: String, producer: Producer)]

    public init(producers: [Producer]) {
        self.producers = producers
        self.byNOM = Dictionary(producers.map { ($0.nom, $0) }, uniquingKeysWith: { a, _ in a })
        self.brands = producers.flatMap { producer in
            producer.brands.map { (folded: $0.normalizedForMatching(), brand: $0, producer: producer) }
        }
    }

    public static let empty = TequilaRegistry(producers: [])

    private struct File: Decodable {
        let version: Int
        let producers: [Producer]
    }

    public static func decode(from data: Data) throws -> TequilaRegistry {
        TequilaRegistry(producers: try JSONDecoder().decode(File.self, from: data).producers)
    }

    public var isEmpty: Bool { producers.isEmpty }

    /// "NOM 1139", "nom-1139", "1139" → "1139". Nil for anything that is
    /// not four digits.
    public static func normalise(_ raw: String) -> String? {
        let digits = raw.uppercased()
            .replacingOccurrences(of: "NOM", with: "")
            .filter(\.isNumber)
        guard digits.count == 4, raw.uppercased().filter(\.isLetter).allSatisfy({ "NOM".contains($0) })
        else { return nil }
        return digits
    }

    public func producer(nom raw: String) -> Producer? {
        Self.normalise(raw).flatMap { byNOM[$0] }
    }

    /// Producers with a brand matching the words typed. A brand that IS the
    /// query comes first, then brands that start with it, then brands that
    /// contain it; at most `limit`. Four characters before anything is
    /// searched: three is the start of a Four Roses code, not a brand.
    public func find(brand raw: String, limit: Int = 8) -> [(producer: Producer, brand: String)] {
        let query = raw.normalizedForMatching()
        guard query.count >= 4 else { return [] }
        var exact: [(Producer, String)] = []
        var prefix: [(Producer, String)] = []
        var contains: [(Producer, String)] = []
        for entry in brands {
            if entry.folded == query { exact.append((entry.producer, entry.brand)) }
            else if entry.folded.hasPrefix(query) { prefix.append((entry.producer, entry.brand)) }
            else if entry.folded.contains(query) { contains.append((entry.producer, entry.brand)) }
        }
        return Array((exact + prefix + contains).prefix(limit)).map { (producer: $0.0, brand: $0.1) }
    }

    /// Only brands that are exactly the words typed -- for the case where
    /// four digits are both a NOM and a registered brand name.
    public func exact(brand raw: String) -> [(producer: Producer, brand: String)] {
        let query = raw.normalizedForMatching()
        guard !query.isEmpty else { return [] }
        return brands.filter { $0.folded == query }.map { (producer: $0.producer, brand: $0.brand) }
    }
}
