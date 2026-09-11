import Foundation
import GRDB

/// What you know about a PRODUCT, as distinct from what you thought of one
/// bottle of it.
///
/// A tasting is an opinion about a pour on a night. This is the other kind
/// of note: "the 2019 batches ran hot", "the store pick beats the standard,
/// the standard is not worth $60", "buy at Total Wine, not the ABC" -- facts
/// a person accumulates about a whiskey over years and has nowhere to keep
/// except a notes app that does not know what a bottle is.
///
/// One note per product per person. Editing replaces the body rather than
/// appending a second note, because "what do I know about Weller 12" wants
/// one answer, kept current, not a thread.
public struct KnowledgeNoteRepository: Sendable {
    private let db: AppDatabase

    /// The subject kind stored for a product note. The table can hold other
    /// subjects later; this is the one the screens use.
    public static let productSubject = "product"

    public init(_ db: AppDatabase) { self.db = db }

    public func note(productId: String) throws -> KnowledgeNote? {
        try db.queue.read { db in
            try KnowledgeNote
                .live()
                .filter(Column("subject_kind") == Self.productSubject)
                .filter(Column("subject_id") == productId)
                .order(Column("updated_at").desc)
                .fetchOne(db)
        }
    }

    /// Every product note, newest edit first, for a list.
    public func all() throws -> [KnowledgeNote] {
        try db.queue.read { db in
            try KnowledgeNote
                .live()
                .filter(Column("subject_kind") == Self.productSubject)
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    /// The product ids that have a note, for a screen that only needs to
    /// know whether to show the affordance.
    public func productIdsWithNotes() throws -> Set<String> {
        try db.queue.read { db in
            let ids = try String.fetchAll(
                db,
                sql: """
                    SELECT subject_id FROM knowledge_notes
                    WHERE deleted_at IS NULL AND subject_kind = ? AND subject_id IS NOT NULL
                    """,
                arguments: [Self.productSubject])
            return Set(ids)
        }
    }

    /// Writes the note for a product: updates the existing one, revives a
    /// removed one, or creates it. An empty body removes the note -- a blank
    /// note is not knowledge and should not show as one.
    @discardableResult
    public func set(productId: String, title: String, body: String) throws -> KnowledgeNote? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return try db.queue.write { db in
            // ALL rows, tombstones included, so a removed note revives rather
            // than leaving two rows for one product.
            let existing = try KnowledgeNote
                .filter(Column("subject_kind") == Self.productSubject)
                .filter(Column("subject_id") == productId)
                .fetchOne(db)

            if trimmedBody.isEmpty {
                if var found = existing, found.deletedAt == nil {
                    found.softDelete()
                    try found.save(db)
                }
                return nil
            }

            if var found = existing {
                found.deletedAt = nil
                found.title = title
                found.body = trimmedBody
                try found.saveLocal(db)
                return found
            }

            var note = KnowledgeNote(
                title: title,
                body: trimmedBody,
                subjectKind: Self.productSubject,
                subjectId: productId)
            try note.saveLocal(db)
            return note
        }
    }
}
