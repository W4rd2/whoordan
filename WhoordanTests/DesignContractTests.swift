import XCTest
@testable import Whoordan

final class DesignContractTests: XCTestCase {
    func testSourceTreeKeepsIndustryStandardAppBoundaries() throws {
        for directory in [
            "Whoordan/App",
            "Whoordan/Core",
            "Whoordan/DesignSystem",
            "Whoordan/Features",
            "Whoordan/Resources",
            "WhoordanTests"
        ] {
            var isDirectory: ObjCBool = false
            let path = projectRoot().appendingPathComponent(directory).path
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue,
                "\(directory) should exist as a clear top-level boundary."
            )
        }
    }

    func testFeatureViewsDoNotOwnPlatformNetworkOrPersistenceIntegrations() throws {
        let forbiddenTerms = [
            "import HealthKit",
            "import CoreBluetooth",
            "import Security",
            "URLSession.shared",
            "HKHealthStore",
            "CBCentralManager",
            "SecItem",
            "SupabaseAuthService(",
            "SupabaseHealthSyncService(",
            "FileProtectedLocalStore(",
            "KeychainStore("
        ]
        let featureFiles = try swiftSourceFiles(in: projectRoot().appendingPathComponent("Whoordan/Features"))

        for file in featureFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for term in forbiddenTerms {
                XCTAssertFalse(
                    source.contains(term),
                    "\(file.lastPathComponent) should receive platform, network, and persistence behavior through app/core abstractions instead of owning \(term)."
                )
            }
        }
    }

    func testSwiftLintConfigurationDocumentsCodingStandard() throws {
        let source = try String(
            contentsOf: projectRoot().appendingPathComponent(".swiftlint.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("included:"))
        XCTAssertTrue(source.contains("line_length:"))
        XCTAssertTrue(source.contains("type_body_length:"))
        XCTAssertTrue(source.contains("function_body_length:"))
        XCTAssertTrue(source.contains("force_cast"))
        XCTAssertTrue(source.contains("force_try"))
    }

    func testSignalScreensDoNotUseRepeatedGenericTitlePattern() throws {
        for file in ["RecoveryView.swift", "SleepView.swift", "HeartView.swift"] {
            let source = try readFeatureSource(file)
            XCTAssertFalse(source.contains("SignalScreen("), "\(file) should not use the old duplicated SignalScreen title layout.")
            XCTAssertFalse(source.contains(".navigationTitle("), "\(file) should rely on one visible screen header.")
        }
    }

    func testTodayMissingDataCTAsExist() throws {
        let source = try readFeatureSource("TodayView.swift")
        XCTAssertTrue(source.contains("Pair wearable"))
        XCTAssertTrue(source.contains("Build baseline"))
        XCTAssertTrue(source.contains("Steps"))
        XCTAssertFalse(source.contains("Enable Apple Health export"))
        XCTAssertFalse(source.contains("No source yet"))
        XCTAssertFalse(source.contains("No data"))
    }

    func testTodaySignalBoardSurfacesTrends() throws {
        let source = try readFeatureSource("TodayView.swift")
        XCTAssertTrue(source.contains("TrendsView()"))
        XCTAssertTrue(source.contains("title: \"Trends\""))
        XCTAssertTrue(source.contains("trendCardContext"))
    }

    func testTodayBodySignalsStayVisibleAboveDataQualityAudit() throws {
        let source = try readFeatureSource("TodayView.swift")

        XCTAssertTrue(source.contains("title: \"Body signals\""))
        XCTAssertTrue(source.contains("No beta estimates in this snapshot"))
        guard
            let bodySignalsRange = source.range(of: "if hasBodySignals { bodySignals }"),
            let dataQualityRange = source.range(of: "metricDashboard")
        else {
            XCTFail("Today should render body signals and the data quality dashboard.")
            return
        }
        XCTAssertLessThan(bodySignalsRange.lowerBound, dataQualityRange.lowerBound)
    }

    func testRecoveryContributorListExists() throws {
        let source = try readFeatureSource("RecoveryView.swift")
        XCTAssertTrue(source.contains("Contributors"))
        XCTAssertTrue(source.contains("Top positive contributors"))
        XCTAssertTrue(source.contains("Top negative contributors"))
        XCTAssertTrue(source.contains("HRV relative to baseline"))
        XCTAssertTrue(source.contains("RHR relative to baseline"))
        XCTAssertTrue(source.contains("Sleep sufficiency"))
        XCTAssertTrue(source.contains("Respiratory fit"))
        XCTAssertTrue(source.contains("skin-temperature deviation"))
        XCTAssertTrue(source.contains("Missing-data confidence"))
        XCTAssertTrue(source.contains("Source labels"))
        XCTAssertTrue(source.contains("Not medical advice"))
        XCTAssertTrue(source.contains("not equivalent to any proprietary recovery score"))
    }

    func testSleepSourceCTAExistsAndDoesNotFakeStages() throws {
        let source = try readFeatureSource("SleepView.swift")
        XCTAssertTrue(source.contains("Pair wearable"))
        XCTAssertTrue(source.contains("No fabricated efficiency or stages"))
    }

    func testMetricPagesGatePairWearableCTAOnConnectionState() throws {
        for file in [
            "TodayView.swift",
            "RecoveryView.swift",
            "SleepView.swift",
            "HeartView.swift",
            "SettingsView.swift"
        ] {
            let source = try readFeatureSource(file)
            guard source.contains("Pair wearable") else { continue }

            XCTAssertTrue(
                source.contains("shouldShowPairWearableCTA"),
                "\(file) must not render Pair wearable on metric pages when a wearable is already connected."
            )
        }
    }

    func testBodySignalsConfigureAndConnectCTAsExist() throws {
        let source = try readFeatureSource("SettingsView.swift")
        XCTAssertTrue(source.contains("BodySignalsView"))
        XCTAssertTrue(source.contains("Never computed from BPM alone"))
    }

    func testBodyProfileUsesBirthDateInsteadOfManualAgeInput() throws {
        let settings = try readFeatureSource("SettingsView.swift")
        XCTAssertTrue(settings.contains("Birth date, sex, height, weight"))
        XCTAssertTrue(settings.contains("DatePicker("))
        XCTAssertTrue(settings.contains("\"Birth date\""))
        XCTAssertTrue(settings.contains("Add birth date"))
        XCTAssertTrue(settings.contains("Age updates automatically"))
        XCTAssertFalse(settings.contains("TextField(\"Age in years\""))

        let models = try readCoreSource("Models/HealthModels.swift")
        XCTAssertTrue(models.contains("var birthDate: Date?"))
        XCTAssertTrue(models.contains("func resolvedAgeYears(on referenceDate: Date = Date()"))
        XCTAssertTrue(models.contains("Birth date cannot be in the future."))
    }

    func testSettingsExposeExplicitPermissionRequests() throws {
        let source = try readFeatureSource("SettingsView.swift")
        XCTAssertTrue(source.contains("Section(\"Permissions\")"))
        XCTAssertTrue(source.contains("Bluetooth and wearable"))
        XCTAssertTrue(
            source.contains("environment.requestBluetoothAccess()"),
            "The Settings permission row must invoke the explicit Bluetooth permission path, not only a scan/reconnect action."
        )
        XCTAssertTrue(source.contains("Apple Health"))
        XCTAssertTrue(source.contains("Notifications"))
        XCTAssertTrue(source.contains("Whoordan automatically requests Bluetooth, Apple Health export, and notifications on first approved launch"))
        XCTAssertTrue(source.contains("Prepare Local Data Export"))
        XCTAssertTrue(source.contains("Erase Local Data and Sign Out"))
        XCTAssertTrue(source.contains("Request Account Deletion"))
    }

    func testSettingsExposeThemePreferenceControl() throws {
        let app = try readAppSource("WhoordanApp.swift")
        XCTAssertTrue(app.contains("enum AppThemePreference"))
        XCTAssertTrue(app.contains("case system"))
        XCTAssertTrue(app.contains("case light"))
        XCTAssertTrue(app.contains("case dark"))
        XCTAssertTrue(app.contains("@AppStorage(AppThemePreference.storageKey)"))
        XCTAssertTrue(app.contains(".preferredColorScheme(resolvedThemePreference.preferredColorScheme)"))
        XCTAssertFalse(app.contains(".preferredColorScheme(.dark)"))

        let root = try readAppSource("AppRootView.swift")
        XCTAssertFalse(root.contains(".toolbarColorScheme(.dark, for: .tabBar)"))

        let settings = try readFeatureSource("SettingsView.swift")
        XCTAssertTrue(settings.contains("Section(\"Appearance\")"))
        XCTAssertTrue(settings.contains("Picker(\"Theme\""))
        XCTAssertTrue(settings.contains("AppThemePreference.allCases"))

        let theme = try readDesignSystemSource("WTheme.swift")
        XCTAssertTrue(theme.contains("whoordanAdaptive"))
        XCTAssertTrue(theme.contains("traitCollection.userInterfaceStyle == .dark"))
    }

    func testAppleHealthExportIsAutomaticNotUserClickDriven() throws {
        let featureFiles = try swiftSourceFiles(in: projectRoot().appendingPathComponent("Whoordan/Features"))
        let forbiddenManualExportTerms = [
            "requestHealthKit()",
            "Request Export Permission",
            "Enable Apple Health export",
            "title: \"Apple Health export\"",
            "Button(\"Apple Health\""
        ]

        for file in featureFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for term in forbiddenManualExportTerms {
                XCTAssertFalse(
                    source.contains(term),
                    "\(file.lastPathComponent) should not expose Apple Health export as a user-click driven action."
                )
            }
        }

        let appEnvironment = try readAppSource("AppEnvironment.swift")
        XCTAssertTrue(appEnvironment.contains("requestRemainingStartupPermissionsAfterCloudPrompt"))
        XCTAssertTrue(appEnvironment.contains("await requestHealthKit()"))
    }

    func testInfoPlistDeclaresUsedSystemPermissionReasons() throws {
        let plistURL = projectRoot().appendingPathComponent("Whoordan/Resources/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertNotNil(plist["NSBluetoothAlwaysUsageDescription"])
        XCTAssertNotNil(plist["NSBluetoothPeripheralUsageDescription"])
        XCTAssertNotNil(plist["NSHealthShareUsageDescription"])
        XCTAssertNotNil(plist["NSHealthUpdateUsageDescription"])
        XCTAssertNil(plist["UIFileSharingEnabled"])
        XCTAssertNil(plist["LSSupportsOpeningDocumentsInPlace"])
        XCTAssertNil(plist["NSAccessorySetupBluetoothServices"])
        XCTAssertNil(plist["NSAccessorySetupKitSupports"])
        XCTAssertEqual(plist["BGTaskSchedulerPermittedIdentifiers"] as? [String], ["com.w4rd2.whoordan.refresh"])
        XCTAssertTrue((plist["UIBackgroundModes"] as? [String] ?? []).contains("bluetooth-central"))
    }

    func testNotificationVibrationFeatureIsRemovedFromUserFacingRuntime() throws {
        let vibrationView = try readFeatureSource("VibrationView.swift")
        XCTAssertFalse(vibrationView.contains("Notification vibration"))
        XCTAssertFalse(vibrationView.contains("Accessory notification forwarding"))
        XCTAssertFalse(vibrationView.contains("Pair and request forwarding"))
        XCTAssertFalse(vibrationView.contains("notifications received"))

        let deviceView = try readFeatureSource("DeviceView.swift")
        XCTAssertFalse(deviceView.contains("Notification mode:"))
        XCTAssertFalse(deviceView.contains("Notification route:"))
        XCTAssertFalse(deviceView.contains("All-app notification"))

        let appEnvironment = try readAppSource("AppEnvironment.swift")
        XCTAssertFalse(appEnvironment.contains("routeNotificationVibration"))
        XCTAssertFalse(appEnvironment.contains("routeAccessoryForwardedNotification"))
        XCTAssertFalse(appEnvironment.contains("requestAccessoryNotificationForwarding"))
        XCTAssertFalse(appEnvironment.contains("accessoryNotificationForwardingService.start()"))

        let vibrationModels = try readCoreSource("Haptics/VibrationModels.swift")
        XCTAssertFalse(vibrationModels.contains("NotificationVibrationSettings"))
        XCTAssertFalse(vibrationModels.contains("NotificationVibrationMode"))
        XCTAssertFalse(vibrationModels.contains("AppVibrationRule"))
        XCTAssertFalse(vibrationModels.contains("dismissNotificationWhereSupported"))
    }

    func testNotificationVibrationExtensionStackIsRemovedFromBuild() throws {
        let project = try String(
            contentsOf: projectRoot().appendingPathComponent("Whoordan.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        for forbiddenTerm in [
            "WhoordanAccessoryNotificationsProvider",
            "WhoordanAccessoryTransport",
            "AccessoryNotifications",
            "NotificationsForwarding",
            "accessory-data-provider",
            "accessory-transport",
            "com.apple.developer.accessory"
        ] {
            XCTAssertFalse(project.contains(forbiddenTerm), "Xcode project should not contain \(forbiddenTerm).")
        }

        for removedDirectory in [
            "WhoordanAccessoryNotificationsProvider",
            "WhoordanAccessoryTransport",
            "WhoordanAccessoryTransportSecurity"
        ] {
            let path = projectRoot().appendingPathComponent(removedDirectory).path
            XCTAssertFalse(FileManager.default.fileExists(atPath: path), "\(removedDirectory) should not remain in the source tree.")
        }
    }

    func testBluetoothPermissionRequestKeepsForegroundProbeWithBackgroundRestoration() throws {
        let source = try readCoreSource("BLE/WearableBLEService.swift")

        XCTAssertTrue(source.contains("CBCentralManager(delegate: self, queue: .main, options: ["))
        XCTAssertTrue(source.contains("CBCentralManagerOptionShowPowerAlertKey: true"))
        XCTAssertTrue(
            source.contains("CBCentralManagerOptionRestoreIdentifierKey"),
            "The operational BLE manager needs a restoration identifier so iOS can relaunch Whoordan for restored central events."
        )
        XCTAssertTrue(
            source.contains("willRestoreState"),
            "CoreBluetooth restoration must restore delegates and subscriptions instead of dropping background BLE events."
        )
        XCTAssertTrue(
            source.contains("retrievePeripherals(withIdentifiers: identifiers)"),
            "Background reconnect should first use the saved peripheral identifier before weaker background scans."
        )
        XCTAssertTrue(
            source.contains("scanIfReady(serviceFiltered: true)"),
            "Auto-connect fallback should use a service-filtered scan so iOS background discovery is constrained."
        )
        XCTAssertTrue(
            source.contains("runBluetoothPermissionProbeScanIfReady"),
            "First launch must perform an actual CoreBluetooth access operation; creating the manager alone may not create the iOS Bluetooth permission row."
        )
        XCTAssertTrue(
            source.contains("scanForPeripherals(withServices: [permissionProbeServiceUUID]"),
            "The Bluetooth permission probe should use a filtered scan so iOS prompts without discovering arbitrary devices."
        )
        XCTAssertTrue(
            source.contains("forceWhenNotDetermined: true"),
            "The Bluetooth permission probe should still exercise protected CoreBluetooth access when iOS reports notDetermined authorization with a stale poweredOff manager state."
        )
        XCTAssertTrue(
            source.contains("guard !permissionProbeScanActive else { return }"),
            "Permission probing must not persist discovered devices or expose BLE candidates before approval."
        )
        XCTAssertTrue(
            source.contains("CoreBluetooth state: poweredOff"),
            "A powered-off CoreBluetooth state must be reported as system Bluetooth unavailable, not as app permission denial."
        )
        XCTAssertFalse(
            source.contains("A wearable can be paired to the phone but still not available to this app until Bluetooth is on and Whoordan has permission."),
            "The powered-off copy should not conflate system Bluetooth availability with Whoordan authorization."
        )
    }

    func testUserVisibleBatteryUsesProtocolHelloBatteryCandidate() throws {
        let source = try readCoreSource("BLE/WearableBLEService.swift")

        XCTAssertTrue(
            source.contains("characteristic.uuid == standardBatteryLevelUUID"),
            "The standard GATT Battery Level characteristic should still be parsed as diagnostic evidence."
        )
        XCTAssertTrue(
            source.contains("source == .proprietaryHelloCandidate"),
            "The displayed wearable battery should be promoted only from the validated protocol hello candidate."
        )
        XCTAssertTrue(source.contains("$0.applyDisplayedBatteryPercent(battery, source: .standardGattBatteryLevel)"))
        XCTAssertTrue(source.contains("source: .proprietaryHelloCandidate"))
        XCTAssertFalse(
            source.contains("state.batteryPercent = Int(batteryPercent.rounded())"),
            "The protocol hello response must use the guarded battery display policy instead of assigning directly."
        )
        XCTAssertFalse(
            source.contains("state.batteryPercent = Int(value.rounded())"),
            "The proprietary event battery candidate is noisy and must not override the displayed battery percentage."
        )
        XCTAssertTrue(
            source.contains("state.isCharging = isCharging"),
            "The hello response can still update charging status independently of the displayed battery value."
        )
        XCTAssertTrue(
            source.contains("state.isOnWrist = isOnWrist"),
            "The hello response can still update wrist status independently of the displayed battery value."
        )
    }

    func testIPhoneInstallerDoesNotShipAccessorySetupDeclarations() throws {
        let source = try String(
            contentsOf: projectRoot().appendingPathComponent("scripts/build-install-ios-supabase.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("WhoordanAppOnlyInfo.plist"))
        XCTAssertTrue(source.contains("Delete :NSAccessorySetupBluetoothServices"))
        XCTAssertTrue(source.contains("Delete :NSAccessorySetupKitSupports"))
        XCTAssertTrue(source.contains("INFOPLIST_FILE = WhoordanAppOnlyInfo.plist;"))
        XCTAssertFalse(source.contains("INSTALL_WITH_ACCESSORY_EXTENSIONS"))
        XCTAssertFalse(source.contains("Including accessory ExtensionKit targets"))
    }

    func testIPhoneInstallerParsesOnlyAllowlistedEnvironmentKeys() throws {
        let source = try String(
            contentsOf: projectRoot().appendingPathComponent("scripts/build-install-ios-supabase.sh"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("source \"$ENV_FILE\""))
        XCTAssertFalse(source.contains("set -a"))
        XCTAssertTrue(source.contains("read_env_value()"))
        XCTAssertTrue(source.contains("forbidden_env_key_pattern"))
        XCTAssertTrue(source.contains("base64.urlsafe_b64decode"))
        XCTAssertTrue(source.contains("payload.get(\"role\") == \"service_role\""))
        XCTAssertTrue(source.contains("SUPABASE_PROJECT_ID"))
        XCTAssertTrue(source.contains("WHOORDAN_SUPABASE_PUBLISHABLE_KEY"))
        XCTAssertTrue(source.contains("SUPABASE_PUBLISHABLE_KEY"))
        XCTAssertTrue(source.contains("SUPABASE_ANON_KEY"))
    }

    func testNoHeavyDashOrUnavailableEmptyCopyOnPrimaryScreens() throws {
        for file in ["TodayView.swift", "RecoveryView.swift", "SleepView.swift", "HeartView.swift"] {
            let source = try readFeatureSource(file)
            XCTAssertFalse(source.contains("?? \"--\""), "\(file) should use intentional empty-state language.")
            XCTAssertFalse(source.contains("\"Unavailable\""), "\(file) should avoid heavy unavailable copy.")
        }
    }

    func testApprovalGateStillBlocksProtectedServicesBeforeApproval() {
        let guarder = PrivacyAccessGuard()
        XCTAssertFalse(guarder.canStartProtectedService(approval: nil))
        XCTAssertFalse(guarder.canStartProtectedService(approval: .pending()))
        XCTAssertTrue(guarder.canStartProtectedService(approval: .approved()))
    }

    func testMoreExposesProductSurfacesAndDeveloperTools() throws {
        let source = try readFeatureSource("SettingsView.swift")
        XCTAssertTrue(source.contains("MoreView"))
        XCTAssertTrue(source.contains("MovementView"))
        XCTAssertTrue(source.contains("WorkoutsView"))
        XCTAssertTrue(source.contains("StrengthView"))
        XCTAssertTrue(source.contains("BodySignalsView"))
        XCTAssertTrue(source.contains("TrendsView"))
        XCTAssertTrue(source.contains("DeveloperToolsView"))
        XCTAssertTrue(source.contains("reliable step/activity record"))
    }

    func testMetricFirstProductSurfacesExposeReadinessAndDetailPages() throws {
        let today = try readFeatureSource("TodayView.swift")
        let settings = try readFeatureSource("SettingsView.swift")
        let device = try readFeatureSource("DeviceView.swift")
        let components = try readDesignSystemSource("WComponents.swift")

        XCTAssertTrue(today.contains("MetricDetailView"))
        XCTAssertTrue(today.contains("Data quality"))
        XCTAssertTrue(today.contains("Show now"))
        XCTAssertTrue(today.contains("Beta / estimated"))
        XCTAssertTrue(today.contains("Later / blocked"))
        XCTAssertTrue(settings.contains("HealthMonitorView"))
        XCTAssertTrue(settings.contains("StressView"))
        XCTAssertTrue(settings.contains("StrainDetailView"))
        XCTAssertTrue(device.contains("Toggle(\"Local-only capture\""))
        XCTAssertTrue(device.contains("Local-only capture"))
        XCTAssertTrue(device.contains("Files location: On My iPhone > Whoordan > whoordan-ble-debug"))
        XCTAssertTrue(device.contains("Manual export: open Files or Finder"))
        XCTAssertFalse(device.contains("Export BLE logs"))
        XCTAssertFalse(device.contains("Share zipped logs"))
        XCTAssertTrue(device.contains("batteryDetail"))
        XCTAssertTrue(device.contains("Charging"))
        XCTAssertTrue(device.contains("Background capture is best-effort"))
        XCTAssertTrue(device.contains("Frame Trends"))
        XCTAssertTrue(components.contains("WMetricCard"))
        XCTAssertFalse(components.contains("Source:"))
        XCTAssertFalse(components.contains("Confidence:"))
        XCTAssertFalse(components.contains("Last updated:"))
        XCTAssertTrue(today.contains("Tap a metric for source"))
    }

    func testMetricDetailsUseGuidedMissingDataStates() throws {
        let today = try readFeatureSource("TodayView.swift")
        let components = try readDesignSystemSource("WComponents.swift")

        XCTAssertTrue(today.contains("MetricMissingGuidance"))
        XCTAssertTrue(today.contains("No sleep was detected for this day."))
        XCTAssertTrue(today.contains("Trend appears after Whoordan has enough source data for this metric."))
        XCTAssertFalse(today.contains("Lazy loaded when this detail page opens"))
        XCTAssertTrue(components.contains("WMetricMissingHero"))
        XCTAssertTrue(components.contains("WMissingMetricGuidanceCard"))
        XCTAssertTrue(components.contains("Waiting for data"))
        XCTAssertFalse(components.contains("Text(metric.value ?? \"Not ready\")"))
    }

    func testTodayMetricQualityCardsUseReadablePhoneLayout() throws {
        let today = try readFeatureSource("TodayView.swift")
        let components = try readDesignSystemSource("WComponents.swift")

        XCTAssertTrue(today.contains("metricGridColumns"))
        XCTAssertTrue(today.contains("GridItem(.flexible(minimum: 260"))
        XCTAssertFalse(components.contains("metric.value ?? \"Unavailable\""))
        XCTAssertTrue(components.contains("metricDisplayValue"))
        XCTAssertTrue(components.contains("metricSecondaryLine"))
        XCTAssertTrue(components.contains("metricStatusText"))
    }

    func testDeviceScreenKeepsRawDiagnosticsInDeveloperTools() throws {
        let source = try readFeatureSource("DeviceView.swift")
        let normalDeviceSource = source.components(separatedBy: "struct DeveloperToolsView").first ?? source
        let developerSource = source.components(separatedBy: "struct DeveloperToolsView").dropFirst().joined(separator: "struct DeveloperToolsView")
        XCTAssertFalse(source.contains("First bytes:"))
        XCTAssertFalse(source.contains("Last bytes:"))
        XCTAssertFalse(source.contains("rawCapturePath"))
        XCTAssertFalse(normalDeviceSource.contains("Malformed frames"))
        XCTAssertFalse(normalDeviceSource.contains("Packet Diagnostics"))
        XCTAssertTrue(developerSource.contains("Stop and name"))
        XCTAssertTrue(developerSource.contains("TextField(\"Recording name\""))
        XCTAssertTrue(developerSource.contains("Payload bytes are intentionally hidden."))
        XCTAssertTrue(developerSource.contains("Packet Diagnostics"))
    }

    func testPrimaryTabStructureUsesProductIA() throws {
        let source = try readAppSource("AppRootView.swift")
        XCTAssertTrue(source.contains("Label(\"Today\""))
        XCTAssertTrue(source.contains("Label(\"Recovery\""))
        XCTAssertTrue(source.contains("Label(\"Sleep\""))
        XCTAssertTrue(source.contains("Label(\"Activity\""))
        XCTAssertTrue(source.contains("Label(\"More\""))
        XCTAssertFalse(source.contains("Label(\"Heart\""))
        XCTAssertFalse(source.contains("Label(\"Settings\""))
    }

    func testLaunchRestoreIsNotAttachedToRouteSwitchingTask() throws {
        let source = try readAppSource("AppRootView.swift")

        XCTAssertTrue(source.contains("@State private var didStartInitialRestore = false"))
        XCTAssertTrue(source.contains(".onAppear"))
        XCTAssertTrue(source.contains("Task { await environment.restore() }"))
        XCTAssertFalse(
            source.contains(".task {\n            await environment.restore()\n        }"),
            "Initial restore must not be attached to the route-switching content tree."
        )
    }

    private func readFeatureSource(_ filename: String) throws -> String {
        let root = projectRoot()
        let candidates = [
            root.appendingPathComponent("Whoordan/App/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Today/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Recovery/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Sleep/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Heart/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Settings/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Device/\(filename)"),
            root.appendingPathComponent("Whoordan/Features/Vibration/\(filename)")
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func readAppSource(_ filename: String) throws -> String {
        try String(contentsOf: projectRoot().appendingPathComponent("Whoordan/App/\(filename)"), encoding: .utf8)
    }

    private func readDesignSystemSource(_ filename: String) throws -> String {
        try String(contentsOf: projectRoot().appendingPathComponent("Whoordan/DesignSystem/\(filename)"), encoding: .utf8)
    }

    private func readCoreSource(_ path: String) throws -> String {
        try String(contentsOf: projectRoot().appendingPathComponent("Whoordan/Core/\(path)"), encoding: .utf8)
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func swiftSourceFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else {
                return nil
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}
