import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import LiquorData

/// Your bottles in the phone's own search.
///
/// Pull down on the Home Screen, type "weller", and the bottle from your
/// shelf is there with "on your shelf · 13 of 17 pours" under it, before
/// the app is even open. People use that search far more than any voice
/// assistant, and it is the shop question answered one gesture sooner.
///
/// Re-indexed whole after every change the app notices: a collection is
/// hundreds of rows at most, and a partial update that drifts is worse
/// than a full one that does not. Finished bottles are left out -- search
/// is for what you have.
enum Spotlight {
    static let domain = "bottles"

    /// The identifier a search result carries back: "bottle:<id>".
    static func bottleId(from activity: NSUserActivity) -> String? {
        guard activity.activityType == CSSearchableItemActionType,
              let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              raw.hasPrefix("bottle:") else { return nil }
        return String(raw.dropFirst("bottle:".count))
    }

    static func reindex(_ env: AppEnvironment) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        // A shelf that could not be read is not an empty shelf. The index
        // keeps what it had rather than being wiped by a transient error.
        guard let summaries = try? env.bottles.summaries() else { return }
        let items = summaries.map { summary -> CSSearchableItem in
            let bottle = summary.bottle
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = env.name(for: bottle)
            var lines: [String] = []
            if let distillery = env.distillery(for: bottle) { lines.append(distillery) }
            if bottle.isSample {
                lines.append("Sample" + (bottle.sampleFrom.map { " from \($0)" } ?? ""))
            } else if bottle.isOpen, summary.status.hasPartialPourOnly {
                lines.append("Open · less than a pour left")
            } else if bottle.isOpen {
                lines.append("Open · \(summary.status.remainingPours) of \(summary.status.totalPours) pours")
            } else {
                lines.append("On your shelf, unopened")
            }
            if let location = bottle.storageLocation { lines.append(location) }
            attributes.contentDescription = lines.joined(separator: " · ")
            attributes.keywords = [bottle.releaseLabel, bottle.barrelNumber, bottle.batchNumber, bottle.pickStore]
                .compactMap { $0 }
            let item = CSSearchableItem(
                uniqueIdentifier: "bottle:\(bottle.id)",
                domainIdentifier: domain,
                attributeSet: attributes)
            item.expirationDate = .distantFuture
            return item
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            index.indexSearchableItems(items) { _ in }
        }
    }
}
