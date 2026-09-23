import XCTest
import SwiftUI
import LiquorEngine
@testable import LiquorLog

/// The small pieces of logic that live in the app target rather than an
/// engine, and had no test until something went wrong.
///
/// The app layer carries 13 tests against the engine's 544, and every bug
/// found in review this week lived here rather than in either engine: a
/// label falling back to a raw identifier, an undo that promised a fill
/// change it could not make, a picker hiding 46 of 60 classes. None of
/// those are hard to test. They were untested because the code sits inside
/// a `View` and nobody had pulled the answerable parts out.
final class AppearanceAndFormTests: XCTestCase {

    // MARK: - Light, dark, or the phone

    func testAppearanceMapsToWhatSwiftUINeeds() {
        // `nil` is not "no opinion" here, it is the ONLY way to say "follow
        // the phone": ColorScheme has no system case, so an override of nil
        // is what leaves the trait collection alone.
        XCTAssertNil(Palette.Appearance.system.colorScheme)
        XCTAssertEqual(Palette.Appearance.light.colorScheme, .light)
        XCTAssertEqual(Palette.Appearance.dark.colorScheme, .dark)
    }

    func testAppearanceRoundTripsThroughItsStoredValue() {
        // The value is persisted in the app group and read back by name. A
        // case renamed without a migration silently resets everybody to
        // following the phone.
        for appearance in Palette.Appearance.allCases {
            XCTAssertEqual(
                Palette.Appearance(rawValue: appearance.rawValue), appearance,
                "\(appearance) does not survive a round trip")
        }
        XCTAssertNil(Palette.Appearance(rawValue: "sepia"))
    }

    func testAppearanceDefaultsToFollowingThePhone() {
        // What the app did before the setting existed, so an upgrade
        // changes nothing for anybody who never opens it.
        XCTAssertEqual(Palette.Appearance.standard, .system)
    }

    func testEveryAppearanceAndLookIsNamedForAPerson() {
        for appearance in Palette.Appearance.allCases {
            XCTAssertFalse(appearance.name.isEmpty)
            XCTAssertNotEqual(appearance.name, appearance.rawValue, "raw value on screen")
            XCTAssertFalse(appearance.line.isEmpty)
        }
        for look in Palette.Look.allCases {
            XCTAssertFalse(look.name.isEmpty)
            XCTAssertNotEqual(look.name, look.rawValue, "raw value on screen")
        }
    }

    // MARK: - The finish band, going back the way it came

    func testFinishLengthFindsTheBandAStoredFigureCameFrom() {
        // Seconds are stored so they can be compared and exported; the form
        // only ever offers bands. Editing a tasting has to get back to the
        // band, and this mapping had no test when it was written.
        typealias Finish = TastingSheetView.FinishLength
        for band in Finish.allCases where band.seconds != nil {
            XCTAssertEqual(
                Finish.nearest(band.seconds), band,
                "\(band) does not survive being stored and read back")
        }
    }

    func testFinishLengthTreatsNothingRecordedAsNothingRecorded() {
        // Not "brief". A tasting where nobody timed the finish must not
        // come back claiming somebody did.
        XCTAssertEqual(TastingSheetView.FinishLength.nearest(nil), .notRecorded)
        XCTAssertNil(TastingSheetView.FinishLength.notRecorded.seconds)
    }

    func testFinishLengthRoundsAFigureFromSomewhereElseToTheNearestBand() {
        // A figure imported from a spreadsheet, or written by an older
        // build, is not one of our four. It has to land somewhere sensible
        // rather than falling through to "not recorded", which would read
        // as data loss.
        typealias Finish = TastingSheetView.FinishLength
        XCTAssertEqual(Finish.nearest(8), .brief)
        XCTAssertEqual(Finish.nearest(25), .medium)
        XCTAssertEqual(Finish.nearest(50), .long)
        XCTAssertEqual(Finish.nearest(300), .veryLong)
    }

    // MARK: - The class on the bottle screen

    func testEveryClassPrintsWordsRatherThanAStorageKey() {
        // The bottle screen had its own copy of this switch, identical to
        // the engine's for seven classes and falling back to `rawValue` for
        // the rest -- so twenty classes added this week printed
        // "hardCider" and "flavoredWhiskey" at somebody. The copy is gone
        // and the screen reads `ClassType.label`, which means this
        // assertion now covers it.
        for type in ClassType.allCases {
            XCTAssertFalse(type.label.isEmpty, "\(type) has no label")
            XCTAssertNotEqual(type.label, type.rawValue, "\(type) prints its storage key")
        }
    }
}
