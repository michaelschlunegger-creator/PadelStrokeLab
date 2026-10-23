import XCTest

final class PadelStrokeLab_Watch_AppUITests: WatchFixtureUITestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testUnpreparedOwnerCannotOpenLocalStart() throws {
        let app = launch(id: UUID())
        let check = app.buttons["watchLetsPlay"]
        reveal(check, in: app, hittable: false)
        XCTAssertTrue(check.waitForExistence(timeout: 10)); XCTAssertFalse(check.isEnabled)
        let status = app.staticTexts["watchOwnerStatus"]
        reveal(status, in: app, hittable: false)
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Prepare this Watch on your iPhone"), evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(status.label.contains("Prepare this Watch on your iPhone"))
        let banner = app.staticTexts["watchFixtureBanner"]
        reveal(banner, in: app, hittable: false)
        XCTAssertTrue(banner.label.contains("sensors disabled"))
        XCTAssertFalse(app.buttons["watchStart"].exists)
        capture(app, name: "O5-unprepared-owner-denied")
    }
    @MainActor func testForehandPhoneAcceptanceAndHonestSimulatorBlocker() throws {
        try exerciseAcceptedCheck(drill: "forehandGroundstroke", title: "Forehand groundstroke")
    }
    @MainActor func testBackhandPhoneAcceptanceAndHonestSimulatorBlocker() throws {
        try exerciseAcceptedCheck(drill: "backhandGroundstroke", title: "Backhand groundstroke")
    }
    @MainActor func testRelaunchDoesNotReconstructAcceptedPreparation() throws {
        let id = UUID(), app = launch(id: id, drill: "forehandGroundstroke")
        waitForEnabled(app.buttons["watchLetsPlay"], in: app)
        tap("watchLetsPlay", in: app); tap("watchConfirmPlacement", in: app)
        app.terminate()
        app.launch() // Same validated UUID and persisted fixture owner; no reset or new seed.
        let check = app.buttons["watchLetsPlay"]
        reveal(check, in: app, hittable: false)
        XCTAssertTrue(check.exists); XCTAssertFalse(check.isEnabled)
        let status = app.staticTexts["watchOwnerStatus"]
        reveal(status, in: app, hittable: false)
        let ready = NSPredicate(format: "label CONTAINS %@", "Prepare this Watch on your iPhone")
        expectation(for: ready, evaluatedWith: status); waitForExpectations(timeout: 10)
        XCTAssertFalse(app.buttons["watchStart"].exists)
        capture(app, name: "O5-relaunch-requires-new-phone-acceptance")
    }
    @MainActor func testCancelRequiresFreshPhysicalCheck() throws {
        let app = launch(id: UUID(), drill: "forehandGroundstroke")
        waitForEnabled(app.buttons["watchLetsPlay"], in: app); tap("watchLetsPlay", in: app)
        tap("watchConfirmPlacement", in: app); tap("watchConfirmOrientation", in: app); tap("watchConfirmFit", in: app)
        tap("watchSetupCancel", in: app)
        tap("watchLetsPlay", in: app)
        let placement = app.buttons["watchConfirmPlacement"]
        reveal(placement, in: app)
        XCTAssertEqual(placement.label, "Watch is on my racket arm")
        let orientation = app.buttons["watchConfirmOrientation"]
        reveal(orientation, in: app); XCTAssertFalse(orientation.isEnabled)
        capture(app, name: "O5-cancel-clears-physical-check")
    }
    @MainActor func testLeavingForegroundRequiresFreshPhysicalCheck() throws {
        let app = launch(id: UUID(), drill: "forehandGroundstroke")
        waitForEnabled(app.buttons["watchLetsPlay"], in: app); tap("watchLetsPlay", in: app)
        tap("watchConfirmPlacement", in: app); tap("watchConfirmOrientation", in: app); tap("watchConfirmFit", in: app)
        XCUIDevice.shared.press(.home); app.activate()
        let placement = app.buttons["watchConfirmPlacement"]
        // Return within the same check and fixture identity.
        reveal(placement, in: app, searchDirection: 1)
        XCTAssertEqual(placement.label, "Watch is on my racket arm")
        let start = app.buttons["watchStart"]
        reveal(start, in: app); XCTAssertFalse(start.isEnabled)
        capture(app, name: "O5-background-clears-unadmitted-check")
    }
    @MainActor private func exerciseAcceptedCheck(drill: String, title: String) throws {
        let app = launch(id: UUID(), drill: drill)
        waitForEnabled(app.buttons["watchLetsPlay"], in: app); tap("watchLetsPlay", in: app)
        let header = app.staticTexts["watchSetupProgress"]
        XCTAssertTrue(header.waitForExistence(timeout: 10)); XCTAssertEqual(header.label, "Quick Watch check")
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertFalse(app.buttons["watchShotPicker"].exists)
        tap("watchConfirmPlacement", in: app)
        tap("watchConfirmOrientation", in: app)
        tap("watchConfirmFit", in: app)
        let issue = app.staticTexts["watchCapabilityIssue"]
        reveal(issue, in: app, hittable: false)
        XCTAssertEqual(issue.label, "An isolated motion source is required for this fixture.")
        let start = app.buttons["watchStart"]
        reveal(start, in: app); XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(app.buttons["watchPauseRecording"].exists)
        capture(app, name: "O5-\(drill)-local-start-blocked-on-simulator")
    }
    @MainActor private func launch(id: UUID, drill: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--owner-watch-fixture=\(id.uuidString)"]
        if let drill { app.launchArguments += ["--owner-watch-prepared=\(drill)", "--owner-watch-match-wrist"] }
        app.launch(); return app
    }
    @MainActor private func waitForEnabled(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let element = app.buttons[id]; reveal(element, in: app)
        XCTAssertTrue(element.isEnabled, "Disabled control: \(id)"); element.tap()
    }
    @MainActor func testLaunchPerformance() throws {
        // Simulator synthetic-launch regression; one fresh fixture persists across measured relaunches.
        let app = XCUIApplication(), fixtureID = UUID()
        app.launchArguments = ["--owner-watch-fixture=\(fixtureID.uuidString)"]
        measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
        let check = app.buttons["watchLetsPlay"]
        reveal(check, in: app, hittable: false)
        XCTAssertTrue(check.waitForExistence(timeout: 10)); XCTAssertFalse(check.isEnabled)
        let status = app.staticTexts["watchOwnerStatus"]
        reveal(status, in: app, hittable: false)
        XCTAssertTrue(status.label.contains("Prepare this Watch on your iPhone"))
        let banner = app.staticTexts["watchFixtureBanner"]
        reveal(banner, in: app, hittable: false)
        XCTAssertTrue(banner.label.contains("sensors disabled"))
        XCTAssertFalse(app.buttons["watchStart"].exists)
    }
}

