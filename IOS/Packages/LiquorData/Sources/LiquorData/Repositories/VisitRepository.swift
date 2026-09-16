import Foundation
import GRDB
import LiquorEngine

/// The passport: distillery visits, rows like any other.
public struct VisitRepository: Sendable {
    private let db: AppDatabase

    public init(_ db: AppDatabase) { self.db = db }

    /// Everything, newest first.
    public func all() throws -> [Visit] {
        try db.queue.read { db in
            try Visit.live().order(Column("visited_at").desc).fetchAll(db)
        }
    }

    @discardableResult
    public func record(distillery: String, visitedAt: Int64 = Visit.nowMilliseconds(), note: String? = nil) throws -> Visit {
        let place = distillery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else { throw DataError.visitNeedsAPlace }
        var row = Visit(distillery: place, visitedAt: visitedAt, note: note?.isEmpty == false ? note : nil)
        try db.queue.write { db in try row.saveLocal(db) }
        return row
    }

    /// Soft delete, like everything else here.
    public func remove(id: String) throws {
        try db.queue.write { db in
            guard var row = try Visit.filter(key: id).fetchOne(db) else { return }
            row.softDelete()
            try row.save(db)
        }
    }

    /// The visits as the engine reads them.
    public func facts() throws -> [Passport.Visit] {
        try all().map {
            Passport.Visit(
                distillery: $0.distillery,
                at: Date(timeIntervalSince1970: Double($0.visitedAt) / 1000),
                note: $0.note)
        }
    }
}
