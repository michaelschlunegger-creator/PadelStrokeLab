import XCTest
import UIKit

final class OwnerPracticeSetupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testEveryHandAndWristPairRequiresExplicitAnswersAndMirrorsGuidance() {
        let app = openSetup()
        let scroll = app.scrollViews["practiceSetupScreen"]
        XCTAssertFalse(app.staticTexts["watchPlacementGuidance"].exists)
        for identifier in ["ownerAttestation", "motionStudyConsent"] {
            let toggle = app.switches[identifier]
            let native = toggle.descendants(matching: .switch).firstMatch
            XCTAssertTrue(native.waitForExistence(timeout: 5))
            XCTAssertTrue(centerInteractiveControl(native, in: scroll, app: app))
            native.tap()
            XCTAssertEqual(toggle.value as? String, "1")
        }
        let prepare = app.buttons["reviewAndPrepare"]
        reveal(prepare, in: scroll)
        XCTAssertFalse(prepare.isEnabled, "Consent alone cannot complete unanswered local setup.")
        for arm in ["Right", "Left"] {
            choose("setupRacketArm", value: arm, app: app, scroll: scroll)
            XCTAssertFalse(app.staticTexts["watchPlacementGuidance"].exists)
            assertNativeChoice(app.buttons["setupCurrentWrist"], title: "Which wrist is your Watch on now?", choice: "Choose")
            reveal(prepare, in: scroll)
            XCTAssertFalse(prepare.isEnabled, "Changing the racket hand must invalidate the wrist answer.")
            for wrist in ["Left", "Right"] {
                choose("setupCurrentWrist", value: wrist, app: app, scroll: scroll)
                let guidance = app.staticTexts["watchPlacementGuidance"]
                reveal(guidance, in: scroll)
                XCTAssertEqual(guidance.label, arm == wrist
                    ? "Your Watch is already on your \(arm.lowercased()) racket arm."
                    : "Move your Watch to your \(arm.lowercased()) wrist.")
                let orientation = app.staticTexts["phoneWatchOrientationGuidance"]
                reveal(orientation, in: scroll)
                XCTAssertTrue(orientation.label.contains("Watch app"))
                XCTAssertTrue(orientation.label.contains("\(arm) Wrist"))
                XCTAssertTrue(orientation.label.contains("Digital Crown"))
                let fit = app.staticTexts["phoneWatchFitGuidance"]
                reveal(fit, in: scroll); XCTAssertTrue(fit.label.contains("snug"))
                reveal(prepare, in: scroll)
                XCTAssertTrue(prepare.isEnabled, "Both explicit answers complete only the local UI guidance.")
            }
        }
    }

    @MainActor func testReenteringSetupRequiresBothAnswersAgainAndKeepsNewLeftHand() {
        let app = openSetup()
        let scroll = app.scrollViews["practiceSetupScreen"]
        choose("setupRacketArm", value: "Left", app: app, scroll: scroll)
        choose("setupCurrentWrist", value: "Right", app: app, scroll: scroll)
        XCTAssertFalse(app.buttons["setupSavedUsualHand"].exists)
        reopenSetup(app)
        assertUnanswered(app)
        choose("setupRacketArm", value: "Left", app: app, scroll: scroll)
        XCTAssertFalse(app.buttons["setupSavedUsualHand"].exists, "New left-handed setup must not inherit the old right-hand default.")
        XCTAssertFalse(app.staticTexts["watchPlacementGuidance"].exists)
    }

    @MainActor func testSavedMismatchesArePreservedUntilExplicitlyCorrected() {
        for arm in ["Left", "Right"] {
            let usual = arm == "Left" ? "Right" : "Left"
            // Exercise both durable preference and draft-only loading paths.
            let app = openSetup(savedArm: arm, savedDraft: arm == "Right")
            let scroll = app.scrollViews["practiceSetupScreen"]
            assertUnanswered(app)
            choose("setupRacketArm", value: arm, app: app, scroll: scroll)
            let saved = app.buttons["setupSavedUsualHand"]
            reveal(saved, in: scroll)
            assertNativeChoice(saved, title: "Saved usual playing hand", choice: usual)
            choose("setupCurrentWrist", value: usual, app: app, scroll: scroll)
            reopenSetup(app)
            assertUnanswered(app)
            choose("setupRacketArm", value: arm, app: app, scroll: scroll)
            reveal(saved, in: scroll)
            assertNativeChoice(saved, title: "Saved usual playing hand", choice: usual)
            choose("setupSavedUsualHand", value: arm, app: app, scroll: scroll)
            reopenSetup(app)
            choose("setupRacketArm", value: arm, app: app, scroll: scroll)
            XCTAssertFalse(saved.exists, "Only the explicit correction may resolve the saved mismatch.")
            app.terminate()
        }
    }

    @MainActor func testOwnerConsentIsExplicitAndOnlyManualForehandBackhandAreOffered() {
        let app = openSetup()
        let scroll = app.scrollViews["practiceSetupScreen"]
        checkLabeledChoices(app, in: scroll)
        let owner = app.switches["ownerAttestation"]
        let motion = app.switches["motionStudyConsent"]
        let heartRate = app.switches["optionalHeartRateConsent"]
        for toggle in [owner, motion, heartRate] {
            reveal(toggle, in: scroll)
            XCTAssertEqual(toggle.value as? String, "0")
        }
        let prepare = app.buttons["reviewAndPrepare"]
        reveal(prepare, in: scroll)
        XCTAssertFalse(prepare.isEnabled)
        XCTAssertFalse(app.buttons["Start recording"].exists)
        let notice = app.staticTexts["localWatchStartNotice"]
        reveal(notice, in: scroll)
        XCTAssertTrue(notice.label.contains("Start on Watch"))
        let forehand = app.buttons["setupForehand"]
        let backhand = app.buttons["setupBackhand"]
        reveal(forehand, in: scroll); XCTAssertTrue(forehand.isHittable)
        reveal(backhand, in: scroll); backhand.tap()
        XCTAssertFalse(app.buttons["Serve"].exists)
        XCTAssertFalse(app.buttons["Smash"].exists)
        XCTAssertFalse(app.buttons["Forehand volley"].exists)
        capture("SYNTHETIC-owner-setup-explicit-consent", app: app)
    }

    @MainActor func testOfflineReviewNeverClaimsWatchAcceptedOrStopped() {
        let app = openSetup()
        let scroll = app.scrollViews["practiceSetupScreen"]
        checkLabeledChoices(app, in: scroll)
        for identifier in ["ownerAttestation", "motionStudyConsent"] {
            let toggle = app.switches[identifier]
            let children = toggle.descendants(matching: .switch)
            let native = children.firstMatch
            let nativeExists = native.waitForExistence(timeout: 5)
            let nativeCount = children.count
            if !nativeExists || nativeCount != 1 { captureOfflineConsentState("\(identifier)-native-missing-or-ambiguous", app: app) }
            XCTAssertTrue(nativeExists, "Required consent must expose its native switch.")
            XCTAssertEqual(nativeCount, 1, "Required consent must contain exactly one native switch.")
            let enabled = native.isEnabled
            if !enabled { captureOfflineConsentState("\(identifier)-native-disabled", app: app) }
            XCTAssertTrue(enabled, "The native consent switch must be enabled before revealing it.")
            guard centerInteractiveControl(native, in: scroll, app: app) else {
                captureOfflineConsentState("\(identifier)-not-centered", app: app)
                XCTFail("The native consent switch must be centered before the diagnostic tap.")
                return
            }
            let before = toggle.value as? String
            let nativeBefore = native.value as? String
            let hittable = native.isHittable
            captureOfflineConsentState("\(identifier)-before", app: app)
            XCTAssertTrue(hittable, "The native consent switch must be hittable before tapping it.")
            XCTAssertEqual(before, "0", "Required consent must begin off.")
            XCTAssertEqual(nativeBefore, "0", "The native consent switch must begin off.")
            native.tap()
            let consentIsOn = NSPredicate { _, _ in
                (toggle.value as? String) == "1" && (native.value as? String) == "1"
            }
            let observation = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: consentIsOn, object: nil)], timeout: 5)
            let after = toggle.value as? String
            let nativeAfter = native.value as? String
            captureOfflineConsentState("\(identifier)-after", app: app)
            XCTAssertEqual(observation, .completed, "Both consent values must turn on after one native tap.")
            XCTAssertEqual(after, "1", "One intentional switch tap must enable the required consent.")
            XCTAssertEqual(nativeAfter, "1", "The native switch must remain on after the same tap.")
        }
        let prepare = app.buttons["reviewAndPrepare"]
        reveal(prepare, in: scroll)
        let ready = prepare.isEnabled
        if !ready { captureOfflineConsentState("prepare-disabled", app: app) }
        XCTAssertTrue(ready); prepare.tap()
        let status = app.staticTexts["setupStatus"]
        reveal(status, in: scroll)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.localizedCaseInsensitiveContains("Watch"))
        XCTAssertFalse(status.label.localizedCaseInsensitiveContains("accepted"))
        XCTAssertFalse(status.label.localizedCaseInsensitiveContains("Watch stopped"))
        XCTAssertFalse(app.buttons["endPractice"].isEnabled)
        capture("SYNTHETIC-owner-setup-offline", app: app)
    }

    @MainActor private func centerInteractiveControl(_ native: XCUIElement, in scroll: XCUIElement,
                                                    app: XCUIApplication) -> Bool {
        for _ in 0..<24 {
            let visible = usableViewport(in: scroll, app: app)
            guard visible.width > 0, visible.height > 0, native.exists else { return false }
            let frame = native.frame
            let middleBand = CGRect(x: visible.minX, y: visible.midY - visible.height * 0.1,
                                    width: visible.width, height: visible.height * 0.2)
            if native.isHittable, visible.contains(frame),
               middleBand.contains(CGPoint(x: frame.midX, y: frame.midY)) { return true }
            let limit = visible.height * 0.4
            let distance = max(-limit, min(limit, visible.midY - frame.midY))
            guard abs(distance) > 1 else { return false }
            let startY = visible.minY + visible.height * (distance < 0 ? 0.75 : 0.25)
            let start = scroll.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: visible.midX - scroll.frame.minX, dy: startY - scroll.frame.minY))
            let end = start.withOffset(CGVector(dx: 0, dy: distance))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        return false
    }

    @MainActor private func captureOfflineConsentState(_ reason: String, app: XCUIApplication) {
        let name = "SYNTHETIC-owner-setup-offline-\(reason)"
        capture(name, app: app)
        var details: [String] = []
        for identifier in ["ownerAttestation", "motionStudyConsent", "optionalHeartRateConsent"] {
            let toggle = app.switches[identifier]
            if toggle.exists {
                details.append("\(identifier) parent: frame=\(toggle.frame), value=\(String(describing: toggle.value)), enabled=\(toggle.isEnabled), hittable=\(toggle.isHittable)")
                let children = toggle.descendants(matching: .switch).allElementsBoundByIndex
                details.append("\(identifier) nativeCount=\(children.count)")
                for (index, native) in children.enumerated() {
                    let frame = native.frame
                    let center = CGPoint(x: frame.midX, y: frame.midY)
                    details.append("\(identifier) native[\(index)]: frame=\(frame), center=\(center), value=\(String(describing: native.value)), enabled=\(native.isEnabled), hittable=\(native.isHittable)")
                }
            } else { details.append("\(identifier): absent") }
        }
        let prepare = app.buttons["reviewAndPrepare"]
        if prepare.exists { details.append("reviewAndPrepare: frame=\(prepare.frame), enabled=\(prepare.isEnabled), hittable=\(prepare.isHittable)") }
        let hierarchy = XCTAttachment(string: details.joined(separator: "\n") + "\n\n" + app.debugDescription)
        hierarchy.name = name + "-consent-accessibility"; hierarchy.lifetime = .keepAlways; add(hierarchy)
    }

    @MainActor func testLargestTextPortraitSetupControlsAndReturnHome() throws {
        try checkLargeText(orientation: .portrait)
    }

    @MainActor func testLargestTextLandscapeSetupControlsAndReturnHome() throws {
        try checkLargeText(orientation: .landscapeLeft)
    }

    @MainActor private func checkLargeText(orientation: UIDeviceOrientation) throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = openSetup(largeText: true, orientation: orientation)
        try app.performAccessibilityAudit(for: [.contrast, .sufficientElementDescription, .hitRegion, .textClipped, .trait])
        let scroll = app.scrollViews["practiceSetupScreen"]
        checkLabeledChoices(app, in: scroll, orientation: orientation)
        for identifier in ["ownerAttestation", "motionStudyConsent", "optionalHeartRateConsent"] {
            let toggle = app.switches[identifier]
            reveal(toggle, in: scroll); XCTAssertTrue(toggle.isHittable)
        }
        for identifier in ["setupForehand", "setupBackhand", "reviewAndPrepare"] {
            let button = app.buttons[identifier]
            reveal(button, in: scroll); XCTAssertTrue(button.exists)
        }
        for identifier in ["watchPlacementGuidance", "phoneWatchOrientationGuidance", "phoneWatchFitGuidance"] {
            let text = app.staticTexts[identifier]
            reveal(text, in: scroll); assertHorizontallyContained(text, in: scroll, app: app)
        }
        capture("SYNTHETIC-owner-setup-largest-text-\(orientation.rawValue)", app: app, orientation: orientation)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.scrollViews["homeScreen"].waitForExistence(timeout: 5))
    }

    @MainActor private func openSetup(largeText: Bool = false, orientation: UIDeviceOrientation = .portrait,
                                    savedArm: String? = nil, savedDraft: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        // The DEBUG wizard fixture owns its temporary directory and disables real connectivity.
        app.launchArguments = ["--owner-setup-fixture=offline"]
        if let savedArm { app.launchArguments += ["--owner-setup-saved-mismatch=\(savedArm.lowercased())"] }
        if savedDraft { app.launchArguments += ["--owner-setup-saved-draft"] }
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        waitForOrientation(orientation, app: app)
        let home = app.scrollViews["homeScreen"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        let setup = app.buttons["practiceSetupLink"]
        reveal(setup, in: home); setup.tap()
        XCTAssertTrue(app.scrollViews["practiceSetupScreen"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor private func waitForOrientation(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        var previous: [CGRect] = []
        var stableObservations = 0
        let predicate = NSPredicate { _, _ in
            guard app.windows.firstMatch.exists else { return false }
            let frames = [app.frame, app.windows.firstMatch.frame]
            let matches = frames.allSatisfy { $0.width > 0 && $0.height > 0
                && (orientation.isLandscape ? $0.width > $0.height : $0.height > $0.width) }
            stableObservations = matches && frames == previous ? stableObservations + 1 : 0
            previous = frames
            return stableObservations >= 1
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5)
        if result != .completed { capture("SYNTHETIC-owner-setup-orientation-failure", app: app, orientation: orientation) }
        XCTAssertEqual(result, .completed, "App and window geometry did not settle in the requested orientation.")
    }

    @MainActor private func checkLabeledChoices(_ app: XCUIApplication, in scroll: XCUIElement,
                                               orientation: UIDeviceOrientation = .portrait) {
        for (identifier, title) in [("setupRacketArm", "Which hand holds your racket?"),
                                    ("setupCurrentWrist", "Which wrist is your Watch on now?")] {
            let label = app.staticTexts[identifier + "Label"]
            guard label.waitForExistence(timeout: 5) else {
                capture("SYNTHETIC-owner-setup-missing-\(identifier)-label", app: app, orientation: orientation)
                XCTFail("Missing visible choice label: \(title)"); return
            }
            reveal(label, in: scroll)
            XCTAssertEqual(label.label, title)
            assertHorizontallyContained(label, in: scroll, app: app)
            let menu = app.buttons[identifier]
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            reveal(menu, in: scroll)
            assertNativeChoice(menu, title: title, choice: "Choose")
            assertHorizontallyContained(menu, in: scroll, app: app)
            for choice in ["Left", "Right"] {
                menu.tap()
                let option = app.buttons[choice].firstMatch
                guard option.waitForExistence(timeout: 5) else {
                    let name = "SYNTHETIC-owner-setup-missing-\(identifier)-\(choice)"
                    capture(name, app: app, orientation: orientation)
                    let hierarchy = XCTAttachment(string: app.debugDescription)
                    hierarchy.name = name + "-accessibility"; hierarchy.lifetime = .keepAlways; add(hierarchy)
                    XCTFail("Native option \(choice) did not appear for \(title)."); return
                }
                option.tap()
                assertNativeChoice(menu, title: title, choice: choice)
            }
            capture("SYNTHETIC-owner-setup-\(identifier)-\(orientation.rawValue)", app: app, orientation: orientation)
        }
    }

    @MainActor private func choose(_ identifier: String, value: String, app: XCUIApplication, scroll: XCUIElement) {
        let menu = app.buttons[identifier]
        guard menu.waitForExistence(timeout: 5) else {
            captureChoiceFailure("\(identifier)-missing", app: app)
            XCTFail("Required choice menu \(identifier) is missing."); return
        }
        guard menu.isEnabled else {
            captureChoiceFailure("\(identifier)-disabled", app: app)
            XCTFail("Required choice menu \(identifier) must be enabled before selecting \(value)."); return
        }
        guard centerInteractiveControl(menu, in: scroll, app: app) else {
            captureChoiceFailure("\(identifier)-not-centered", app: app)
            XCTFail("Required choice menu \(identifier) must be fully visible and centered before selecting \(value)."); return
        }
        guard menu.isHittable else {
            captureChoiceFailure("\(identifier)-not-hittable", app: app)
            XCTFail("Required choice menu \(identifier) must be hittable before selecting \(value)."); return
        }
        menu.tap()
        let option = app.buttons[value].firstMatch
        guard option.waitForExistence(timeout: 5) else {
            captureChoiceFailure("\(identifier)-missing-option-\(value)", app: app)
            XCTFail("Native option \(value) did not appear for \(identifier) after one tap."); return
        }
        guard option.isEnabled, option.isHittable else {
            captureChoiceFailure("\(identifier)-unavailable-option-\(value)", app: app)
            XCTFail("Native option \(value) must be enabled and hittable for \(identifier)."); return
        }
        option.tap()
    }

    @MainActor private func captureChoiceFailure(_ reason: String, app: XCUIApplication) {
        let name = "SYNTHETIC-owner-setup-choice-\(reason)"
        capture(name, app: app)
        let status = app.staticTexts["setupStatus"], error = app.staticTexts["setupError"]
        let details = "status=\(status.exists ? status.label : "absent")\nerror=\(error.exists ? error.label : "absent")\n\n\(app.debugDescription)"
        let hierarchy = XCTAttachment(string: details)
        hierarchy.name = name + "-accessibility"; hierarchy.lifetime = .keepAlways; add(hierarchy)
    }

    @MainActor private func assertUnanswered(_ app: XCUIApplication) {
        let scroll = app.scrollViews["practiceSetupScreen"]
        for (identifier, title) in [("setupRacketArm", "Which hand holds your racket?"),
                                    ("setupCurrentWrist", "Which wrist is your Watch on now?")] {
            let menu = app.buttons[identifier]
            reveal(menu, in: scroll); assertNativeChoice(menu, title: title, choice: "Choose")
        }
        XCTAssertFalse(app.staticTexts["watchPlacementGuidance"].exists)
        let prepare = app.buttons["reviewAndPrepare"]
        reveal(prepare, in: scroll); XCTAssertFalse(prepare.isEnabled)
    }

    @MainActor private func reopenSetup(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        let home = app.scrollViews["homeScreen"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        let setup = app.buttons["practiceSetupLink"]
        reveal(setup, in: home); setup.tap()
        XCTAssertTrue(app.scrollViews["practiceSetupScreen"].waitForExistence(timeout: 5))
    }

    @MainActor private func assertNativeChoice(_ menu: XCUIElement, title: String, choice: String) {
        XCTAssertEqual(menu.label, "\(title), \(choice)")
        if let value = menu.value, (value as? String)?.isEmpty != true {
            XCTAssertEqual(value as? String, choice)
        }
    }

    @MainActor private func assertHorizontallyContained(_ element: XCUIElement, in scroll: XCUIElement,
                                                       app: XCUIApplication) {
        let viewport = app.frame.intersection(scroll.frame), frame = element.frame
        XCTAssertTrue(element.isHittable)
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 1)
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 1)
    }

    @MainActor private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
        let app = XCUIApplication()
        for _ in 0..<24 {
            let visible = usableViewport(in: scroll, app: app)
            guard visible.width > 0, visible.height > 0 else { XCTFail("No unobscured scroll viewport."); return }
            let frame = element.exists ? element.frame : nil
            let oversizedText = frame.map { $0.height > visible.height && element.elementType == .staticText } ?? false
            if let frame, element.isHittable {
                // Long instructions can span several landscape viewports. A readable part
                // must cross the viewport's center; interactive controls must fit completely.
                let contained = oversizedText
                    ? frame.minX >= visible.minX && frame.maxX <= visible.maxX
                        && frame.intersection(visible).contains(CGPoint(x: frame.midX, y: visible.midY))
                    : visible.contains(frame)
                if contained { return }
            }
            let limit = visible.height * 0.55
            let distance = frame.map { frame in
                let targetY = oversizedText
                    ? max(frame.minY + visible.height / 2, min(visible.midY, frame.maxY - visible.height / 2))
                    : frame.midY
                return max(-limit, min(limit, visible.midY - targetY))
            } ?? -limit
            let startY = visible.minY + visible.height * (distance < 0 ? 0.8 : 0.2)
            let start = scroll.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: visible.midX - scroll.frame.minX, dy: startY - scroll.frame.minY))
            let end = start.withOffset(CGVector(dx: 0, dy: distance))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTFail("Control is not reachable: \(element)")
    }

    @MainActor private func usableViewport(in scroll: XCUIElement, app: XCUIApplication) -> CGRect {
        let bounds = app.frame.intersection(scroll.frame)
        let bars = app.navigationBars.allElementsBoundByIndex.map(\.frame)
            .filter { !$0.isEmpty && $0.intersects(bounds) }
        let top = max(bounds.minY, bars.map(\.maxY).max() ?? bounds.minY) + 8
        return CGRect(x: bounds.minX + 4, y: top, width: max(0, bounds.width - 8),
                      height: max(0, bounds.maxY - 24 - top))
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication, orientation: UIDeviceOrientation = .portrait) {
        let screen = XCUIScreen.main.screenshot(), application = app.screenshot()
        let scroll = app.scrollViews["practiceSetupScreen"]
        var geometry = ["requestedOrientation=\(orientation.rawValue)", "deviceOrientation=\(XCUIDevice.shared.orientation.rawValue)",
                        "app=\(app.frame)", "scroll=\(scroll.exists ? String(describing: scroll.frame) : "absent")"]
        for (index, window) in app.windows.allElementsBoundByIndex.enumerated() { geometry.append("window[\(index)]=\(window.frame)") }
        for (index, bar) in app.navigationBars.allElementsBoundByIndex.enumerated() { geometry.append("navigationBar[\(index)]=\(bar.frame)") }
        if scroll.exists { geometry.append("usableViewport=\(usableViewport(in: scroll, app: app))") }
        for identifier in ["setupRacketArmLabel", "setupCurrentWristLabel", "setupRacketArm", "setupCurrentWrist",
                           "setupSavedUsualHand", "watchPlacementGuidance", "phoneWatchOrientationGuidance", "phoneWatchFitGuidance",
                           "setupForehand", "setupBackhand", "reviewAndPrepare", "setupStatus"] {
            let element = app.descendants(matching: .any)[identifier].firstMatch
            if element.exists {
                geometry.append("\(identifier): frame=\(element.frame), label=\(element.label), value=\(String(describing: element.value))")
            } else { geometry.append("\(identifier): absent") }
        }
        for (kind, screenshot) in [("screen", screen), ("app", application)] {
            let pixels = screenshot.image.cgImage
            geometry.append("\(kind)Screenshot: size=\(screenshot.image.size), pixels=\(pixels?.width ?? 0)x\(pixels?.height ?? 0), imageOrientation=\(screenshot.image.imageOrientation.rawValue)")
            let image = XCTAttachment(screenshot: screenshot)
            image.name = name + "-" + kind; image.lifetime = .keepAlways; add(image)
        }
        let frames = XCTAttachment(string: geometry.joined(separator: "\n"))
        frames.name = name + "-geometry"; frames.lifetime = .keepAlways; add(frames)
    }
}