class WatchFixtureUITestCase: XCTestCase {
    @MainActor func reveal(_ element: XCUIElement, in app: XCUIApplication, hittable: Bool = true,
                                   searchDirection: CGFloat = -1) {
        var direction = searchDirection, lastPosition: CGFloat?, lastStep: CGFloat = 0, missing = 0
        var trace: [String] = []
        for attempt in 0..<14 {
            let collection = app.collectionViews.firstMatch
            let surface = collection.exists ? collection : app
            let bounds = app.frame.intersection(surface.frame)
            let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame)
                .filter { !$0.isEmpty && $0.intersects(bounds) }
            let top = max(bounds.minY, bars.map(\.maxY).max() ?? bounds.minY)
            let viewport = CGRect(x: bounds.minX, y: top, width: max(0, bounds.width),
                                  height: max(0, bounds.maxY - top - 8))
            guard !viewport.isEmpty, viewport.width.isFinite, viewport.height.isFinite else { break }
            var distance: CGFloat
            if element.exists {
                let frame = element.frame
                guard !frame.isEmpty, frame.midX.isFinite, frame.midY.isFinite else { break }
                trace.append("\(attempt): viewport=\(viewport), target=\(frame)")
                let contained = frame.height <= viewport.height ? viewport.contains(frame)
                    : frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
                        && viewport.contains(CGPoint(x: frame.midX, y: frame.midY))
                if contained, !hittable || element.isHittable { return }
                missing = 0; lastPosition = frame.midY
                distance = max(-viewport.height * 0.3, min(viewport.height * 0.3, viewport.midY - frame.midY))
                if abs(distance) < 2 { distance = direction * viewport.height * 0.15 }
                direction = distance < 0 ? -1 : 1
            } else {
                if searchDirection > 0 {
                    // After foreground return, ask the native collection to reveal earlier rows.
                    func visibleAnchors() -> String {
                        app.buttons.allElementsBoundByIndex.compactMap { button in
                            guard button.exists else { return nil }
                            let frame = button.frame
                            return frame.intersects(viewport) ? "\(button.label): \(frame)" : nil
                        }.joined(separator: "; ")
                    }
                    trace.append("\(attempt): native swipeDown before: \(visibleAnchors())")
                    surface.swipeDown()
                    trace.append("\(attempt): native swipeDown after: \(visibleAnchors())")
                    continue
                }
                missing += 1
                if let position = lastPosition {
                    direction = position < viewport.midY ? 1 : -1
                    if position >= viewport.minY && position <= viewport.maxY { direction = lastStep < 0 ? 1 : -1 }
                    lastPosition = nil
                } else if missing == 7 { direction *= -1 }
                distance = direction * viewport.height * 0.2
                trace.append("\(attempt): viewport=\(viewport), target absent, distance=\(distance)")
            }
            let startY = viewport.minY + viewport.height * (distance < 0 ? 0.75 : 0.25)
            let start = surface.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: viewport.midX - surface.frame.minX, dy: startY - surface.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
            if let position = lastPosition { lastPosition = position + distance }
            lastStep = distance
        }
        capture(app, name: "O5-Watch-reveal-failure")
        let evidence = XCTAttachment(string: trace.joined(separator: "\n") + "\n\n" + app.debugDescription)
        evidence.name = "O5-Watch-reveal-geometry-accessibility"; evidence.lifetime = .keepAlways; add(evidence)
        XCTFail("Expected Watch content was not visible after bounded navigation.")
    }
    @MainActor func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}
