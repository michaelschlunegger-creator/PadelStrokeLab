//
//  PadelStrokeLabUITestsLaunchTests.swift
//  PadelStrokeLabUITests
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import XCTest

final class PadelStrokeLabUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--owner-setup-fixture=offline"]
        app.launch()
        XCTAssertTrue(app.scrollViews["homeScreen"].waitForExistence(timeout: 10))

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let appScreenshot = app.screenshot()
        let fullScreenScreenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: appScreenshot)
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        let fullScreenAttachment = XCTAttachment(screenshot: fullScreenScreenshot)
        fullScreenAttachment.name = "Launch Screen-full-screen"
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
        geometry.name = "Launch Screen-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
    }
}
