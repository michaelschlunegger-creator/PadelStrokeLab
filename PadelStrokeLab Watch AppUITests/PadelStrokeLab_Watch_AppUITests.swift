//
//  PadelStrokeLab_Watch_AppUITests.swift
//  PadelStrokeLab Watch AppUITests
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import XCTest

final class PadelStrokeLab_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testArmSelectionResetsConfirmationAndPersistsAcrossLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        let picker = app.descendants(matching: .any)["watchArmPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        capture(app, name: "05-Watch-setup")
        reveal(picker, in: app)
        let initialArm = try XCTUnwrap(picker.value as? String)
        XCTAssertTrue(["Left", "Right"].contains(initialArm), "Picker must expose the selected arm")
        let firstArm = initialArm.contains("Left") ? "Right" : "Left"
        let secondArm = firstArm == "Left" ? "Right" : "Left"
        picker.tap()
        capture(app, name: "06-Watch-arm-picker")
        let first = app.buttons[firstArm]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()

        let confirmation = app.descendants(matching: .any)["watchArmConfirmation"]
        reveal(confirmation, in: app)
        confirmation.tap()
        let status = app.staticTexts["watchSetupStatus"]
        reveal(status, in: app, requiresHittability: false)
        XCTAssertTrue(status.label.contains("Arm confirmed"))
        capture(app, name: "07-Watch-confirmed")

        reveal(picker, in: app, searchTowardStart: true)
        picker.tap()
        let second = app.buttons[secondArm]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()
        reveal(status, in: app, requiresHittability: false)
        XCTAssertTrue(status.label.contains("Check your Watch placement"))

        reveal(confirmation, in: app, searchTowardStart: true)
        confirmation.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.value as? String == secondArm || picker.label.contains(secondArm),
                      "The selected playing arm should survive a fresh launch")
        reveal(status, in: app, requiresHittability: false)
        XCTAssertTrue(status.label.contains("Check your Watch placement"),
                      "Placement confirmation must clear on a fresh process launch")
        capture(app, name: "08-Watch-fresh-launch")
    }

    @MainActor
    func testSimulatorCannotStartAndShowsPhysicalRequirement() throws {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["watchStartRecording"]
        reveal(start, in: app)
        XCTAssertTrue(start.exists)
        XCTAssertFalse(start.isEnabled)
        let issue = app.staticTexts["watchCapabilityIssue"]
        reveal(issue, in: app, requiresHittability: false, searchTowardStart: true)
        XCTAssertTrue(issue.label.contains("physical Apple Watch"))
        let state = app.staticTexts["watchCaptureState"]
        reveal(state, in: app, requiresHittability: false, searchTowardStart: true)
        XCTAssertEqual(state.label, "Ready")
        capture(app, name: "09-Watch-simulator-capability")
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        requiresHittability: Bool = true,
        searchTowardStart: Bool = false
    ) {
        var normalizeToStart = searchTowardStart
        for attempt in 0..<24 {
            let appFrame = app.frame
            // Exclude the clock/navigation title, but retain readable content near the bottom.
            let viewport = CGRect(x: appFrame.minX + 6, y: appFrame.minY + appFrame.height * 0.26,
                                  width: appFrame.width - 12, height: appFrame.height * 0.74 - 6)
            let exists = element.exists
            let frame = exists ? element.frame : .zero
            let visible = frame.intersection(viewport)
            let hittable = exists && element.isHittable
            let hasBounds = !frame.isEmpty && !frame.isNull && !frame.isInfinite
            let isVisible = hasBounds && !visible.isEmpty && !visible.isNull &&
                viewport.contains(CGPoint(x: frame.midX, y: frame.midY)) &&
                visible.height >= min(frame.height, viewport.height) * 0.9
            let target = exists ? element.identifier : "offscreen target"
            XCTContext.runActivity(named: "Reveal \(target), attempt \(attempt + 1): exists=\(exists), frame=\(frame), visible=\(visible), hittable=\(hittable)") { _ in }
            if exists && isVisible && (!requiresHittability || hittable) {
                return
            }
            if hasBounds && frame.midY < viewport.minY {
                normalizeToStart = true
            }
            if normalizeToStart {
                // Native swipes can pass virtualized targets. Seek a stable boundary first,
                // then use the controlled forward scan instead of chasing an absent row.
                let beginning = app.staticTexts["FIRST DRILL"]
                let beginningFrame = beginning.exists ? beginning.frame : .zero
                let atBeginning = !beginningFrame.isEmpty && viewport.contains(beginningFrame)
                XCTContext.runActivity(named: "Normalize to FIRST DRILL: frame=\(beginningFrame), visible=\(atBeginning)") { _ in }
                if atBeginning {
                    normalizeToStart = false
                } else {
                    XCTContext.runActivity(named: "Seek list beginning with a native slow downward swipe") { _ in
                        app.collectionViews.element.swipeDown(velocity: .slow)
                    }
                    continue
                }
            }
            // Stay below the navigation overlay and avoid sweeping past several carousel rows.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTFail("Expected visible Watch content\(requiresHittability ? " with a reachable control" : ""): \(element)")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
