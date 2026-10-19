//
//  PadelStrokeLabUITests.swift
//  PadelStrokeLabUITests
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import XCTest

final class PadelStrokeLabUITests: XCTestCase {

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
    func testPracticeGuidesAndBackNavigation() throws {
        try checkGuides(orientation: .portrait, largeText: false)
    }

    @MainActor
    func testLargestTextPortraitGuides() throws {
        try checkGuides(orientation: .portrait, largeText: true)
    }

    @MainActor
    func testLargestTextLandscapeGuides() throws {
        try checkGuides(orientation: .landscapeLeft, largeText: true)
    }

    @MainActor
    private func checkGuides(orientation: UIDeviceOrientation, largeText: Bool) throws {
        XCUIDevice.shared.orientation = orientation
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                                    "-AppleInterfaceStyle", "Dark"]
        }
        app.launch()
        let home = app.scrollViews["homeScreen"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        capture(app, name: "01-Practice-home")

        let practice = app.buttons["practiceGuideLink"]
        reveal(practice, in: home)
        practice.tap()
        let practiceGuide = app.scrollViews["practiceGuideScreen"]
        XCTAssertTrue(practiceGuide.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your training set"].exists)
        let intent = app.staticTexts["trainingSetGuidance"]
        reveal(intent, in: practiceGuide)
        XCTAssertTrue(intent.label.contains("one intended shot type per short set"))
        for title in ["Forehand groundstroke", "Backhand groundstroke", "Forehand volley", "Backhand volley",
                      "Serve", "Lob", "Bandeja", "Víbora", "Smash", "Other / unclassified"] {
            let choice = app.staticTexts[title]
            reveal(choice, in: practiceGuide)
            XCTAssertTrue(choice.exists, "Missing intended type: \(title)")
        }
        let firstTest = app.staticTexts["firstAttemptGuidance"]
        reveal(firstTest, in: practiceGuide)
        XCTAssertTrue(firstTest.label.contains("one attempt per set"))
        XCTAssertTrue(firstTest.label.contains("No automatic contact score"))
        let uncertainty = app.staticTexts["trainingUncertaintyGuidance"]
        reveal(uncertainty, in: practiceGuide)
        XCTAssertTrue(uncertainty.label.contains("not an independent measurement"))
        capture(app, name: "02-Practice-guide")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 5))

        let contact = app.buttons["contactGuideLink"]
        reveal(contact, in: home)
        contact.tap()
        let contactGuide = app.scrollViews["contactGuideScreen"]
        XCTAssertTrue(contactGuide.waitForExistence(timeout: 5))
        capture(app, name: "03-Contact-guide")
        for title in ["Clean contact", "Mishit", "Uncertain", "Air swing", "Other movement"] {
            let label = app.staticTexts[title]
            reveal(label, in: contactGuide)
            XCTAssertTrue(label.exists, "Missing reference category: \(title)")
        }
        capture(app, name: "04-Contact-guide-lower")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        let notice = app.descendants(matching: .any)["preparationNotice"]
        reveal(notice, in: home)
        XCTAssertTrue(notice.label.contains("Record on your Watch"))
    }

    @MainActor
    func testSessionsEmptyStateAndBackNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        let home = app.scrollViews["homeScreen"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        let sessions = app.buttons["recordingLibraryLink"]
        reveal(sessions, in: home)
        sessions.tap()
        let library = app.scrollViews["recordingsScreen"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Record your first set on your Watch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["refreshRecordings"].exists)
        capture(app, name: "05-Sessions-empty")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 5))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<40 {
            let viewport = scrollView.frame.insetBy(dx: 4, dy: 20)
            if element.exists && element.isHittable && viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) {
                return
            }
            let upward = !element.exists || element.frame.midY > viewport.midY
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.70 : 0.35))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.35 : 0.70))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTFail("Expected an accessible, visible element: \(element)")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let appScreenshot = app.screenshot()
        let fullScreenScreenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: appScreenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let fullScreenAttachment = XCTAttachment(screenshot: fullScreenScreenshot)
        fullScreenAttachment.name = "\(name)-full-screen"
        fullScreenAttachment.lifetime = .keepAlways
        add(fullScreenAttachment)

        let appImage = appScreenshot.image
        let fullScreenImage = fullScreenScreenshot.image
        let windowFrames = app.windows.allElementsBoundByIndex.enumerated().map {
            "window[\($0.offset)] frame=\($0.element.frame)"
        }.joined(separator: "\n")
        let geometry = XCTAttachment(string: """
        deviceOrientation=\(XCUIDevice.shared.orientation) rawValue=\(XCUIDevice.shared.orientation.rawValue)
        appFrame=\(app.frame)
        \(windowFrames)
        appScreenshot size=\(appImage.size) scale=\(appImage.scale) imageOrientation=\(appImage.imageOrientation) rawValue=\(appImage.imageOrientation.rawValue)
        fullScreenScreenshot size=\(fullScreenImage.size) scale=\(fullScreenImage.scale) imageOrientation=\(fullScreenImage.imageOrientation) rawValue=\(fullScreenImage.imageOrientation.rawValue)
        """)
        geometry.name = "\(name)-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
