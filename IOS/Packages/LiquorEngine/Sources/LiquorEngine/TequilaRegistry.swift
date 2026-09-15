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

    public init(producers: [Producer]) {
        self.producers = producers
        self.byNOM = Dictionary(producers.map { ($0.nom, $0) }, uniquingKeysWith: { a, _ in a })
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
    /// contain it; at most `limit`.
    public func find(brand raw: String, limit: Int = 8) -> [(producer: Producer, brand: String)] {
        let query = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard query.count >= 3 else { return [] }
        var exact: [(Producer, String)] = []
        var prefix: [(Producer, String)] = []
        var contains: [(Producer, String)] = []
        for producer in producers {
            for brand in producer.brands {
                let name = brand.uppercased()
                if name == query { exact.append((producer, brand)) }
                else if name.hasPrefix(query) { prefix.append((producer, brand)) }
                else if name.contains(query) { contains.append((producer, brand)) }
            }
        }
        return Array((exact + prefix + contains).prefix(limit)).map { (producer: $0.0, brand: $0.1) }
    }
}
