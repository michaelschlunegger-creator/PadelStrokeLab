import XCTest

final class MotionStatisticsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testMotionSignalAccessibilityIdentifiersAreDistinct() throws {
        let app = open(mode: "populated", dark: false)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "SYNTHETIC-motion-accessibility-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertTrue(app.descendants(matching: .any)["userAcceleration-peak"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["rotationRate-peak"].exists)
    }

    @MainActor func testPopulatedDarkAppOnLightOSPortraitAndRawDetails() throws {
        let app = open(mode: "populated", dark: false)
        let scroll = app.scrollViews["recordingDetailScreen"]
        let peak = app.descendants(matching: .any)["userAcceleration-peak"]
        reveal(peak, in: scroll)
        XCTAssertTrue(peak.label.contains("2 g"))
        let trace = app.descendants(matching: .any)["userAccelerationTrace"]
        reveal(trace, in: scroll)
        XCTAssertTrue(trace.label.contains("Wrist acceleration trace"))
        XCTAssertTrue((trace.value as? String ?? "").contains("80 eligible samples"))
        capture("SYNTHETIC-dark-app-light-OS-wrist-acceleration")
        let rotation = app.descendants(matching: .any)["rotationRate-peak"]
        reveal(rotation, in: scroll)
        XCTAssertTrue(rotation.label.contains("180 °/s"))
        capture("SYNTHETIC-dark-app-light-OS-rotation")
        let raw = app.buttons["rawAccelerationDisclosure"]
        reveal(raw, in: scroll); raw.tap()
        let rawPeak = app.descendants(matching: .any)["rawAcceleration-peak"]
        reveal(rawPeak, in: scroll)
        XCTAssertTrue(rawPeak.label.contains("5 g"))
        capture("SYNTHETIC-dark-app-light-OS-raw-acceleration")
    }

    @MainActor func testLargestTextDarkPortrait() throws {
        let app = open(mode: "populated", dark: true, large: true)
        let scroll = app.scrollViews["recordingDetailScreen"]
        let peak = app.descendants(matching: .any)["userAcceleration-peak"]
        reveal(peak, in: scroll)
        XCTAssertTrue(peak.label.contains("2 g"))
        capture("SYNTHETIC-dark-largest-portrait")
        let rotation = app.descendants(matching: .any)["rotationRate-peak"]
        reveal(rotation, in: scroll)
        XCTAssertTrue(rotation.label.contains("180 °/s"))
    }

    @MainActor func testLargestTextDarkLandscape() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = open(mode: "populated", dark: true, large: true, landscape: true)
        let peak = app.descendants(matching: .any)["userAcceleration-peak"]
        reveal(peak, in: app.scrollViews["recordingDetailScreen"])
        XCTAssertTrue(peak.label.contains("2 g"))
        capture("SYNTHETIC-dark-largest-landscape")
    }

    @MainActor func testUnavailableTimelineShowsExplanation() throws {
        let app = open(mode: "unavailable", dark: false)
        let message = app.staticTexts["motionStatisticsUnavailable"]
        reveal(message, in: app.scrollViews["recordingDetailScreen"])
        XCTAssertTrue(message.label.contains("known active intervals"))
        XCTAssertFalse(app.descendants(matching: .any)["userAcceleration-peak"].exists)
        capture("SYNTHETIC-unavailable")
    }

    @MainActor func testInterruptedRetainsQualifiedStatistics() throws {
        let app = open(mode: "interrupted", dark: true)
        let message = app.staticTexts["motionInterruptedNotice"]
        reveal(message, in: app.scrollViews["recordingDetailScreen"])
        XCTAssertEqual(message.label, "Retained portion — interrupted")
        let peak = app.descendants(matching: .any)["userAcceleration-peak"]
        reveal(peak, in: app.scrollViews["recordingDetailScreen"])
        XCTAssertTrue(peak.label.contains("2 g"))
        capture("SYNTHETIC-interrupted")
    }

    @MainActor func testDeletionSheetCancelSwipeRetainAndConfirmDeletesOnlyFixture() throws {
        let app = open(mode: "populated", dark: true)
        let detail = app.scrollViews["recordingDetailScreen"]
        let delete = app.buttons["deletePhoneRecording"]
        let warning = "This removes this iPhone's raw recording and owner labels. The Watch original stays on your Watch. Exported or shared copies remain outside this deletion."
        reveal(delete, in: detail)
        delete.tap()
        let confirmation = app.scrollViews["deleteConfirmationSheet"]
        let cancel = app.buttons["cancelPhoneDeletion"]
        let confirm = app.buttons["confirmPhoneDeletion"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.staticTexts["Delete this iPhone copy?"].exists)
        XCTAssertEqual(confirmation.staticTexts["deleteConfirmationWarning"].label, warning)
        XCTAssertEqual(cancel.label, "Cancel")
        XCTAssertEqual(confirm.label, "Delete iPhone copy")
        XCTAssertTrue(cancel.isHittable)
        XCTAssertTrue(confirm.isHittable)
        capture("SYNTHETIC-A3-delete-warning")
        cancel.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(detail.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let library = app.scrollViews["recordingsScreen"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        let item = app.buttons["recording-A6201020-0007-4000-8000-000000000001"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        reveal(item, in: library)
        capture("SYNTHETIC-A3-cancel-retains-fixture")
        item.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        reveal(delete, in: detail)
        delete.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        let grabber = app.buttons["Sheet Grabber"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        XCTAssertTrue(grabber.isHittable)
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(detail.exists)
        delete.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertEqual(confirmation.staticTexts["deleteConfirmationWarning"].label, warning)
        // open() selects only the existing isolated temporary populated fixture.
        confirm.doubleTap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertFalse(detail.exists)
        XCTAssertFalse(item.exists)
        XCTAssertTrue(app.descendants(matching: .any)["recordingsEmptyState"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SYNTHETIC UI REVIEW"].exists)
        capture("SYNTHETIC-A3-deleted-fixture-empty-library")
    }

    @MainActor private func open(mode: String, dark: Bool, large: Bool = false,
                                landscape: Bool = false) -> XCUIApplication {
        let originalAppearance = XCUIDevice.shared.appearance
        addTeardownBlock {
            await MainActor.run { XCUIDevice.shared.appearance = originalAppearance }
        }
        XCUIDevice.shared.appearance = dark ? .dark : .light
        XCTAssertEqual(XCUIDevice.shared.appearance, dark ? .dark : .light)
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--motion-statistics-fixture=\(mode)"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let home = app.scrollViews["homeScreen"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        let sessions = app.buttons["recordingLibraryLink"]
        reveal(sessions, in: home); sessions.tap()
        let library = app.scrollViews["recordingsScreen"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["SYNTHETIC UI REVIEW"].exists)
        let item = app.buttons["recording-A6201020-0007-4000-8000-000000000001"]
        XCTAssertTrue(item.waitForExistence(timeout: 10)); reveal(item, in: library); item.tap()
        XCTAssertTrue(app.scrollViews["recordingDetailScreen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["syntheticReviewNotice"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
        var previousPan: (midY: CGFloat, distance: CGFloat, direction: CGFloat)?
        for _ in 0..<40 {
            let viewport = scroll.frame
            let navigation = XCUIApplication().navigationBars.firstMatch
            let top = max(viewport.minY, navigation.exists ? navigation.frame.maxY : viewport.minY)
            let frame = CGRect(x: viewport.minX + 4, y: top + 8,
                               width: viewport.width - 8, height: max(1, viewport.maxY - top - 28))
            if element.exists && element.isHittable {
                let target = element.frame
                let fits = target.width <= frame.width && target.height <= frame.height
                if fits ? frame.contains(target) : frame.contains(CGPoint(x: target.midX, y: target.midY)) { return }
            }
            if element.exists && !element.frame.isEmpty {
                let target = element.frame
                var panLoss: CGFloat = 0
                if let previousPan {
                    let movement = (target.midY - previousPan.midY) * previousPan.direction
                    // Compensate measured pan activation loss without imposing a minimum final scroll.
                    let unconsumed = movement < 1 ? previousPan.distance + frame.height * 0.05
                        : max(0, previousPan.distance - movement)
                    if movement >= 0 { panLoss = min(unconsumed, frame.height * 0.2) }
                }
                let distance = min(abs(target.midY - frame.midY) + panLoss, frame.height * 0.7)
                let direction: CGFloat = target.midY < frame.midY ? 1 : -1
                previousPan = (target.midY, distance, direction)
                let origin = scroll.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: frame.midX - viewport.minX,
                    dy: frame.midY - viewport.minY - direction * distance / 2))
                let end = origin.withOffset(CGVector(dx: frame.midX - viewport.minX,
                    dy: frame.midY - viewport.minY + direction * distance / 2))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            } else {
                previousPan = nil
                scroll.swipeUp(velocity: .slow)
            }
        }
        capture("SYNTHETIC-motion-reveal-failure")
        let evidence = XCTAttachment(string: "Target: \(element.debugDescription)\nViewport: \(scroll.frame)\n\n\(XCUIApplication().debugDescription)")
        evidence.name = "SYNTHETIC-motion-reveal-geometry"; evidence.lifetime = .keepAlways; add(evidence)
        XCTFail("Expected visible element: \(element)")
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
