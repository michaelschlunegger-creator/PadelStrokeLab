//
//  PadelStrokeLab_Watch_AppUITestsLaunchTests.swift
//  PadelStrokeLab Watch AppUITests
//
//  Created by Michael Schlunegger on 24/08/2026.
//

import XCTest

final class PadelStrokeLab_Watch_AppUITestsLaunchTests: WatchFixtureUITestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication(), fixtureID = UUID()
        app.launchArguments = ["--owner-watch-fixture=\(fixtureID.uuidString)"]
        app.launch()
        let check = app.buttons["watchLetsPlay"]
        reveal(check, in: app, hittable: false)
        XCTAssertTrue(check.waitForExistence(timeout: 10)); XCTAssertFalse(check.isEnabled)
        let status = app.staticTexts["watchOwnerStatus"]
        reveal(status, in: app, hittable: false)
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Prepare this Watch on your iPhone"))
        let banner = app.staticTexts["watchFixtureBanner"]
        reveal(banner, in: app, hittable: false)
        XCTAssertTrue(banner.exists && banner.label.contains("sensors disabled"))
        XCTAssertFalse(app.buttons["watchStart"].exists)

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
