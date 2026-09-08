import XCTest
@testable import LiquorEngine

/// The shipped JSON is validated by `scripts/check_flavor_wheel.py`, which runs
/// on the free Linux job. These tests cover the decoder and the rules, using
/// fixtures — so a structural bug is caught here even if the data file is fine.
final class FlavorWheelTests: XCTestCase {

    private func wheel(_ json: String) throws -> FlavorWheel {
        try FlavorWheel.decode(from: Data(json.utf8))
    }

    private let sample = """
    {
      "version": 1,
      "name": "Test wheel",
      "families": [
        { "key": "sweet", "label": "Sweet", "descriptors": [
          { "key": "vanilla", "label": "Vanilla", "origin": "maturation",
            "compound": "vanillin", "why": "Oak lignin under char." },
          { "key": "honey", "label": "Honey", "origin": "maturation" }
        ]},
        { "key": "grain", "label": "Grain", "descriptors": [
          { "key": "rye-spice", "label": "Rye spice", "origin": "grain" }
        ]},
        { "key": "faults", "label": "Off-notes", "descriptors": [
          { "key": "green-apple", "label": "Green apple", "origin": "oxidation" },
          { "key": "sulphur", "label": "Sulphur", "origin": "fault" }
        ]}
      ]
    }
    """

    // MARK: - Decoding

    func testDecodesFamiliesAndDescriptors() throws {
        let w = try wheel(sample)
        XCTAssertEqual(w.version, 1)
        XCTAssertEqual(w.families.count, 3)
        XCTAssertEqual(w.allDescriptors.count, 5)
    }

    func testOptionalFieldsAreOptional() throws {
        let w = try wheel(sample)
        XCTAssertEqual(w.descriptor("vanilla")?.compound, "vanillin")
        XCTAssertNil(w.descriptor("honey")?.compound)
        XCTAssertNil(w.descriptor("honey")?.why)
    }

    func testUnknownOriginFailsToDecodeRatherThanDefaulting() {
        let bad = """
        {"version":1,"name":"x","families":[{"key":"a","label":"A","descriptors":[
          {"key":"k","label":"K","origin":"vibes"}]}]}
        """
        XCTAssertThrowsError(try wheel(bad),
            "a silently defaulted origin would put a descriptor in the wrong place")
    }

    // MARK: - Lookup

    func testDescriptorLookupByStoredKey() throws {
        let w = try wheel(sample)
        XCTAssertEqual(w.descriptor("rye-spice")?.label, "Rye spice")
        XCTAssertEqual(w.family(containing: "rye-spice")?.key, "grain")
    }

    /// A tasting note holds a key. A key from a newer wheel must return nil so
    /// the UI can show the raw key, rather than the note silently vanishing.
    func testAnUnknownKeyReturnsNilRatherThanCrashing() throws {
        let w = try wheel(sample)
        XCTAssertNil(w.descriptor("brand-new-descriptor"))
        XCTAssertNil(w.family(containing: "brand-new-descriptor"))
    }

    /// Origin is what lets the oxidation model reason about which notes arrive
    /// as a bottle sits open and which ones flatten.
    func testDescriptorsCanBeSelectedByOrigin() throws {
        let w = try wheel(sample)
        XCTAssertEqual(w.descriptors(from: .oxidation).map(\.key), ["green-apple"])
        XCTAssertEqual(w.descriptors(from: .maturation).count, 2)
    }

    func testOnlyFaultsAreMarkedUndesirable() {
        for origin in FlavorOrigin.allCases {
            XCTAssertEqual(origin.isUndesirable, origin == .fault, "\(origin)")
        }
    }

    func testEveryOriginHasALabel() {
        for origin in FlavorOrigin.allCases {
            XCTAssertFalse(origin.label.isEmpty, "\(origin) has no label")
        }
    }

    // MARK: - Validation

    func testACleanWheelHasNoIssues() throws {
        XCTAssertTrue(try wheel(sample).validate().isEmpty)
    }

    /// Keys are stored in tasting notes, so a duplicate makes a saved note
    /// ambiguous forever.
    func testDuplicateDescriptorKeysAcrossFamiliesAreRejected() throws {
        let dupe = """
        {"version":1,"name":"x","families":[
          {"key":"a","label":"A","descriptors":[{"key":"oak","label":"Oak","origin":"maturation"}]},
          {"key":"b","label":"B","descriptors":[{"key":"oak","label":"Oak","origin":"maturation"}]}]}
        """
        let issues = try wheel(dupe).validate()
        XCTAssertTrue(issues.contains { $0.rule == "descriptor.unique" })
    }

    func testDuplicateFamilyKeysAreRejected() throws {
        let dupe = """
        {"version":1,"name":"x","families":[
          {"key":"a","label":"A","descriptors":[{"key":"one","label":"One","origin":"grain"}]},
          {"key":"a","label":"A again","descriptors":[{"key":"two","label":"Two","origin":"grain"}]}]}
        """
        XCTAssertTrue(try wheel(dupe).validate().contains { $0.rule == "family.unique" })
    }

    func testAnEmptyFamilyIsRejected() throws {
        let empty = """
        {"version":1,"name":"x","families":[{"key":"a","label":"A","descriptors":[]}]}
        """
        XCTAssertTrue(try wheel(empty).validate().contains { $0.rule == "family.notEmpty" })
    }

    /// Keys are permanent. An uppercase or spaced key today is a key somebody
    /// "tidies" tomorrow, orphaning every note that used it.
    func testUnstableKeysAreRejected() throws {
        let loose = """
        {"version":1,"name":"x","families":[{"key":"a","label":"A","descriptors":[
          {"key":"Charred Oak","label":"Charred oak","origin":"maturation"}]}]}
        """
        XCTAssertTrue(try wheel(loose).validate().contains { $0.rule == "descriptor.keyIsStable" })
    }

    func testAMissingLabelIsRejected() throws {
        let blank = """
        {"version":1,"name":"x","families":[{"key":"a","label":"A","descriptors":[
          {"key":"oak","label":"  ","origin":"maturation"}]}]}
        """
        XCTAssertTrue(try wheel(blank).validate().contains { $0.rule == "descriptor.hasLabel" })
    }
}
