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
        let status = app.descendants(matching: .any)["watchSetupStatus"]
        reveal(status, in: app)
        XCTAssertTrue(status.label.contains("Arm confirmed"))
        capture(app, name: "07-Watch-confirmed")

        reveal(picker, in: app)
        picker.tap()
        let second = app.buttons[secondArm]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()
        reveal(status, in: app)
        XCTAssertTrue(status.label.contains("Check your Watch placement"))

        reveal(confirmation, in: app)
        confirmation.tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.value as? String == secondArm || picker.label.contains(secondArm),
                      "The selected playing arm should survive a fresh launch")
        reveal(status, in: app)
        XCTAssertTrue(status.label.contains("Check your Watch placement"),
                      "Placement confirmation must clear on a fresh process launch")
        capture(app, name: "08-Watch-fresh-launch")
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for direction in [true, false] {
            for _ in 0..<12 {
                let viewport = app.frame.insetBy(dx: 6, dy: 45)
                if element.exists && element.isHittable && viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                    return
                }
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction ? 0.72 : 0.40))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: direction ? 0.40 : 0.72))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            }
        }
        XCTFail("Expected a reachable Watch control: \(element)")
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
