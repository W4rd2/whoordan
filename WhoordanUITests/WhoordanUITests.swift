import XCTest

final class WhoordanUITests: XCTestCase {
    func testLaunchShowsAuthOrRestoreGate() {
        let app = configuredApp()
        app.launch()
        let deadline = Date().addingTimeInterval(15)
        let knownRootLabels = [
            "Whoordan",
            "Whoordan W mark",
            "Email",
            "Password",
            "Reset Password",
            "Refresh Status",
            "Sign Out",
            "Today",
            "Restoring session"
        ]

        while Date() < deadline {
            if app.progressIndicators.firstMatch.exists {
                return
            }
            if knownRootLabels.contains(where: { label in
                app.staticTexts[label].exists
                    || app.buttons[label].exists
                    || app.images[label].exists
                    || app.textFields[label].exists
                    || app.secureTextFields[label].exists
            }) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTFail("Expected Whoordan to reach auth, restore, approval locked, or approved root state.")
    }

    func testApprovedSessionShowsTodayRoot() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Today"].waitForExistence(timeout: 20)
                || app.tabBars.buttons["Today"].waitForExistence(timeout: 20),
            "Expected the signed-in approved session to reach the Today root. This requires a preserved approved account session on the device."
        )
    }

    func testApprovedTabsShowProtectedScreens() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        ["Recovery", "Sleep", "Activity", "More"].forEach { tab in
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(
                app.navigationBars[tab].waitForExistence(timeout: 8) || app.staticTexts[tab].waitForExistence(timeout: 8),
                "Expected \(tab) to be reachable for an approved account."
            )
        }
        XCTAssertTrue(app.buttons["Device"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Vibration"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Journal"].waitForExistence(timeout: 8))
    }

    func testApprovedSleepShowsRestoredSleepData() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        app.tabBars.buttons["Sleep"].tap()
        XCTAssertTrue(
            app.staticTexts["Sleep recorded"].waitForExistence(timeout: 30)
                || waitForAnyLabelContaining(["restored", "8h"], in: app, timeout: 30),
            "Expected restored cloud sleep to be visible. Visible state: \(visibleDiagnosticText(in: app))"
        )
        XCTAssertFalse(app.staticTexts["No overnight sleep yet"].exists)
    }

    func testApprovedCallVibrationToggleCanBeEnabled() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Vibration", in: app)
        enableToggle("Vibrate wearable for iPhone calls", identifier: "call-vibration-toggle", in: app)
        let toggle = app.switches["call-vibration-toggle"]
        XCTAssertEqual(toggle.value as? String, "1")
        RunLoop.current.run(until: Date().addingTimeInterval(3))
    }

    func testApprovedCallVibrationTogglePersistsAfterRelaunch() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Vibration", in: app)
        enableToggle("Vibrate wearable for iPhone calls", identifier: "call-vibration-toggle", in: app)
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        app.terminate()

        app.launch()
        XCTAssertTrue(waitForToday(in: app))
        openSettings(in: app)
        openSettingsTool("Vibration", in: app)

        let identifiedToggle = app.switches["call-vibration-toggle"]
        let labelledToggle = app.switches["Vibrate wearable for iPhone calls"]
        let toggle = identifiedToggle.waitForExistence(timeout: 10) ? identifiedToggle : labelledToggle
        XCTAssertEqual(toggle.value as? String, "1")
    }

    func testApprovedHealthKitExportStatusIsAutomaticAndNotButtonDriven() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launchEnvironment["WHOORDAN_RAW_BLE_CAPTURE"] = "1"
        app.launchEnvironment["WHOORDAN_RAW_BLE_CAPTURE_MAX"] = "25"
        app.launchArguments.append("--whoordan-raw-ble-capture")
        handleSystemPrompts(for: app)
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Settings", in: app)
        XCTAssertFalse(app.buttons["Request Export Permission"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Enable Apple Health export"].waitForExistence(timeout: 2))
        for _ in 0..<4 {
            app.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.75))
        }

        let statuses = [
            "Status: requested",
            "Status: authorized",
            "Status: partial",
            "Status: failed",
            "Status: unavailable"
        ]
        XCTAssertTrue(
            statuses.contains(where: { app.staticTexts[$0].waitForExistence(timeout: 30) }),
            "Expected HealthKit request to complete with a visible non-private status."
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Apple Health export")).firstMatch.waitForExistence(timeout: 30)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Wrote supported user-created")).firstMatch.waitForExistence(timeout: 30),
            "Expected Apple Health export-only status without exposing private values. Visible state: \(visibleDiagnosticText(in: app))"
        )
    }

    func testApprovedDeviceScanShowsBluetoothState() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        handleSystemPrompts(for: app)
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Device", in: app)
        XCTAssertTrue(app.buttons["Scan or reconnect"].waitForExistence(timeout: 8))
        app.buttons["Scan or reconnect"].tap()
        app.tap()

        let states = [
            "Scanning",
            "Connecting",
            "Live",
            "Syncing",
            "Offline",
            "Wearable connected",
            "Syncing wearable history",
            "Looking for your wearable",
            "Connect your wearable"
        ]
        XCTAssertTrue(
            states.contains(where: { app.staticTexts[$0].waitForExistence(timeout: 30) }),
            "Expected BLE scan to reach a visible connection state without raw payload logging."
        )
    }

    func testApprovedWearableAutoConnectReachesProtocolState() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        handleSystemPrompts(for: app)
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Device", in: app)

        let connectedProtocolStates = [
            "Wearable connected",
            "Syncing wearable history",
            "Connecting",
            "Live"
        ]
        XCTAssertTrue(
            waitForAnyStaticText(connectedProtocolStates, in: app, timeout: 60),
            "Expected auto-connect to reach service discovery, subscription, init, historical sync, or realtime. Scanning alone is not treated as a wearable connection."
        )
    }

    func testConnectsToPreferredOwnedWearable() throws {
        try requireApprovedPhysicalSession()
        let wearableName = preferredWearableName

        let app = configuredApp()
        handleSystemPrompts(for: app)
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Device", in: app)

        let connectedProtocolStates = [
            "Wearable connected",
            "Syncing wearable history",
            "Connecting",
            "Live"
        ]
        if !waitForAnyStaticText(connectedProtocolStates, in: app, timeout: 20) {
            let connectButton = app.buttons.matching(NSPredicate(format: "label =[c] %@", "Connect \(wearableName)")).firstMatch
            XCTAssertTrue(
                connectButton.waitForExistence(timeout: 45),
                "Expected preferred owned wearable to be discovered before attempting connection."
            )
            connectButton.tap()
        }

        guard waitForAnyStaticText(connectedProtocolStates, in: app, timeout: 60) else {
            openSettings(in: app)
            openSettingsTool("Developer Tools", in: app)
            XCTFail("Expected \(wearableName) to reach service discovery, subscription, init, historical sync, or realtime. Menu visibility alone is not connection success. Visible state: \(visibleDiagnosticText(in: app))")
            return
        }

        XCTAssertTrue(
            app.staticTexts["Seen"].waitForExistence(timeout: 60)
                || app.staticTexts["Decode: valid frame"].waitForExistence(timeout: 60),
            "Expected \(wearableName) to produce at least one accepted packet or valid decoded frame. Connection alone is not data validation. Visible state: \(visibleDiagnosticText(in: app))"
        )

        let parsedPayloadEvidence = [
            "R10 realtime IMU/HR",
            "R21 optical PPG",
            "GATT 2A37",
            "GATT 2A19",
            "standard heart rate parsed",
            "standard battery parsed",
            "Device visible"
        ]
        XCTAssertTrue(
            waitForAnyStaticText(parsedPayloadEvidence, in: app, timeout: 90),
            "Expected at least one recognized wearable metric or standard Bluetooth attribute to be processed into app state. Raw packet receipt alone is not treated as metric processing. Visible state: \(visibleDiagnosticText(in: app))"
        )
    }

    func testApprovedVibrationPreviewReportsHonestState() throws {
        try requireApprovedPhysicalSession()
        let app = configuredApp()
        app.launch()
        XCTAssertTrue(waitForToday(in: app))

        openSettings(in: app)
        openSettingsTool("Vibration", in: app)
        XCTAssertTrue(app.buttons["Preview standard wearable vibration"].waitForExistence(timeout: 8))
        app.buttons["Preview standard wearable vibration"].tap()

        let statuses = [
            "Wearable disconnected",
            "Unsupported",
            "Started",
            "Failed",
            "Terminated",
            "Unsafe pattern",
            "Approval required",
            "Sending"
        ]
        XCTAssertTrue(
            statuses.contains(where: { app.staticTexts[$0].waitForExistence(timeout: 12) }),
            "Expected vibration preview to report an honest state."
        )
    }

    private func configuredApp() -> XCUIApplication {
        let app = XCUIApplication()
        let environment = ProcessInfo.processInfo.environment
        [
            "SUPABASE_PROJECT_ID",
            "SUPABASE_PUBLISHABLE_KEY",
            "WHOORDAN_SUPABASE_PUBLISHABLE_KEY",
            "WHOORDAN_SUPABASE_URL",
            "WHOORDAN_PREFERRED_WEARABLE_NAME",
            "WHOORDAN_RAW_BLE_CAPTURE",
            "WHOORDAN_RAW_BLE_CAPTURE_MAX"
        ].forEach { key in
            if let value = environment[key], !value.isEmpty {
                app.launchEnvironment[key] = value
            }
        }
        app.launchEnvironment["WHOORDAN_DISABLE_UPDATE_CHECKS"] = "1"
        app.launchEnvironment["WHOORDAN_PREFERRED_WEARABLE_NAME"] = preferredWearableName
        return app
    }

    private var preferredWearableName: String {
        let configured = ProcessInfo.processInfo.environment["WHOORDAN_PREFERRED_WEARABLE_NAME"]
        return configured?.isEmpty == false ? configured! : "WARDAN's wearable"
    }

    private func requireApprovedPhysicalSession() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Approved-account physical UI tests require an existing approved session on a real iPhone.")
        #endif
    }

    private func waitForToday(in app: XCUIApplication) -> Bool {
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if app.staticTexts["Today"].exists || app.tabBars.buttons["Today"].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return app.staticTexts["Today"].exists || app.tabBars.buttons["Today"].exists
    }

    private func waitForAnyStaticText(_ labels: [String], in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if labels.contains(where: { app.staticTexts[$0].exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func waitForAnyLabelContaining(_ fragments: [String], in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
            if labels.contains(where: { label in
                fragments.contains { fragment in
                    label.localizedCaseInsensitiveContains(fragment)
                }
            }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func openSettings(in app: XCUIApplication) {
        let more = app.tabBars.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        XCTAssertTrue(
            app.staticTexts["Tools and settings"].waitForExistence(timeout: 10)
                || app.buttons["Device"].waitForExistence(timeout: 10),
            "Expected More to be visible before selecting a protected tool."
        )
    }

    private func openSettingsTool(_ title: String, in app: XCUIApplication) {
        for _ in 0..<6 {
            let directButton = app.buttons[title]
            if directButton.exists && directButton.isHittable {
                directButton.tap()
                return
            }
            let label = app.staticTexts[title]
            if label.exists && label.isHittable {
                label.tap()
                return
            }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        XCTFail("Expected \(title) to be visible in Settings.")
    }

    private func enableToggle(_ title: String, in app: XCUIApplication) {
        let toggle = app.switches[title]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Expected \(title) toggle to be visible.")
        if (toggle.value as? String) != "1" {
            toggle.tap()
        }
    }

    private func enableToggle(_ title: String, identifier: String, in app: XCUIApplication) {
        let identifiedToggle = app.switches[identifier]
        let labelledToggle = app.switches[title]
        let toggle = identifiedToggle.waitForExistence(timeout: 10) ? identifiedToggle : labelledToggle
        XCTAssertTrue(toggle.exists, "Expected \(title) toggle to be visible.")
        if (toggle.value as? String) != "1" {
            toggle.tap()
        }
    }

    private func expandAdvancedDiagnosticsIfAvailable(in app: XCUIApplication) {
        let diagnostics = app.buttons["Developer Tools"]
        if diagnostics.exists {
            diagnostics.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }

    private func visibleDiagnosticText(in app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
            .prefix(30)
            .joined(separator: " | ")
    }

    private func handleSystemPrompts(for app: XCUIApplication) {
        addUIInterruptionMonitor(withDescription: "System permission prompts") { alert in
            let allowedButtons = [
                "Allow",
                "Allow All",
                "Turn On All",
                "Share All",
                "Continue",
                "Done",
                "OK"
            ]
            for buttonTitle in allowedButtons where alert.buttons[buttonTitle].exists {
                alert.buttons[buttonTitle].tap()
                return true
            }
            return false
        }
    }
}
