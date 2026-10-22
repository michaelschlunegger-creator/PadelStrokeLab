import XCTest
import UIKit

// Private O10 proposal. Fixed DEBUG fixture modes create actual isolated stores;
// no UI-only rows, default data, real connectivity or Health data are used.
final class OwnerPracticeReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testBothManualStrokesHaveOwnerCoverageAndExplicitExportPreview() throws {
        let app = open(mode: "included")
        let screen = app.scrollViews["recordingDetailScreen"]
        let scope = app.staticTexts["ownerPracticeScope"]
        reveal(scope, in: screen)
        XCTAssertTrue(scope.label.localizedCaseInsensitiveContains("owner"))
        let intent = app.staticTexts["recordedIntendedShotType"]
        reveal(intent, in: screen)
        XCTAssertTrue(intent.label.localizedCaseInsensitiveContains("forehand"))
        let measurement = app.staticTexts["ownerPracticeMeasurementNotice"]
        reveal(measurement, in: screen)
        XCTAssertTrue(measurement.label.localizedCaseInsensitiveContains("manual"))
        XCTAssertTrue(measurement.label.localizedCaseInsensitiveContains("quality"))
        let heart = app.staticTexts["ownerHeartRateCoverage"]
        reveal(heart, in: screen); XCTAssertFalse(heart.label.isEmpty)
        let recovery = app.staticTexts["ownerRecovery60"]
        reveal(recovery, in: screen)
        XCTAssertTrue(recovery.label.localizedCaseInsensitiveContains("missing"), "Sparse fixture must not invent a 60-second recovery value")
        let export = app.buttons["prepareRecordingExport"]
        reveal(export, in: screen); export.tap()
        let preview = app.scrollViews["ownerPracticeExportPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        for identifier in ["exportWearer", "exportPracticeInventory", "exportHeartRateInclusion"] {
            let element = app.staticTexts[identifier]; reveal(element, in: preview)
            XCTAssertFalse(element.label.isEmpty)
        }
        let inventory = app.staticTexts["exportPracticeInventory"].label.lowercased()
        XCTAssertTrue(inventory.contains("forehand") && inventory.contains("backhand"))
        XCTAssertFalse(app.buttons["shareRecordingExport"].exists, "Review the scope before preparing a shareable file")
        app.buttons["confirmPracticeExport"].tap()
        XCTAssertTrue(app.buttons["shareRecordingExport"].waitForExistence(timeout: 5))
        capture("SYNTHETIC-O10-owner-export-reviewed", app)
    }

    @MainActor func testExcludedAbsentAndLegacyEvidenceNeverInventsHeartRate() {
        for mode in ["excluded", "absent", "legacy"] {
            let app = open(mode: mode)
            let screen = app.scrollViews["recordingDetailScreen"]
            if mode == "legacy" {
                let legacy = app.staticTexts["legacyOwnerEvidenceNotice"]
                reveal(legacy, in: screen)
                XCTAssertTrue(legacy.label.localizedCaseInsensitiveContains("unassigned"))
                XCTAssertFalse(app.staticTexts["ownerPracticeScope"].exists)
                XCTAssertFalse(app.buttons["deleteEntirePractice"].exists)
            } else {
                let coverage = app.staticTexts["ownerHeartRateCoverage"]
                reveal(coverage, in: screen)
                XCTAssertTrue(coverage.label.localizedCaseInsensitiveContains(mode == "excluded" ? "excluded" : "no accessible"))
                XCTAssertFalse(app.otherElements["ownerHeartRateTrace"].exists)
            }
            capture("SYNTHETIC-O10-\(mode)", app)
            app.terminate()
        }
    }

    @MainActor func testWholePracticeDeleteRequiresExplicitScopeAndShowsPeerPending() {
        let app = open(mode: "included")
        let screen = app.scrollViews["recordingDetailScreen"]
        let delete = app.buttons["deleteEntirePractice"]
        reveal(delete, in: screen); delete.tap()
        let sheet = app.scrollViews["deleteConfirmationSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let warning = app.staticTexts["deleteConfirmationWarning"]
        reveal(warning, in: sheet)
        let text = warning.label.lowercased()
        XCTAssertTrue(text.contains("entire practice") && text.contains("both"))
        XCTAssertTrue(text.contains("export") && text.contains("health"))
        app.buttons["cancelPracticeDeletion"].tap()
        XCTAssertTrue(screen.waitForExistence(timeout: 5))
        reveal(delete, in: screen); delete.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        app.buttons["confirmPracticeDeletion"].tap()
        let pending = app.staticTexts["practiceDeletionStatus"]
        XCTAssertTrue(pending.waitForExistence(timeout: 10))
        XCTAssertTrue(pending.label.localizedCaseInsensitiveContains("Watch cleanup pending"))
        XCTAssertFalse(pending.label.localizedCaseInsensitiveContains("both devices deleted"))
        capture("SYNTHETIC-O10-delete-peer-pending", app)
    }

    @MainActor func testLargestTextPortraitReviewAccessibility() throws { try largeText(.portrait) }
    @MainActor func testLargestTextLandscapeReviewAccessibility() throws { try largeText(.landscapeLeft) }
    @MainActor func testStandardTextPortraitReviewContrast() throws { try standardTextContrast(.portrait) }
    @MainActor func testStandardTextLandscapeReviewContrast() throws { try standardTextContrast(.landscapeLeft) }

    @MainActor private func standardTextContrast(_ orientation: UIDeviceOrientation) throws {
        let app = open(mode: "included", orientation: orientation)
        try app.performAccessibilityAudit(for: [.contrast])
        capture("SYNTHETIC-O10-standard-initial-\(orientation.rawValue)", app)
        let export = app.buttons["prepareRecordingExport"]
        reveal(export, in: app.scrollViews["recordingDetailScreen"])
        XCTAssertTrue(export.isHittable && export.isEnabled)
        // Capture scrolled controls for rendered-color review. Native audits run at the
        // canonical initial position, where scroll-edge occlusion cannot corrupt their crops.
        capture("SYNTHETIC-O10-standard-export-\(orientation.rawValue)", app)
    }

    @MainActor private func largeText(_ orientation: UIDeviceOrientation) throws {
        let app = open(mode: "included", large: true, orientation: orientation)
        try app.performAccessibilityAudit(for: [.contrast, .sufficientElementDescription, .hitRegion, .textClipped, .trait]) { issue in
            print("O10 audit type: \(issue.auditType)")
            print("O10 audit compact description: \(issue.compactDescription)")
            print("O10 audit detailed description: \(issue.detailedDescription)")
            print("O10 audit offending element: \(issue.element?.debugDescription ?? "<nil>")")
            self.capture("SYNTHETIC-O10-audit-issue-\(orientation.rawValue)", app)
            return false
        }
        let scroll = app.scrollViews["recordingDetailScreen"]
        capture("SYNTHETIC-O10-largest-initial-\(orientation.rawValue)", app)
        let receipt = app.staticTexts["Verified receipt on this iPhone"]
        reveal(receipt, in: scroll)
        captureElement("hero-receipt-\(orientation.rawValue)", receipt, app)
        captureElement("navigation-\(orientation.rawValue)", app.navigationBars.firstMatch, app)
        for identifier in ["ownerPracticeScope", "ownerHeartRateCoverage", "ownerRecovery60"] {
            let value = app.staticTexts[identifier]
            reveal(value, in: scroll)
            XCTAssertTrue(value.isHittable && !value.label.isEmpty)
            XCTAssertLessThanOrEqual(value.frame.width, scroll.frame.width)
            captureElement("\(identifier)-\(orientation.rawValue)", value, app)
        }
        let addAttempt = app.buttons["addAttempt"]
        reveal(addAttempt, in: scroll)
        XCTAssertTrue(addAttempt.isHittable && addAttempt.isEnabled && !addAttempt.label.isEmpty)
        captureElement("addAttempt-\(orientation.rawValue)", addAttempt, app)
        let intendedShot = app.staticTexts["recordedIntendedShotType"]
        reveal(intendedShot, in: scroll)
        XCTAssertTrue(intendedShot.isHittable && !intendedShot.label.isEmpty)
        XCTAssertLessThanOrEqual(intendedShot.frame.width, scroll.frame.width)
        captureElement("intendedShot-\(orientation.rawValue)", intendedShot, app)
        XCTAssertEqual(app.staticTexts["recordedDrillRawValue"].label, "Stored value: forehandGroundstroke")
        XCTAssertEqual(app.staticTexts["recordedProtocolVersion"].label, "Protocol: owner-manual-training-logger-1")
        for identifier in ["prepareRecordingExport", "deleteEntirePractice"] {
            let button = app.buttons[identifier]; reveal(button, in: scroll)
            XCTAssertTrue(button.isHittable && button.isEnabled && !button.label.isEmpty)
            captureElement("\(identifier)-\(orientation.rawValue)", button, app)
        }
        let secondary = app.staticTexts["Nothing is automatically uploaded to a public or shared folder."]
        reveal(secondary, in: scroll)
        XCTAssertTrue(secondary.isHittable && !secondary.label.isEmpty)
        captureElement("secondary-\(orientation.rawValue)", secondary, app)
        // These retained screenshots are the explicit visual-review evidence for the existing
        // black/turquoise/white theme; a successful audit alone does not certify the palette.
        capture("SYNTHETIC-O10-largest-\(orientation.rawValue)", app)
    }

    @MainActor private func open(mode: String, large: Bool = false, orientation: UIDeviceOrientation = .portrait) -> XCUIApplication {
        let originalAppearance = XCUIDevice.shared.appearance
        addTeardownBlock { await MainActor.run { XCUIDevice.shared.appearance = originalAppearance; XCUIDevice.shared.orientation = .portrait } }
        XCUIDevice.shared.appearance = .dark; XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = ["--owner-practice-review-fixture=\(mode)"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let home = app.scrollViews["homeScreen"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        let sessions = app.buttons["recordingLibraryLink"]
        reveal(sessions, in: home); sessions.tap()
        let library = app.scrollViews["recordingsScreen"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["SYNTHETIC UI REVIEW"].exists)
        let row = app.buttons["recording-A6201022-0010-4000-8000-000000000001"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); reveal(row, in: library); row.tap()
        XCTAssertTrue(app.scrollViews["recordingDetailScreen"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
        for _ in 0..<30 {
            let navigation = XCUIApplication().navigationBars.firstMatch
            let top = max(scroll.frame.minY, navigation.exists ? navigation.frame.maxY : scroll.frame.minY)
            let viewport = CGRect(x: scroll.frame.minX + 4, y: top + 8, width: scroll.frame.width - 8,
                height: max(1, scroll.frame.maxY - top - 28))
            if element.exists && element.isHittable && viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { return }
            if element.exists && !element.frame.isEmpty {
                // A fast flick can jump over a target repeatedly in landscape. Once its
                // frame is known, drag only the distance needed within the usable viewport.
                let distance = min(abs(element.frame.midY - viewport.midY), viewport.height * 0.7)
                let direction: CGFloat = element.frame.midY < viewport.midY ? 1 : -1
                let origin = scroll.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: viewport.midX - scroll.frame.minX,
                    dy: viewport.midY - scroll.frame.minY - direction * distance / 2))
                let end = origin.withOffset(CGVector(dx: viewport.midX - scroll.frame.minX,
                    dy: viewport.midY - scroll.frame.minY + direction * distance / 2))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            } else {
                scroll.swipeUp(velocity: .fast)
            }
        }
        XCTFail("Required review control was not reachable: \(element)")
    }
    @MainActor private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
    @MainActor private func captureElement(_ name: String, _ element: XCUIElement, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: element.screenshot())
        image.name = "SYNTHETIC-O10-role-" + name; image.lifetime = .keepAlways; add(image)
        let geometry = XCTAttachment(string: "\(element.debugDescription)\nWindow: \(app.frame)")
        geometry.name = "SYNTHETIC-O10-role-" + name + "-geometry"
        geometry.lifetime = .keepAlways; add(geometry)
        capture("SYNTHETIC-O10-viewport-" + name, app)
    }
}
