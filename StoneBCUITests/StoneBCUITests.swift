import XCTest

final class RideRecordingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        executionTimeAllowance = 1_200
    }

    func testRecordTabLaunchesInUITestMode() {
        let app = launchApp(resetSandbox: true)

        XCTAssertTrue(app.buttons["stonebc.record.start"].waitForExistence(timeout: 20))
        attachScreenshot(named: "record-tab", app: app)
    }

    func testShortSimulatedRideRecordingFlow() throws {
        let app = launchApp(resetSandbox: false, autoStartRide: true)

        try startRide(in: app)
        wait(seconds: 20)
        attachScreenshot(named: "short-ride-recording", app: app)
        try stopRideAndDiscard(in: app)
    }

    func testFifteenMinuteSimulatedRideRecording() throws {
        let app = launchApp(resetSandbox: false, autoStartRide: true)

        attachScreenshot(named: "long-ride-before-start", app: app)
        try startRide(in: app)
        wait(seconds: 60)
        attachScreenshot(named: "long-ride-during-recording", app: app)
        wait(seconds: 840)
        attachScreenshot(named: "long-ride-before-stop", app: app)
        try stopRideAndDiscard(in: app)
        attachScreenshot(named: "long-ride-after-completion", app: app)
    }

    private func launchApp(resetSandbox: Bool, autoStartRide: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-stonebc-ui-testing",
            "-stonebc-ui-skip-onboarding",
            "-stonebc-ui-start-record",
            "-stonebc-ui-disable-animations"
        ]
        if resetSandbox {
            app.launchArguments.append("-stonebc-ui-reset")
        }
        if autoStartRide {
            app.launchArguments.append("-stonebc-ui-auto-start-ride")
        }
        app.terminate()
        app.launch()
        if autoStartRide {
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            app.terminate()
            app.launch()
        }
        return app
    }

    private func startRide(in app: XCUIApplication) throws {
        XCTAssertTrue(app.buttons["stonebc.record.start"].waitForExistence(timeout: 20))
        app.buttons["stonebc.record.start"].tap()

        let preflightStart = app.buttons["stonebc.record.preflight.start"]
        if waitForHittable(preflightStart, timeout: 5) {
            preflightStart.tap()
        }

        let stopButton = waitForButton(
            identifiers: ["stonebc.record.stop", "stonebc.record.header.stop"],
            in: app,
            timeout: 60
        )
        XCTAssertNotNil(stopButton, "Ride controls did not appear after preflight start.")
    }

    private func stopRideAndDiscard(in app: XCUIApplication) throws {
        guard let stopButton = waitForButton(
            identifiers: ["stonebc.record.stop", "stonebc.record.header.stop"],
            in: app,
            timeout: 30
        ) else {
            XCTFail("Ride stop control did not appear.")
            return
        }
        stopButton.tap()

        let stopAndSave = app.buttons["stonebc.record.stopAndSave"].firstMatch.exists
            ? app.buttons["stonebc.record.stopAndSave"].firstMatch
            : app.buttons["Stop & Save"].firstMatch
        XCTAssertTrue(stopAndSave.waitForExistence(timeout: 10))
        stopAndSave.tap()

        let discardButton = app.buttons["stonebc.record.save.discard"].firstMatch.exists
            ? app.buttons["stonebc.record.save.discard"].firstMatch
            : app.buttons["Discard"].firstMatch
        XCTAssertTrue(discardButton.waitForExistence(timeout: 30))
        attachScreenshot(named: "ride-review-ready", app: app)
        discardButton.tap()

        XCTAssertTrue(app.buttons["stonebc.record.start"].waitForExistence(timeout: 20))
    }

    private func waitForButton(
        identifiers: [String],
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for identifier in identifiers {
                let button = app.buttons[identifier].firstMatch
                if button.exists, button.isHittable, button.isEnabled {
                    return button
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return nil
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true && hittable == true && enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func wait(seconds: TimeInterval) {
        var remaining = seconds
        while remaining > 0 {
            let chunk = min(remaining, 60)
            let expectation = XCTestExpectation(description: "Wait \(chunk) seconds")
            let result = XCTWaiter().wait(for: [expectation], timeout: chunk)
            XCTAssertEqual(result, .timedOut)
            remaining -= chunk
        }
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
