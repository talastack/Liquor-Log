import XCTest
import GRDB
import LiquorEngine
@testable import LiquorData

/// One note per product, kept current: edits replace, blanks remove, and a
/// removed note revives rather than duplicating.
final class KnowledgeNoteRepositoryTests: XCTestCase {

    private var notes: KnowledgeNoteRepository!

    override func setUpWithError() throws {
        notes = KnowledgeNoteRepository(try AppDatabase.inMemory())
    }

    func testSetThenReadBack() throws {
        try notes.set(productId: "weller-12", title: "Weller 12", body: "  Runs hot in 2019 batches. ")
        let note = try XCTUnwrap(notes.note(productId: "weller-12"))
        XCTAssertEqual(note.body, "Runs hot in 2019 batches.")
        XCTAssertEqual(note.subjectKind, "product")
        XCTAssertEqual(try notes.productIdsWithNotes(), ["weller-12"])
    }

    func testEditingReplacesRatherThanAppends() throws {
        let first = try XCTUnwrap(notes.set(productId: "p", title: "P", body: "one"))
        let second = try XCTUnwrap(notes.set(productId: "p", title: "P", body: "two"))
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try notes.all().count, 1)
        XCTAssertEqual(try notes.note(productId: "p")?.body, "two")
    }

    func testABlankBodyRemovesTheNote() throws {
        try notes.set(productId: "p", title: "P", body: "one")
        XCTAssertNil(try notes.set(productId: "p", title: "P", body: "   \n"))
        XCTAssertNil(try notes.note(productId: "p"))
        XCTAssertTrue(try notes.productIdsWithNotes().isEmpty)
    }

    func testARemovedNoteRevivesTheSameRow() throws {
        let first = try XCTUnwrap(notes.set(productId: "p", title: "P", body: "one"))
        try notes.set(productId: "p", title: "P", body: "")
        let again = try XCTUnwrap(notes.set(productId: "p", title: "P", body: "three"))
        XCTAssertEqual(first.id, again.id)
        XCTAssertEqual(try notes.all().count, 1)
    }
}
