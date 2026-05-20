import XCTest
@testable import Whoordan

@MainActor
final class AppEnvironmentWearableStateTests: XCTestCase {
    func testMetricPagesHidePairWearableCTAWhenWearableIsConnected() {
        var realtime = WearableDeviceState()
        realtime.connection = .realtime

        var historicalSync = WearableDeviceState()
        historicalSync.connection = .historicalSync

        var connectedCandidate = WearableDeviceState()
        connectedCandidate.candidates = [
            WearableDeviceCandidate(
                id: "connected",
                name: "Whoordan wearable",
                rssi: -42,
                advertisedServiceUUIDs: [],
                matchesExpectedService: true,
                isConnectedToPhone: true,
                isPreferredOwnedDevice: true,
                lastSeen: Date(timeIntervalSince1970: 1)
            )
        ]

        XCTAssertFalse(realtime.shouldShowPairWearableCTA)
        XCTAssertFalse(historicalSync.shouldShowPairWearableCTA)
        XCTAssertFalse(connectedCandidate.shouldShowPairWearableCTA)
    }

    func testMetricPagesShowPairWearableCTAWhenWearableIsDisconnected() {
        for connection in [
            WearableConnectionState.idle,
            .approvalRequired,
            .disconnected,
            .error
        ] {
            var device = WearableDeviceState()
            device.connection = connection

            XCTAssertTrue(device.shouldShowPairWearableCTA)
        }
    }

    func testHighFrequencyWearablePacketCountersAreThrottledForUI() async throws {
        var currentTime = Date(timeIntervalSince1970: 10_000)
        let environment = makeEnvironment(
            minimumPublishInterval: 60,
            now: { currentTime }
        )
        var live = WearableDeviceState()
        live.connection = .realtime

        environment.receiveWearableState(live)

        XCTAssertEqual(environment.deviceState.connection, .realtime)
        XCTAssertEqual(environment.deviceState.payloadProcessing.processedPayloadCount, 0)

        currentTime = currentTime.addingTimeInterval(1)
        var firstPacket = live
        firstPacket.lastPacketAt = currentTime
        firstPacket.payloadProcessing.processedPayloadCount = 1
        firstPacket.payloadProcessing.imuSampleCount = 100
        environment.receiveWearableState(firstPacket)

        currentTime = currentTime.addingTimeInterval(1)
        var secondPacket = live
        secondPacket.lastPacketAt = currentTime
        secondPacket.payloadProcessing.processedPayloadCount = 2
        secondPacket.payloadProcessing.imuSampleCount = 200
        environment.receiveWearableState(secondPacket)

        XCTAssertEqual(
            environment.deviceState.payloadProcessing.processedPayloadCount,
            0,
            "Packet counter churn should be coalesced so Developer Tools does not repaint on every BLE packet."
        )
        XCTAssertEqual(environment.deviceState.payloadProcessing.imuSampleCount, 0)
    }

    func testWearableConnectionAndCaptureStatePublishImmediately() async throws {
        var currentTime = Date(timeIntervalSince1970: 11_000)
        let environment = makeEnvironment(
            minimumPublishInterval: 60,
            now: { currentTime }
        )
        var live = WearableDeviceState()
        live.connection = .realtime

        environment.receiveWearableState(live)
        XCTAssertEqual(environment.deviceState.connection, .realtime)

        currentTime = currentTime.addingTimeInterval(1)
        var capturing = live
        capturing.rawCapture = WearableCaptureDiagnostics(
            isActive: true,
            scenario: .walking,
            recordCount: 0,
            maxRecords: 10_000,
            lastCapturedAt: nil,
            lastDirection: nil,
            lastDecodedPacketType: nil,
            fileFingerprint: "redacted",
            lastError: nil
        )
        environment.receiveWearableState(capturing)

        XCTAssertTrue(environment.deviceState.rawCapture.isActive)
        XCTAssertEqual(environment.deviceState.rawCapture.scenario, .walking)

        currentTime = currentTime.addingTimeInterval(1)
        var disconnected = capturing
        disconnected.connection = .disconnected
        environment.receiveWearableState(disconnected)

        XCTAssertEqual(environment.deviceState.connection, .disconnected)
    }

    func testMetricDetailTimelineLazyLoadsOnlyRelevantSamplesWithLimit() async throws {
        let currentTime = Date(timeIntervalSince1970: 20_000)
        let environment = makeEnvironment(
            minimumPublishInterval: 60,
            now: { currentTime },
            authService: RestoringAuthService()
        )
        await environment.restore()
        let base = currentTime.addingTimeInterval(-3_600)
        let heartRateSamples = (0..<12).map { index in
            HealthSample(
                id: "hr-\(index)",
                type: .heartRate,
                value: Double(60 + index),
                unit: "bpm",
                startDate: base.addingTimeInterval(Double(index) * 60),
                endDate: nil,
                source: .wearableBLE,
                sourceRecordID: "hr-\(index)",
                confidence: .high,
                metadata: [:]
            )
        }
        let stepSample = HealthSample(
            id: "steps",
            type: .steps,
            value: 4_200,
            unit: "count",
            startDate: base,
            endDate: nil,
            source: .wearableBLE,
            sourceRecordID: "steps",
            confidence: .high,
            metadata: [:]
        )
        let appleHealthHeartRate = HealthSample(
            id: "apple-hr",
            type: .heartRate,
            value: 180,
            unit: "bpm",
            startDate: base.addingTimeInterval(13 * 60),
            endDate: nil,
            source: .appleHealth,
            sourceRecordID: "apple-hr",
            confidence: .high,
            metadata: [:]
        )
        let legacyHeartRate = HealthSample(
            id: "legacy-hr",
            type: .heartRate,
            value: 80,
            unit: "bpm",
            startDate: base.addingTimeInterval(14 * 60),
            endDate: nil,
            source: .legacyWearableDeviceExport,
            sourceRecordID: "legacy-hr",
            confidence: .high,
            metadata: [:]
        )

        try await environment.localStore.saveHealthSamples(
            heartRateSamples + [stepSample, appleHealthHeartRate, legacyHeartRate],
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: currentTime
        )

        let timeline = await environment.loadMetricDetailTimeline(for: .heartRate, days: 1, sampleLimit: 5)

        XCTAssertEqual(timeline.metricID, .heartRate)
        XCTAssertEqual(timeline.points.map(\.value), [68, 69, 70, 71, 80])
        XCTAssertEqual(timeline.sampleTypesLoaded, [.heartRate])
        XCTAssertTrue(timeline.wasLimited)
    }

    func testRawWristTemperatureTimelineLoadsBoundedTemperatureSamples() async throws {
        let currentTime = Date(timeIntervalSince1970: 30_000)
        let environment = makeEnvironment(
            minimumPublishInterval: 60,
            now: { currentTime },
            authService: RestoringAuthService()
        )
        await environment.restore()
        let base = currentTime.addingTimeInterval(-3_600)
        let samples = [
            HealthSample(
                id: "raw-temp-1",
                type: .wristTemperature,
                value: 34.1,
                unit: "degC",
                startDate: base,
                endDate: nil,
                source: .wearableBLE,
                sourceRecordID: "raw-temp-1",
                confidence: .high,
                metadata: ["metric_policy": "raw_device_contact_temperature_not_baseline_delta"]
            ),
            HealthSample(
                id: "temp-event",
                type: .temperatureEvent,
                value: 34.3,
                unit: "degC",
                startDate: base.addingTimeInterval(60),
                endDate: nil,
                source: .wearableBLE,
                sourceRecordID: "temp-event",
                confidence: .medium,
                metadata: ["metric_policy": "device_temperature_event_not_body_temperature"]
            ),
            HealthSample(
                id: "legacy-body-temp",
                type: .bodyTemperature,
                value: 36.6,
                unit: "degC",
                startDate: base.addingTimeInterval(120),
                endDate: nil,
                source: .legacyWearableDeviceExport,
                sourceRecordID: "legacy-body-temp",
                confidence: .low,
                metadata: [:]
            ),
            HealthSample(
                id: "apple-wrist-temp",
                type: .wristTemperature,
                value: 35.5,
                unit: "degC",
                startDate: base.addingTimeInterval(180),
                endDate: nil,
                source: .appleHealth,
                sourceRecordID: "apple-wrist-temp",
                confidence: .high,
                metadata: [:]
            )
        ]

        try await environment.localStore.saveHealthSamples(
            samples,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: currentTime
        )

        let timeline = await environment.loadMetricDetailTimeline(for: .rawWristTemperature, days: 1, sampleLimit: 10)

        XCTAssertEqual(timeline.metricID, .rawWristTemperature)
        XCTAssertEqual(timeline.sampleTypesLoaded, [.wristTemperature, .temperatureEvent, .bodyTemperature])
        XCTAssertEqual(timeline.points.map(\.value), [34.1, 34.3, 36.6])
        XCTAssertFalse(timeline.wasLimited)
    }

    func testSyntheticCalibrationContextUsesLocalProfileAndWearableHistory() async throws {
        let currentTime = Date(timeIntervalSince1970: 1_735_689_600)
        let ble = StubBLEService()
        let environment = makeEnvironment(
            minimumPublishInterval: 60,
            now: { currentTime },
            authService: RestoringAuthService(),
            bleService: ble
        )
        try await environment.localStore.saveBodyProfile(
            BodyProfile(
                ageYears: 22,
                heightCentimeters: 167,
                weightKilograms: 69,
                configuredMaxHeartRate: 194
            ),
            updatedAt: currentTime
        )
        await environment.localStore.saveTodaySummary(DailyHealthSummary(
            date: currentTime,
            recovery: ScoreValue(value: 82, scale: 0...100, confidence: .high, explanation: "wearable history"),
            strain: ScoreValue(value: 11.4, scale: 0...21, confidence: .high, explanation: "wearable history"),
            movement: .empty(),
            sleepSummary: nil,
            sleepMinutes: 430,
            sleepNeedMinutes: 470,
            sleepDebtMinutes: 40,
            restingHeartRate: 49,
            restingHeartRateSource: .legacyWearableDeviceExport,
            restingHeartRateConfidence: .high,
            averageHeartRate: nil,
            maxHeartRate: nil,
            heartRateSampleCount: nil,
            hrv: 78,
            hrvSource: .legacyWearableDeviceExport,
            hrvConfidence: .high,
            respiratoryRate: 14.8,
            respiratoryRateSource: .legacyWearableDeviceExport,
            respiratoryRateConfidence: .high,
            oxygenSaturation: 98,
            oxygenSaturationSource: .legacyWearableDeviceExport,
            oxygenSaturationConfidence: .high,
            vo2Max: nil,
            vo2MaxSource: nil,
            vo2MaxConfidence: nil,
            rawWristTemperatureC: nil,
            rawWristTemperatureSource: nil,
            rawWristTemperatureConfidence: nil,
            bodyTemperatureDelta: nil,
            source: .legacyWearableDeviceExport,
            confidence: .high
        ))

        await environment.restore()

        let context = try XCTUnwrap(ble.lastSyntheticCalibrationContext)
        XCTAssertEqual(context.personID, "person_1")
        XCTAssertEqual(context.profile.heightCentimeters, 167)
        XCTAssertEqual(context.profile.weightKilograms, 69)
        XCTAssertEqual(context.profile.ageYears, 22)
        XCTAssertEqual(context.profile.baselineRestingHeartRateBPM, 49)
        XCTAssertEqual(context.profile.baselineHRVRMSSDMS, 78)
        XCTAssertEqual(context.profile.baselineRespiratoryRate, 14.8)
        XCTAssertEqual(context.profile.baselineSleepMinutes, 430)
        XCTAssertEqual(context.profile.baselineSleepNeedMinutes, 470)
        XCTAssertEqual(context.profile.baselineRecoveryPercent, 82)
        XCTAssertEqual(context.profile.baselineDayStrain, 11.4)
        XCTAssertEqual(context.profile.baselineSpO2Percent, 98)
        XCTAssertEqual(context.calibrationSource, "local_wearable_history_with_profile_fallbacks")
    }

    func testDisconnectedWearableSchedulesOperationalNotification() async throws {
        var currentTime = Date(timeIntervalSince1970: 12_000)
        let notifications = RecordingOperationalNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            operationalNotificationScheduler: notifications
        )
        await environment.restore()

        var connected = WearableDeviceState()
        connected.connection = .realtime
        connected.deviceID = "wearable-1"
        environment.receiveWearableState(connected)

        currentTime = currentTime.addingTimeInterval(1)
        var disconnected = connected
        disconnected.connection = .disconnected
        environment.receiveWearableState(disconnected)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(notifications.scheduledKinds, [.wearableDisconnected])
        XCTAssertEqual(notifications.scheduledRequests.first?.timeInterval, 5)
        XCTAssertTrue(notifications.scheduledRequests.first?.body.contains("disconnected") == true)
    }

    func testDisconnectedWearableNotificationCancelsWhenWearableReconnectsQuickly() async throws {
        var currentTime = Date(timeIntervalSince1970: 12_500)
        let notifications = RecordingOperationalNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            operationalNotificationScheduler: notifications
        )
        await environment.restore()

        var connected = WearableDeviceState()
        connected.connection = .realtime
        connected.deviceID = "wearable-1"
        environment.receiveWearableState(connected)

        currentTime = currentTime.addingTimeInterval(1)
        var disconnected = connected
        disconnected.connection = .disconnected
        environment.receiveWearableState(disconnected)

        currentTime = currentTime.addingTimeInterval(2)
        environment.receiveWearableState(connected)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(notifications.scheduledKinds, [.wearableDisconnected])
        XCTAssertTrue(notifications.canceledKinds.contains(.wearableDisconnected))
    }

    func testLowBatteryNotificationSchedulesOnceUntilBatteryRecovers() async throws {
        var currentTime = Date(timeIntervalSince1970: 13_000)
        let notifications = RecordingOperationalNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            operationalNotificationScheduler: notifications
        )
        await environment.restore()

        var connected = WearableDeviceState()
        connected.connection = .realtime
        connected.batteryPercent = 24
        connected.isCharging = false
        environment.receiveWearableState(connected)

        currentTime = currentTime.addingTimeInterval(1)
        connected.batteryPercent = 20
        environment.receiveWearableState(connected)
        try await Task.sleep(nanoseconds: 20_000_000)

        currentTime = currentTime.addingTimeInterval(1)
        connected.batteryPercent = 18
        environment.receiveWearableState(connected)
        try await Task.sleep(nanoseconds: 20_000_000)

        currentTime = currentTime.addingTimeInterval(1)
        connected.batteryPercent = 35
        environment.receiveWearableState(connected)

        currentTime = currentTime.addingTimeInterval(1)
        connected.batteryPercent = 19
        environment.receiveWearableState(connected)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(notifications.scheduledKinds, [.wearableBatteryLow, .wearableBatteryLow])
        XCTAssertTrue(notifications.scheduledRequests.allSatisfy { $0.body.localizedCaseInsensitiveContains("charge") })
        XCTAssertTrue(notifications.scheduledRequests.allSatisfy { !$0.body.contains("20") && !$0.body.contains("19") && !$0.body.contains("18") })
    }

    func testOffWristReminderSchedulesAfterContinuousOffWristAndCancelsWhenWorn() async throws {
        var currentTime = Date(timeIntervalSince1970: 13_500)
        let notifications = RecordingOperationalNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            operationalNotificationScheduler: notifications
        )
        await environment.restore()

        var connected = WearableDeviceState()
        connected.connection = .realtime
        connected.deviceID = "wearable-1"
        connected.isCharging = false
        connected.isOnWrist = true
        environment.receiveWearableState(connected)

        currentTime = currentTime.addingTimeInterval(1)
        var offWrist = connected
        offWrist.isOnWrist = false
        environment.receiveWearableState(offWrist)
        try await Task.sleep(nanoseconds: 20_000_000)

        environment.receiveWearableState(offWrist)
        try await Task.sleep(nanoseconds: 20_000_000)

        currentTime = currentTime.addingTimeInterval(10)
        environment.receiveWearableState(connected)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(notifications.scheduledKinds, [.wearableOffWrist])
        XCTAssertEqual(notifications.scheduledRequests.first?.timeInterval, 5 * 60)
        XCTAssertTrue(notifications.canceledKinds.contains(.wearableOffWrist))
    }

    func testNormalBackgroundingDoesNotScheduleOpenAppReminder() async throws {
        let notifications = RecordingOperationalNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            operationalNotificationScheduler: notifications
        )
        await environment.restore()

        environment.handleScenePhaseChange(.inactive)
        environment.handleScenePhaseChange(.background)
        try await Task.sleep(nanoseconds: 20_000_000)
        environment.handleScenePhaseChange(.active)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertFalse(notifications.scheduledKinds.contains(.openAppReminder))
        XCTAssertTrue(notifications.canceledKinds.contains(.openAppReminder))
    }

    func testBackgroundRestartsApprovedWearableServices() async throws {
        let ble = StubBLEService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: ble
        )
        await environment.restore()
        let startCountAfterRestore = ble.startAutoConnectCount

        environment.handleScenePhaseChange(.background)

        XCTAssertGreaterThan(ble.startAutoConnectCount, startCountAfterRestore)
    }

    func testBackgroundUsesExtendedTaskForCriticalFlushWork() async throws {
        let backgroundTasks = RecordingBackgroundTaskManager()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            backgroundTaskManager: backgroundTasks
        )
        await environment.restore()

        environment.handleScenePhaseChange(.background)

        try await waitUntil {
            backgroundTasks.names.contains("whoordan.background.flush")
        }
    }

    func testEnablingCallVibrationStartsApprovedWearableServices() async throws {
        let ble = StubBLEService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: ble
        )
        await environment.restore()
        let startCountAfterRestore = ble.startAutoConnectCount

        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))

        XCTAssertGreaterThan(ble.startAutoConnectCount, startCountAfterRestore)
    }

    func testIncomingCellularCallRepeatsPreviewUntilCallEndCancelsActiveVibration() async throws {
        let callID = UUID()
        var wearable = WearableDeviceState()
        wearable.connection = .realtime
        let haptics = RecordingHapticService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: StubBLEService(state: wearable),
            hapticService: haptics,
            repeatIntervalNanoseconds: 10_000_000
        )
        await environment.restore()
        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))

        await environment.receiveCallStateEvent(.incomingCellularRinging(id: callID, receivedAt: Date()))
        try await Task.sleep(nanoseconds: 45_000_000)

        XCTAssertGreaterThanOrEqual(haptics.previewedPatternIDs.count, 2)
        XCTAssertTrue(haptics.previewedPatternIDs.allSatisfy { $0 == VibrationPattern.standardID })
        XCTAssertTrue(environment.isCellularCallVibrationActive)
        XCTAssertEqual(environment.activeCellularCall?.id, callID)
        XCTAssertEqual(environment.lastCallStateEventMessage, "Incoming cellular call event received.")
        XCTAssertEqual(environment.lastCallVibrationRouting.reason, .incomingCellularCall)

        await environment.receiveCallStateEvent(.cellularCallEnded(id: callID))
        let previewCountAfterEnd = haptics.previewedPatternIDs.count
        try await Task.sleep(nanoseconds: 35_000_000)

        XCTAssertEqual(haptics.cancelCount, 1)
        XCTAssertEqual(haptics.previewedPatternIDs.count, previewCountAfterEnd)
        XCTAssertFalse(environment.isCellularCallVibrationActive)
        XCTAssertNil(environment.activeCellularCall)
    }

    func testDoubleTapStopsRepeatingCellularCallVibration() async throws {
        let callID = UUID()
        var wearable = WearableDeviceState()
        wearable.connection = .realtime
        let haptics = RecordingHapticService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: StubBLEService(state: wearable),
            hapticService: haptics,
            repeatIntervalNanoseconds: 10_000_000
        )
        await environment.restore()
        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))

        await environment.receiveCallStateEvent(.incomingCellularRinging(id: callID, receivedAt: Date()))
        try await Task.sleep(nanoseconds: 35_000_000)
        await environment.routeDoubleTap(action: .declineCallWhereSupported)
        let previewCountAfterDoubleTap = haptics.previewedPatternIDs.count
        try await Task.sleep(nanoseconds: 35_000_000)

        XCTAssertEqual(environment.lastDoubleTapRouting.status, .silencedCallVibration)
        XCTAssertEqual(haptics.cancelCount, 1)
        XCTAssertEqual(haptics.previewedPatternIDs.count, previewCountAfterDoubleTap)
        XCTAssertFalse(environment.isCellularCallVibrationActive)
    }

    func testWhoordanAlarmRepeatsPreviewUntilDoubleTapSnoozes() async throws {
        var wearable = WearableDeviceState()
        wearable.connection = .realtime
        let haptics = RecordingHapticService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: StubBLEService(state: wearable),
            hapticService: haptics,
            repeatIntervalNanoseconds: 10_000_000
        )
        await environment.restore()
        let alarm = Alarm(label: "Wake", hour: 7, minute: 30, snoozeEnabled: true)

        await environment.triggerAlarm(alarm, now: Date())
        try await waitUntil {
            haptics.previewedPatternIDs.count >= 2
        }

        XCTAssertGreaterThanOrEqual(haptics.previewedPatternIDs.count, 2)
        XCTAssertTrue(haptics.previewedPatternIDs.allSatisfy { $0 == VibrationPattern.standardID })
        XCTAssertEqual(environment.activeAlarm?.id, alarm.id)
        XCTAssertEqual(environment.activeAlarm?.deliveryStatus, .deliveredToWearable)

        await environment.routeDoubleTap(action: .snoozeAlarmWhereSupported)
        let previewCountAfterSnooze = haptics.previewedPatternIDs.count
        try await Task.sleep(nanoseconds: 35_000_000)

        XCTAssertEqual(environment.lastDoubleTapRouting.status, .snoozedAlarm)
        XCTAssertEqual(haptics.cancelCount, 1)
        XCTAssertEqual(haptics.previewedPatternIDs.count, previewCountAfterSnooze)
        XCTAssertNil(environment.activeAlarm)
    }

    func testDisablingActiveWhoordanAlarmStopsRepeatingVibration() async throws {
        var wearable = WearableDeviceState()
        wearable.connection = .realtime
        let haptics = RecordingHapticService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: StubBLEService(state: wearable),
            hapticService: haptics,
            repeatIntervalNanoseconds: 10_000_000
        )
        await environment.restore()
        let alarm = Alarm(label: "Wake", hour: 7, minute: 30, snoozeEnabled: true)

        await environment.triggerAlarm(alarm, now: Date())
        try await Task.sleep(nanoseconds: 25_000_000)
        guard var activeAlarm = environment.activeAlarm else {
            XCTFail("Expected active alarm after trigger.")
            return
        }
        activeAlarm.enabled = false
        environment.saveAlarm(activeAlarm)
        let previewCountAfterDisable = haptics.previewedPatternIDs.count
        try await Task.sleep(nanoseconds: 35_000_000)

        XCTAssertNil(environment.activeAlarm)
        XCTAssertEqual(haptics.cancelCount, 1)
        XCTAssertEqual(haptics.previewedPatternIDs.count, previewCountAfterDisable)
    }

    func testSaveAlarmSchedulesAndCancelsLocalNotificationFallback() async throws {
        let alarmNotifications = RecordingAlarmNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            alarmScheduler: alarmNotifications
        )
        await environment.restore()
        let alarm = Alarm(label: "Wake", hour: 7, minute: 30)

        environment.saveAlarm(alarm)
        try await waitUntil {
            alarmNotifications.scheduledAlarmIDs == [alarm.id]
                && environment.lastAlarmSchedulingResult.status == .scheduled
        }

        XCTAssertEqual(alarmNotifications.scheduledAlarmIDs, [alarm.id])
        XCTAssertEqual(environment.lastAlarmSchedulingResult.status, .scheduled)

        var disabled = alarm
        disabled.enabled = false
        environment.saveAlarm(disabled)
        try await waitUntil {
            alarmNotifications.canceledAlarmIDs == [alarm.id]
                && environment.lastAlarmSchedulingResult.status == .canceled
        }

        XCTAssertEqual(alarmNotifications.canceledAlarmIDs, [alarm.id])
        XCTAssertEqual(environment.lastAlarmSchedulingResult.status, .canceled)
    }

    func testRestoreReschedulesLoadedAlarmNotificationFallback() async throws {
        let currentTime = Date(timeIntervalSince1970: 1_735_671_600)
        let triggerAt = currentTime.addingTimeInterval(9 * 3_600)
        let alarm = Alarm(
            label: "Midnight",
            hour: 0,
            minute: 0,
            timezone: "UTC",
            nextTriggerAt: triggerAt
        )
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-restore-alarm-notification-\(UUID().uuidString).json")
        )
        try await store.saveAlarm(alarm)
        let alarmNotifications = RecordingAlarmNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            localStore: store,
            alarmScheduler: alarmNotifications
        )

        await environment.restore()
        try await waitUntil {
            alarmNotifications.scheduledAlarmIDs == [alarm.id]
        }

        XCTAssertEqual(alarmNotifications.scheduledAlarms.first?.nextTriggerAt, triggerAt)
        XCTAssertEqual(environment.lastAlarmSchedulingResult.status, .scheduled)
    }

    func testRestoreTriggersDueAlarmAfterAppWasNotRunning() async throws {
        let currentTime = Date(timeIntervalSince1970: 1_735_704_000)
        let alarm = Alarm(
            label: "Midnight",
            hour: 0,
            minute: 0,
            timezone: "UTC",
            nextTriggerAt: currentTime.addingTimeInterval(-60)
        )
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-restore-due-alarm-\(UUID().uuidString).json")
        )
        try await store.saveAlarm(alarm)
        var wearable = WearableDeviceState()
        wearable.connection = .realtime
        let haptics = RecordingHapticService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            bleService: StubBLEService(state: wearable),
            hapticService: haptics,
            localStore: store,
            repeatIntervalNanoseconds: 1_000_000_000
        )

        await environment.restore()

        XCTAssertEqual(environment.activeAlarm?.id, alarm.id)
        XCTAssertEqual(environment.activeAlarm?.deliveryStatus, .deliveredToWearable)
        XCTAssertEqual(haptics.previewedPatternIDs.first, VibrationPattern.standardID)
    }

    func testRemoteRestoredAlarmSchedulesLocalNotificationFallback() async throws {
        let currentTime = Date(timeIntervalSince1970: 1_735_671_600)
        let triggerAt = currentTime.addingTimeInterval(9 * 3_600)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-remote-alarm-restore-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true))
        let alarm = Alarm(
            label: "Cloud Midnight",
            hour: 0,
            minute: 0,
            timezone: "UTC",
            nextTriggerAt: triggerAt
        )
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(cloudSyncPromptDismissed: true),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [alarm],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: 8_000,
            updatedAt: currentTime
        )
        let alarmNotifications = RecordingAlarmNotificationScheduler()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            localStore: store,
            accountSyncService: accountSync,
            alarmScheduler: alarmNotifications
        )

        await environment.restore()
        try await waitUntil {
            alarmNotifications.scheduledAlarmIDs.contains(alarm.id)
        }

        XCTAssertEqual(environment.alarms.map { $0.id }, [alarm.id])
        XCTAssertEqual(alarmNotifications.scheduledAlarms.last?.nextTriggerAt, triggerAt)
    }

    func testNotificationPermissionRequestRunsAfterApproval() async throws {
        let permissions = RecordingNotificationPermissionAuthorizer(
            requestResult: NotificationPermissionResult(status: .authorized, message: "Allowed in tests.")
        )
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            notificationPermissionService: permissions
        )
        await environment.restore()

        await environment.requestNotificationPermission()

        XCTAssertEqual(permissions.requestCount, 1)
        XCTAssertEqual(environment.notificationPermissionResult.status, .authorized)
    }

    func testNotificationPermissionRequestIsApprovalGated() async throws {
        let permissions = RecordingNotificationPermissionAuthorizer(
            requestResult: NotificationPermissionResult(status: .authorized, message: "Allowed in tests.")
        )
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            notificationPermissionService: permissions
        )

        await environment.requestNotificationPermission()

        XCTAssertEqual(permissions.requestCount, 0)
        XCTAssertEqual(environment.notificationPermissionResult.status, .unavailable)
        XCTAssertTrue(environment.notificationPermissionResult.message.contains("approval"))
    }

    func testRestoreDoesNotPrimeBluetoothPermissionBeforeApproval() async throws {
        let ble = StubBLEService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: StubAuthService(),
            bleService: ble
        )

        await environment.restore()

        XCTAssertEqual(ble.primeBluetoothPermissionCount, 0)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 0)
        XCTAssertEqual(ble.startScanningCount, 0)
    }

    func testForegroundBluetoothRetryRunsOnlyAfterApproval() async throws {
        let ble = StubBLEService()
        let lockedEnvironment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: StubAuthService(),
            bleService: ble
        )

        await lockedEnvironment.restore()
        lockedEnvironment.retryBluetoothPermissionProbe()

        XCTAssertEqual(ble.primeBluetoothPermissionCount, 0)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 0)
        XCTAssertEqual(ble.startScanningCount, 0)

        let approvedBLE = StubBLEService()
        let approvedEnvironment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: approvedBLE
        )

        await approvedEnvironment.restore()
        approvedEnvironment.retryBluetoothPermissionProbe()

        XCTAssertEqual(approvedBLE.primeBluetoothPermissionCount, 1)
        XCTAssertEqual(approvedBLE.requestBluetoothAccessCount, 0)
        XCTAssertEqual(approvedBLE.startScanningCount, 0)
    }

    func testStartupCloudPromptDoesNotBlockBluetoothPermissionAttempt() async throws {
        let ble = StubBLEService()
        let permissions = RecordingNotificationPermissionAuthorizer(
            requestResult: NotificationPermissionResult(status: .authorized, message: "Allowed in tests.")
        )
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            bleService: ble,
            notificationPermissionService: permissions
        )
        await environment.restore()

        await environment.requestStartupPermissionsIfNeeded()

        XCTAssertTrue(environment.isCloudSyncConsentPromptPresented)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 1)

        environment.enableCloudHealthSyncFromPrompt()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertTrue(environment.consentState.localModeEnabled)
        XCTAssertTrue(environment.consentState.cloudSyncEnabled)
        XCTAssertTrue(environment.consentState.healthDataCloudConsent)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 1)
        XCTAssertEqual(permissions.requestCount, 1)
    }

    func testStartupWithoutCloudPromptRequestsBluetoothAccessPath() async throws {
        let ble = StubBLEService()
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-startup-permission-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            localModeEnabled: true,
            cloudSyncEnabled: false,
            healthDataCloudConsent: false,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: NoopAccountSyncService(),
            bleService: ble,
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )

        await environment.restore()
        await environment.requestStartupPermissionsIfNeeded()

        XCTAssertFalse(environment.isCloudSyncConsentPromptPresented)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 1)
    }

    func testStartupCloudPromptIsOnlyShownOnFirstApprovedLaunchAfterInstall() async throws {
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-startup-cloud-prompt-\(UUID().uuidString).json")
        )
        let firstBLE = StubBLEService()
        let firstEnvironment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: NoopAccountSyncService(),
            bleService: firstBLE,
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )
        await firstEnvironment.restore()

        await firstEnvironment.requestStartupPermissionsIfNeeded()

        XCTAssertTrue(firstEnvironment.isCloudSyncConsentPromptPresented)
        XCTAssertTrue(firstEnvironment.consentState.cloudSyncPromptDismissed)

        let secondBLE = StubBLEService()
        let secondEnvironment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: NoopAccountSyncService(),
            bleService: secondBLE,
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )
        await secondEnvironment.restore()
        await secondEnvironment.requestStartupPermissionsIfNeeded()

        XCTAssertFalse(secondEnvironment.isCloudSyncConsentPromptPresented)
        XCTAssertFalse(secondEnvironment.consentState.canUploadHealthData)
        XCTAssertEqual(secondBLE.requestBluetoothAccessCount, 1)
    }

    func testStartupPermissionsWaitForRestoredConsentBeforePromptDecision() async throws {
        let baseStore = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-startup-consent-race-\(UUID().uuidString).json")
        )
        await baseStore.saveConsentState(ConsentState(
            cloudSyncEnabled: false,
            healthDataCloudConsent: false,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        let store = BlockingConsentLoadStore(base: baseStore)
        let ble = StubBLEService()
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: NoopAccountSyncService(),
            bleService: ble,
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )

        let restore = Task { @MainActor in
            await environment.restore()
        }
        await store.waitUntilConsentLoadStarted()
        await environment.requestStartupPermissionsIfNeeded()

        XCTAssertFalse(environment.isCloudSyncConsentPromptPresented)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 0)

        await store.releaseConsentLoad()
        await restore.value
        await environment.requestStartupPermissionsIfNeeded()

        XCTAssertFalse(environment.isCloudSyncConsentPromptPresented)
        XCTAssertTrue(environment.consentState.cloudSyncPromptDismissed)
        XCTAssertFalse(environment.consentState.canUploadHealthData)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 1)
    }

    func testApprovedRestoreShowsMainRouteWhileLocalStateStillLoads() async throws {
        let baseStore = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-approved-route-local-load-\(UUID().uuidString).json")
        )
        await baseStore.saveConsentState(ConsentState(
            localModeEnabled: true,
            cloudSyncEnabled: false,
            healthDataCloudConsent: false,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        let store = BlockingConsentLoadStore(base: baseStore)
        let ble = StubBLEService()
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: NoopAccountSyncService(),
            bleService: ble,
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )

        let restore = Task { @MainActor in
            await environment.restore()
        }
        await store.waitUntilConsentLoadStarted()

        XCTAssertEqual(environment.route, .approved)
        XCTAssertFalse(environment.isRestoring)
        XCTAssertFalse(environment.hasLoadedApprovedLocalState)

        await environment.requestStartupPermissionsIfNeeded()
        XCTAssertFalse(environment.isCloudSyncConsentPromptPresented)
        XCTAssertEqual(ble.requestBluetoothAccessCount, 0)

        await store.releaseConsentLoad()
        await restore.value

        XCTAssertEqual(environment.route, .approved)
        XCTAssertTrue(environment.hasLoadedApprovedLocalState)
        await environment.requestStartupPermissionsIfNeeded()
        XCTAssertEqual(ble.requestBluetoothAccessCount, 1)
    }

    func testManualWearableScanIsApprovalGated() {
        let ble = StubBLEService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            bleService: ble
        )

        environment.scanForWearable()

        XCTAssertEqual(ble.startScanningCount, 0)
        XCTAssertEqual(environment.deviceState.connection, .approvalRequired)
    }

    func testBodyProfileAndVibrationSettingsUploadThroughAccountSync() async throws {
        let accountSync = RecordingAccountSyncService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            accountSyncService: accountSync
        )
        await environment.restore()
        environment.updateConsent { $0.cloudSyncEnabled = true }
        try await waitUntil { environment.consentState.cloudSyncEnabled }
        accountSync.uploadedSnapshots.removeAll()

        let birthDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1998, month: 6, day: 12))
        environment.updateBodyProfile(BodyProfile(
            birthDate: birthDate,
            biologicalSex: .female,
            heightCentimeters: 167,
            weightKilograms: 69
        ))
        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))

        try await waitUntil {
            environment.bodyProfile.heightCentimeters == 167
                && environment.bodyProfile.weightKilograms == 69
                && environment.bodyProfile.biologicalSex == .female
                && environment.callVibrationSettings.enabled
        }
        accountSync.uploadedSnapshots.removeAll()
        await environment.syncAccountSettingsNow()

        let snapshot = try XCTUnwrap(accountSync.uploadedSnapshots.last)
        XCTAssertEqual(snapshot.bodyProfile.heightCentimeters, 167)
        XCTAssertEqual(snapshot.bodyProfile.weightKilograms, 69)
        XCTAssertEqual(snapshot.bodyProfile.biologicalSex, .female)
        XCTAssertTrue(snapshot.callVibrationSettings.enabled)
        XCTAssertFalse(snapshot.consentState.canUploadHealthData)
    }

    func testSkinTemperatureBaselineUploadsOnlyAfterCloudSyncEnabled() async throws {
        let accountSync = RecordingAccountSyncService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            accountSyncService: accountSync
        )
        await environment.restore()
        accountSync.uploadedSnapshots.removeAll()

        environment.updateTemporarySkinTemperatureBaselineC(34.2)
        try await waitUntil {
            environment.skinTemperatureBaselineProfile.activeBaselineC == 34.2
        }

        XCTAssertTrue(accountSync.uploadedSnapshots.allSatisfy { $0.skinTemperatureBaselineProfile == nil })

        accountSync.uploadedSnapshots.removeAll()
        environment.updateConsent {
            $0.cloudSyncEnabled = true
            $0.healthDataCloudConsent = true
        }
        try await waitUntil {
            accountSync.includeHealthBaselineFetches.contains(true)
                && accountSync.uploadedSnapshots.contains { snapshot in
                    snapshot.skinTemperatureBaselineProfile?.activeBaselineC == 34.2
                        && snapshot.skinTemperatureBaselineProfile?.source == .temporaryCustom
                }
        }

        XCTAssertTrue(accountSync.includeHealthBaselineFetches.contains(true))
        XCTAssertTrue(accountSync.uploadedSnapshots.contains { snapshot in
            snapshot.skinTemperatureBaselineProfile?.activeBaselineC == 34.2
                && snapshot.skinTemperatureBaselineProfile?.source == .temporaryCustom
        })
    }

    func testRemoteSkinTemperatureBaselineRestoresAfterCloudSyncEnabled() async throws {
        let accountSync = RecordingAccountSyncService()
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(appleHealthEnabled: true),
            skinTemperatureBaselineProfile: SkinTemperatureBaselineProfile(
                activeBaselineC: 33.8,
                source: .automatic,
                eligibleDayCount: 9,
                requiredDayCount: 5,
                updatedAt: updatedAt,
                automaticBaselineSetAt: updatedAt
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: updatedAt,
            includesProfile: false,
            includesSettings: true
        )
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            accountSyncService: accountSync
        )

        await environment.restore()

        XCTAssertFalse(accountSync.includeHealthBaselineFetches.contains(true))
        XCTAssertFalse(environment.skinTemperatureBaselineProfile.hasActiveBaseline)

        environment.updateConsent {
            $0.cloudSyncEnabled = true
            $0.healthDataCloudConsent = true
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(environment.skinTemperatureBaselineProfile.activeBaselineC, 33.8)
        XCTAssertEqual(environment.skinTemperatureBaselineProfile.source, .automatic)
        XCTAssertEqual(environment.skinTemperatureBaselineProfile.eligibleDayCount, 9)
    }

    func testCloudSyncToggleRestoresAndSyncsSettingsAndHealthData() async throws {
        let now = Date(timeIntervalSince1970: 1_779_100_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-cloud-sync-toggle-\(UUID().uuidString).json")
        )
        let remoteSettingsUpdatedAt = now.addingTimeInterval(60)
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = makeCloudSyncRemoteSnapshot(updatedAt: remoteSettingsUpdatedAt)
        let healthSync = RecordingHealthRestoreSyncService()
        healthSync.restoredSummaries = [makeRestoredCloudSummary(at: now)]
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { now },
            authService: RestoringAuthService(),
            localStore: store,
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            repeatIntervalNanoseconds: 1_000_000_000
        )

        await environment.restore()
        XCTAssertFalse(environment.consentState.cloudSyncEnabled)
        XCTAssertTrue(accountSync.includeHealthBaselineFetches.isEmpty)
        XCTAssertEqual(healthSync.fetchRecentDailySummariesCount, 0)

        environment.setCloudSyncEnabled(true)

        try await waitUntil {
            accountSync.includeHealthBaselineFetches.contains(true)
                && !accountSync.uploadedSnapshots.isEmpty
                && healthSync.fetchRecentDailySummariesCount == 1
                && healthSync.fetchRecentHealthSamplesCount == 1
                && healthSync.uploadDailySummaryCount == 1
        }

        XCTAssertTrue(environment.consentState.cloudSyncEnabled)
        XCTAssertTrue(environment.consentState.healthDataCloudConsent)
        XCTAssertEqual(environment.callVibrationSettings.lastUpdatedAt, remoteSettingsUpdatedAt)
        XCTAssertEqual(environment.alarms.first?.label, "Cloud alarm")
        XCTAssertEqual(environment.todaySnapshot.sleepMinutes, 430)
        XCTAssertEqual(environment.todaySnapshot.hrv, 58)
        XCTAssertEqual(environment.todaySnapshot.movement.steps, 8_765)
        XCTAssertEqual(accountSync.uploadedSnapshots.last?.movementGoal, 12_000)
        XCTAssertEqual(healthSync.dailySummaryLimits, [3_650])
        XCTAssertEqual(healthSync.healthSampleLimits, [25_000])
    }

    func testRemoteAccountSyncDoesNotRunBeforeLocalCloudOptIn() async throws {
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: true,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: Date(),
            includesProfile: false,
            includesSettings: true
        )
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: Date.init,
            authService: RestoringAuthService(),
            accountSyncService: accountSync
        )

        await environment.restore()

        XCTAssertFalse(environment.consentState.cloudSyncEnabled)
        XCTAssertFalse(environment.consentState.healthDataCloudConsent)
        XCTAssertFalse(environment.consentState.canUploadHealthData)
        XCTAssertFalse(environment.consentState.cloudSyncPromptDismissed)
        XCTAssertFalse(environment.consentState.appleHealthEnabled)
        XCTAssertTrue(accountSync.includeHealthBaselineFetches.isEmpty)
        XCTAssertTrue(accountSync.uploadedSnapshots.isEmpty)
    }

    func testRemoteCloudConsentDoesNotAllowStartupHealthRestoreWithoutLocalOptIn() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-remote-consent-restore-\(UUID().uuidString).json")
        )
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.sleepMinutes = 512
        restored.averageHeartRate = 67.4
        restored.source = .whoordanEstimate
        restored.confidence = .low
        let healthSync = RecordingHealthRestoreSyncService()
        healthSync.restoredSummaries = [restored]
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertFalse(environment.consentState.canUploadHealthData)
        XCTAssertEqual(healthSync.fetchRecentHealthSamplesCount, 0)
        XCTAssertEqual(healthSync.fetchRecentDailySummariesCount, 0)
        XCTAssertNil(environment.todaySnapshot.sleepMinutes)
        XCTAssertNil(environment.todaySnapshot.averageHeartRate)
    }

    func testStartupCloudSettingsRestoreMissDoesNotUploadStaleLocalSnapshot() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-settings-restore-miss-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        try await store.saveCallVibrationSettings(CallVibrationSettings(
            enabled: true,
            patternID: VibrationPattern.standardID,
            lastUpdatedAt: now.addingTimeInterval(-3_600)
        ))

        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = nil
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertTrue(accountSync.includeHealthBaselineFetches.contains(true))
        XCTAssertTrue(accountSync.uploadedSnapshots.isEmpty)
        XCTAssertTrue(environment.callVibrationSettings.enabled)
    }

    func testStartupCloudCallVibrationRestoreBeatsMissingLocalDefault() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let remoteSettingsDate = Date(timeIntervalSince1970: 1_735_689_600)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-call-vibration-remote-default-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true))
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(),
            callVibrationSettings: CallVibrationSettings(
                enabled: true,
                patternID: VibrationPattern.standardID,
                lastUpdatedAt: remoteSettingsDate
            ),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertTrue(environment.callVibrationSettings.enabled)
        XCTAssertEqual(environment.callVibrationSettings.lastUpdatedAt, remoteSettingsDate)
        let persisted = await store.loadCallVibrationSettings()
        XCTAssertTrue(persisted.enabled)
        XCTAssertEqual(persisted.lastUpdatedAt, remoteSettingsDate)
        XCTAssertTrue(accountSync.uploadedSnapshots.isEmpty)
    }

    func testMissingRemoteCallVibrationSettingsDoesNotOverwriteNewerLocalEnabledState() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let localSettingsDate = Date(timeIntervalSince1970: 1_735_689_600)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-call-vibration-local-wins-\(UUID().uuidString).json")
        )
        try await store.saveCallVibrationSettings(CallVibrationSettings(
            enabled: true,
            patternID: VibrationPattern.standardID,
            lastUpdatedAt: localSettingsDate
        ))
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertTrue(environment.callVibrationSettings.enabled)
        XCTAssertEqual(environment.callVibrationSettings.lastUpdatedAt, localSettingsDate)
    }

    func testCallVibrationSettingsLoadBeforeSlowLocalStateRestore() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let settingsDate = Date(timeIntervalSince1970: 1_735_689_600)
        let baseStore = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-call-vibration-fast-load-\(UUID().uuidString).json")
        )
        try await baseStore.saveCallVibrationSettings(CallVibrationSettings(
            enabled: true,
            patternID: VibrationPattern.standardID,
            lastUpdatedAt: settingsDate
        ))
        let store = BlockingConsentLoadStore(base: baseStore)
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: RecordingAccountSyncService(),
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        let restoreTask = Task { await environment.restore() }
        await store.waitUntilConsentLoadStarted()

        XCTAssertTrue(environment.hasLoadedCallVibrationSettings)
        XCTAssertTrue(environment.callVibrationSettings.enabled)
        XCTAssertFalse(environment.hasLoadedApprovedLocalState)

        await store.releaseConsentLoad()
        await restoreTask.value
    }

    func testBackgroundFlushPersistsCallVibrationSettingsForRelaunch() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-call-vibration-background-flush-\(UUID().uuidString).json")
        )
        let accountSync = RecordingAccountSyncService()
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )
        await environment.restore()
        accountSync.uploadedSnapshots.removeAll()

        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))
        environment.handleScenePhaseChange(.background)

        let deadline = Date().addingTimeInterval(1)
        while !(await store.loadCallVibrationSettings()).enabled && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(accountSync.uploadedSnapshots.isEmpty)
        let persisted = await store.loadCallVibrationSettings()
        XCTAssertTrue(persisted.enabled)
        XCTAssertEqual(persisted.lastUpdatedAt, now)
    }

    func testCallVibrationSettingsFallbackSurvivesRelaunchBeforeAsyncStoreSave() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let baseStore = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-call-vibration-fallback-\(UUID().uuidString).json")
        )
        let droppingStore = BlockingConsentLoadStore(
            base: baseStore,
            blocksConsentLoad: false,
            dropsCallVibrationSaves: true
        )
        let authService = RestoringAuthService()
        let accountSync = RecordingAccountSyncService()
        let environment = AppEnvironment(
            authService: authService,
            approvalService: StaticApprovalService(state: .approved()),
            localStore: droppingStore,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )
        await environment.restore()

        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))
        try await Task.sleep(nanoseconds: 50_000_000)
        let droppedPersistedValue = await baseStore.loadCallVibrationSettings()
        XCTAssertFalse(droppedPersistedValue.enabled)

        let relaunch = AppEnvironment(
            authService: authService,
            approvalService: StaticApprovalService(state: .approved()),
            localStore: baseStore,
            healthKitService: StubHealthKitService(),
            healthSyncService: RecordingHealthRestoreSyncService(),
            accountSyncService: RecordingAccountSyncService(),
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )
        await relaunch.restore()

        XCTAssertTrue(relaunch.callVibrationSettings.enabled)
        XCTAssertEqual(relaunch.callVibrationSettings.lastUpdatedAt, now)
        await relaunch.signOut()
    }

    func testStartupCloudHealthRestoreDoesNotUploadStaleLocalSummary() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-health-restore-no-upload-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        var staleLocal = DailyHealthSummary.empty
        staleLocal.date = now
        staleLocal.averageHeartRate = 89
        staleLocal.source = .whoordanEstimate
        staleLocal.confidence = .low
        await store.saveTodaySummary(staleLocal)

        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = nil
        let healthSync = RecordingHealthRestoreSyncService()
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(healthSync.fetchRecentDailySummariesCount, 1)
        XCTAssertEqual(healthSync.fetchRecentHealthSamplesCount, 1)
        XCTAssertEqual(healthSync.uploadHealthSamplesCount, 0)
        XCTAssertEqual(healthSync.uploadDailySummaryCount, 0)
        XCTAssertEqual(environment.todaySnapshot.averageHeartRate, 89)
    }

    func testOfflineApprovedStartupDoesNotRestoreCloudSettingsOrHealthData() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-offline-approved-cloud-restore-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        try await store.saveCallVibrationSettings(CallVibrationSettings(
            enabled: true,
            patternID: VibrationPattern.standardID,
            lastUpdatedAt: now.addingTimeInterval(-3_600)
        ))

        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(
                enabled: false,
                patternID: VibrationPattern.standardID,
                lastUpdatedAt: now
            ),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.sleepMinutes = 512
        restored.averageHeartRate = 67.4
        restored.source = .wearableBLE
        restored.confidence = .medium
        let healthSync = RecordingHealthRestoreSyncService()
        healthSync.restoredSummaries = [restored]
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(
                state: ApprovalState(status: .offlineApproved, message: "Offline", checkedAt: now)
            ),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(environment.approvalState?.status, .offlineApproved)
        XCTAssertTrue(environment.consentState.canUploadHealthData)
        XCTAssertFalse(environment.privacyGuard.canUploadHealthData(
            approval: environment.approvalState,
            consent: environment.consentState
        ))
        XCTAssertTrue(environment.callVibrationSettings.enabled)
        XCTAssertEqual(environment.callVibrationSettings.lastUpdatedAt, now.addingTimeInterval(-3_600))
        XCTAssertNil(environment.todaySnapshot.sleepMinutes)
        XCTAssertNil(environment.todaySnapshot.averageHeartRate)
        XCTAssertEqual(healthSync.fetchRecentHealthSamplesCount, 0)
        XCTAssertEqual(healthSync.fetchRecentDailySummariesCount, 0)
        XCTAssertTrue(accountSync.includeHealthBaselineFetches.isEmpty)
        XCTAssertTrue(accountSync.uploadedSnapshots.isEmpty)
    }

    func testStartupOfflineApprovalRetriesCloudRestoreWhenApprovalRecovers() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.sleepMinutes = 512
        restored.averageHeartRate = 67.4
        restored.source = .whoordanEstimate
        restored.confidence = .low
        let healthSync = RecordingHealthRestoreSyncService()
        healthSync.restoredSummaries = [restored]
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-offline-approval-retry-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: SequencedStaticApprovalService(states: [
                ApprovalState(status: .offlineApproved, message: "Offline", checkedAt: now),
                .approved()
            ]),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            startupApprovalRecoveryDelayNanoseconds: 0,
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()
        try await waitUntil {
            environment.todaySnapshot.sleepMinutes == 512
                && environment.approvalState?.status == .approved
        }

        XCTAssertEqual(environment.approvalState?.status, .approved)
        XCTAssertEqual(healthSync.fetchRecentDailySummariesCount, 1)
    }

    func testStartupAppliesCloudMetricSummaryBeforeLargeSampleRestoreFinishes() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-summary-before-samples-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.sleepMinutes = 512
        restored.averageHeartRate = 67.4
        restored.source = .whoordanEstimate
        restored.confidence = .low
        let healthSync = BlockingSampleRestoreSyncService(restoredSummaries: [restored])
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        let restore = Task { @MainActor in
            await environment.restore()
        }
        await healthSync.waitUntilSampleFetchStarted()
        let restoredBeforeSampleFetchCompleted = environment.todaySnapshot.sleepMinutes
        healthSync.releaseSampleFetch()
        await restore.value

        XCTAssertEqual(restoredBeforeSampleFetchCompleted, 512)
        XCTAssertEqual(environment.todaySnapshot.sleepMinutes, 512)
    }

    func testCloudSleepRestoreWinsOverStaleLocalTodaySummary() async throws {
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-stale-local-sleep-restore-\(UUID().uuidString).json")
        )
        var staleLocal = DailyHealthSummary.empty
        staleLocal.date = yesterday
        staleLocal.averageHeartRate = 71
        staleLocal.hrv = 63
        staleLocal.movement.steps = 12_400
        staleLocal.source = .appleHealth
        staleLocal.confidence = .high
        await store.saveTodaySummary(staleLocal)
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))

        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: now,
            includesProfile: false,
            includesSettings: true
        )
        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.sleepMinutes = 512
        restored.averageHeartRate = 67.4
        restored.source = .whoordanEstimate
        restored.confidence = .low
        let healthSync = RecordingHealthRestoreSyncService()
        healthSync.restoredSummaries = [restored]
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSync,
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertTrue(Calendar.current.isDate(environment.todaySnapshot.date, inSameDayAs: now))
        XCTAssertEqual(environment.todaySnapshot.sleepMinutes, 512)
        XCTAssertEqual(environment.todaySnapshot.averageHeartRate, 67.4)
        XCTAssertNil(environment.todaySnapshot.movement.steps)
    }

    func testRestoreRebuildsTodaySnapshotFromStoredOvernightWearableSleepSamples() async throws {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_779_030_000)
        let dayStart = calendar.startOfDay(for: now)
        let sleepStart = dayStart.addingTimeInterval(-30 * 60)
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-local-overnight-sleep-\(UUID().uuidString).json")
        )
        let overnightSleep = (0..<45).map { index in
            HealthSample(
                id: "overnight-sleep-\(index)",
                type: .sleepAnalysis,
                value: 1,
                unit: "min",
                startDate: sleepStart.addingTimeInterval(TimeInterval(index * 60)),
                endDate: sleepStart.addingTimeInterval(TimeInterval((index + 1) * 60)),
                source: .whoordanEstimate,
                sourceRecordID: "overnight-sleep-\(index)",
                confidence: .low,
                metadata: [
                    "source_label": DataSource.whoordanEstimate.label,
                    "device_only_derivation": "true",
                    "metric_policy": "r10_hr_imu_sleep_stage_estimate",
                    "sleep_category": "3"
                ]
            )
        }
        _ = try await store.saveHealthSamples(
            overnightSleep,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: now
        )
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(environment.todaySnapshot.sleepMinutes, 45)
        XCTAssertEqual(environment.todaySnapshot.sleepSummary?.source, .whoordanEstimate)
        XCTAssertTrue(environment.recentSummaries.contains { summary in
            calendar.isDate(summary.date, inSameDayAs: now) && summary.sleepMinutes == 45
        })
        let persisted = await store.loadTodaySummary()
        XCTAssertEqual(persisted.sleepMinutes, 45)
    }

    func testSavingCallVibrationSettingsUploadsEnabledStateAutomatically() async throws {
        var currentTime = Date(timeIntervalSince1970: 1_779_030_000)
        let accountSync = RecordingAccountSyncService()
        let environment = makeEnvironment(
            minimumPublishInterval: 0.1,
            now: { currentTime },
            authService: RestoringAuthService(),
            accountSyncService: accountSync
        )
        await environment.restore()
        environment.updateConsent { $0.cloudSyncEnabled = true }
        try await waitUntil { environment.consentState.cloudSyncEnabled }
        accountSync.uploadedSnapshots.removeAll()

        currentTime = currentTime.addingTimeInterval(60)
        environment.saveCallVibrationSettings(CallVibrationSettings(enabled: true, patternID: UUID()))

        try await waitUntil {
            accountSync.uploadedSnapshots.contains { snapshot in
                snapshot.callVibrationSettings.enabled
                    && snapshot.callVibrationSettings.patternID == VibrationPattern.standardID
                    && snapshot.callVibrationSettings.lastUpdatedAt == currentTime
            }
        }
        let snapshot = try XCTUnwrap(accountSync.uploadedSnapshots.last)
        XCTAssertTrue(snapshot.callVibrationSettings.enabled)
        XCTAssertEqual(snapshot.callVibrationSettings.patternID, VibrationPattern.standardID)
        XCTAssertEqual(snapshot.callVibrationSettings.lastUpdatedAt, currentTime)
    }

    func testRemoteCloudSettingsDoNotOverrideExplicitLocalCloudOffChoice() async throws {
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-local-cloud-choice-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: false,
            healthDataCloudConsent: false,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: true
        ))
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: true,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: Date(),
            includesProfile: false,
            includesSettings: true
        )
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )

        await environment.restore()

        XCTAssertFalse(environment.consentState.cloudSyncEnabled)
        XCTAssertFalse(environment.consentState.healthDataCloudConsent)
        XCTAssertFalse(environment.consentState.canUploadHealthData)
        XCTAssertTrue(environment.consentState.cloudSyncPromptDismissed)
        XCTAssertFalse(environment.consentState.appleHealthEnabled)
        XCTAssertTrue(accountSync.includeHealthBaselineFetches.isEmpty)
        XCTAssertTrue(accountSync.uploadedSnapshots.isEmpty)
    }

    func testStaleRemoteCloudOffDoesNotDisableEnabledLocalCloudChoice() async throws {
        let store = FileProtectedLocalStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("whoordan-local-cloud-on-\(UUID().uuidString).json")
        )
        await store.saveConsentState(ConsentState(
            cloudSyncEnabled: true,
            healthDataCloudConsent: true,
            appleHealthEnabled: false,
            cloudSyncPromptDismissed: false
        ))
        let accountSync = RecordingAccountSyncService()
        accountSync.remoteSnapshot = AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: false,
                healthDataCloudConsent: false,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            callVibrationSettings: CallVibrationSettings(),
            alarms: [],
            themePreference: AppThemePreference.system.rawValue,
            movementGoal: MovementSummary.empty().goal,
            updatedAt: Date(),
            includesProfile: false,
            includesSettings: true
        )
        let environment = AppEnvironment(
            authService: RestoringAuthService(),
            approvalService: StaticApprovalService(state: .approved()),
            localStore: store,
            healthKitService: StubHealthKitService(),
            healthSyncService: StubHealthSyncService(),
            accountSyncService: accountSync,
            bleService: StubBLEService(),
            hapticService: StubHapticService(),
            notificationPermissionService: NoopNotificationPermissionAuthorizer(),
            scoringService: WhoordanScoringService(),
            wearableStateMinimumPublishInterval: 0.1,
            vibrationRepeatIntervalNanoseconds: 1_000_000_000,
            now: Date.init
        )

        await environment.restore()

        XCTAssertTrue(environment.consentState.cloudSyncEnabled)
        XCTAssertTrue(environment.consentState.canUploadHealthData)
        XCTAssertTrue(environment.consentState.cloudSyncPromptDismissed)
    }

    private func makeEnvironment(
        minimumPublishInterval: TimeInterval,
        now: @escaping () -> Date,
        authService: AuthServicing = StubAuthService(),
        bleService: WearableBLEServicing = StubBLEService(),
        hapticService: VibrationPreviewing = StubHapticService(),
        localStore: LocalStoring? = nil,
        healthSyncService: HealthSyncServicing = StubHealthSyncService(),
        notificationPermissionService: NotificationPermissionAuthorizing = NoopNotificationPermissionAuthorizer(),
        accountSyncService: AccountSyncServicing = NoopAccountSyncService(),
        repeatIntervalNanoseconds: UInt64 = 1_000_000_000,
        alarmScheduler: AlarmNotificationScheduling = NoopAlarmNotificationScheduler(),
        operationalNotificationScheduler: OperationalNotificationScheduling = NoopOperationalNotificationScheduler(),
        backgroundTaskManager: BackgroundTaskManaging = NoopBackgroundTaskManager()
    ) -> AppEnvironment {
        AppEnvironment(
            authService: authService,
            approvalService: StaticApprovalService(state: .approved()),
            localStore: localStore ?? FileProtectedLocalStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("whoordan-env-state-test-\(UUID().uuidString).json")
            ),
            healthKitService: StubHealthKitService(),
            healthSyncService: healthSyncService,
            accountSyncService: accountSyncService,
            bleService: bleService,
            hapticService: hapticService,
            notificationPermissionService: notificationPermissionService,
            alarmScheduler: alarmScheduler,
            operationalNotificationScheduler: operationalNotificationScheduler,
            scoringService: WhoordanScoringService(),
            backgroundTaskManager: backgroundTaskManager,
            wearableStateMinimumPublishInterval: minimumPublishInterval,
            vibrationRepeatIntervalNanoseconds: repeatIntervalNanoseconds,
            now: now
        )
    }

    private func makeCloudSyncRemoteSnapshot(updatedAt: Date) -> AccountSyncSnapshot {
        AccountSyncSnapshot(
            email: "approved@example.invalid",
            bodyProfile: BodyProfile(),
            consentState: ConsentState(
                cloudSyncEnabled: true,
                healthDataCloudConsent: true,
                appleHealthEnabled: false,
                cloudSyncPromptDismissed: true
            ),
            skinTemperatureBaselineProfile: SkinTemperatureBaselineProfile(
                activeBaselineC: 33.7,
                source: .automatic,
                eligibleDayCount: 8,
                requiredDayCount: 5,
                updatedAt: updatedAt,
                automaticBaselineSetAt: updatedAt
            ),
            callVibrationSettings: CallVibrationSettings(
                enabled: true,
                patternID: VibrationPattern.standardID,
                lastUpdatedAt: updatedAt
            ),
            alarms: [
                Alarm(
                    id: UUID(),
                    label: "Cloud alarm",
                    enabled: true,
                    hour: 7,
                    minute: 15,
                    vibrationPatternID: VibrationPattern.standardID
                )
            ],
            themePreference: AppThemePreference.dark.rawValue,
            movementGoal: 12_000,
            updatedAt: updatedAt,
            includesProfile: false,
            includesSettings: true
        )
    }

    private func makeRestoredCloudSummary(at date: Date) -> DailyHealthSummary {
        var restored = DailyHealthSummary.empty
        restored.date = date
        restored.sleepMinutes = 430
        restored.hrv = 58
        restored.movement.steps = 8_765
        restored.source = .cloudImport
        restored.confidence = .high
        return restored
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), file: file, line: line)
    }
}

private final class RecordingBackgroundTaskManager: BackgroundTaskManaging {
    var names: [String] = []

    @MainActor
    func withBackgroundTask(
        named name: String,
        operation: @escaping @MainActor () async -> Void
    ) async {
        names.append(name)
        await operation()
    }
}

private final class RecordingAccountSyncService: AccountSyncServicing {
    var remoteSnapshot: AccountSyncSnapshot?
    var uploadedSnapshots: [AccountSyncSnapshot] = []
    var includeHealthBaselineFetches: [Bool] = []

    func fetchAccountSnapshot(
        session: AuthSession?,
        approval: ApprovalState?,
        includeHealthBaselines: Bool
    ) async -> AccountSyncSnapshot? {
        includeHealthBaselineFetches.append(includeHealthBaselines)
        return remoteSnapshot
    }

    func uploadAccountSnapshot(
        _ snapshot: AccountSyncSnapshot,
        session: AuthSession?,
        approval: ApprovalState?
    ) async -> AccountSyncResult {
        uploadedSnapshots.append(snapshot)
        return AccountSyncResult(status: .synced, message: "Synced in tests.")
    }

    func requestAccountDeletion(session: AuthSession?) async -> AccountSyncResult {
        AccountSyncResult(status: .synced, message: "Deletion requested in tests.")
    }
}

private final class RecordingHealthRestoreSyncService: HealthSyncServicing {
    private(set) var uploadHealthSamplesCount = 0
    private(set) var uploadDailySummaryCount = 0
    private(set) var fetchRecentHealthSamplesCount = 0
    private(set) var fetchRecentDailySummariesCount = 0
    private(set) var dailySummaryLimits: [Int] = []
    private(set) var healthSampleLimits: [Int] = []
    var restoredSummaries: [DailyHealthSummary] = []

    func uploadHealthSamples(
        _ samples: [HealthSample],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        uploadHealthSamplesCount += 1
        return HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Skipped in tests.")
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        uploadDailySummaryCount += 1
        return HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Skipped in tests.")
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        fetchRecentDailySummariesCount += 1
        dailySummaryLimits.append(limit)
        guard consent.canUploadHealthData, !restoredSummaries.isEmpty else {
            return HealthSummaryRestoreResult(status: .nothingToRestore, summaries: [], message: "No summaries.")
        }
        return HealthSummaryRestoreResult(status: .restored, summaries: restoredSummaries, message: "Restored summaries.")
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        fetchRecentHealthSamplesCount += 1
        healthSampleLimits.append(limit)
        return HealthSampleRestoreResult(status: .nothingToRestore, samples: [], message: "No samples.")
    }
}

private final class BlockingSampleRestoreSyncService: HealthSyncServicing {
    private let restoredSummaries: [DailyHealthSummary]
    private let lock = NSLock()
    private var sampleFetchStarted = false
    private var sampleFetchReleased = false
    private var sampleStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var sampleReleaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(restoredSummaries: [DailyHealthSummary]) {
        self.restoredSummaries = restoredSummaries
    }

    func uploadHealthSamples(
        _ samples: [HealthSample],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Skipped in tests.")
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Skipped in tests.")
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        HealthSummaryRestoreResult(status: .restored, summaries: restoredSummaries, message: "Restored summaries.")
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        markSampleFetchStarted()
        await waitForSampleRelease()
        return HealthSampleRestoreResult(status: .nothingToRestore, samples: [], message: "No samples.")
    }

    func waitUntilSampleFetchStarted() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if sampleFetchStarted {
                lock.unlock()
                continuation.resume()
            } else {
                sampleStartWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func releaseSampleFetch() {
        lock.lock()
        sampleFetchReleased = true
        let waiters = sampleReleaseWaiters
        sampleReleaseWaiters.removeAll()
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    private func markSampleFetchStarted() {
        lock.lock()
        sampleFetchStarted = true
        let waiters = sampleStartWaiters
        sampleStartWaiters.removeAll()
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    private func waitForSampleRelease() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if sampleFetchReleased {
                lock.unlock()
                continuation.resume()
            } else {
                sampleReleaseWaiters.append(continuation)
                lock.unlock()
            }
        }
    }
}

private final class StubAuthService: AuthServicing {
    func restoreSession() async throws -> AuthSession? { nil }
    func signIn(email: String, password: String) async throws -> AuthSession { throw AuthError.invalidInput }
    func signUp(email: String, password: String) async throws -> AuthSession { throw AuthError.invalidInput }
    func resetPassword(email: String) async throws {}
    func signOut() async {}
}

private final class RestoringAuthService: AuthServicing {
    let session = AuthSession(
        userID: UUID(),
        email: "approved@example.invalid",
        accessToken: "token",
        refreshToken: nil,
        expiresAt: Date().addingTimeInterval(3_600)
    )

    func restoreSession() async throws -> AuthSession? { session }
    func signIn(email: String, password: String) async throws -> AuthSession { session }
    func signUp(email: String, password: String) async throws -> AuthSession { session }
    func resetPassword(email: String) async throws {}
    func signOut() async {}
}

private final class SequencedStaticApprovalService: ApprovalServicing {
    private var states: [ApprovalState]

    init(states: [ApprovalState]) {
        self.states = states
    }

    func fetchApproval(for userID: UUID) async throws -> ApprovalState {
        if states.count > 1 {
            return states.removeFirst()
        }
        return states.first ?? .approved()
    }
}

private struct StubHealthKitService: HealthKitServicing {
    func isAvailable() -> Bool { false }
    func requestAuthorization() async -> HealthKitAuthorizationResult {
        HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "Unavailable in tests.")
    }
    func requestWriteAuthorization() async -> HealthKitAuthorizationResult {
        HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "Unavailable in tests.")
    }
    func supportedReadTypes() -> [HealthSampleType] { [] }
    func supportedWriteTypes() -> [HealthSampleType] { [] }
    func importSamples(since start: Date, until end: Date) async -> HealthKitImportResult { .unavailable }
    func importIncremental(
        checkpoints: [HealthKitCheckpoint],
        fallbackStart: Date,
        fallbackEnd: Date
    ) async -> HealthKitIncrementalImportResult {
        .unavailable
    }
    func writeSamples(_ samples: [HealthSample]) async -> AppleHealthWriteResult {
        AppleHealthWriteResult(status: .unsupported, writtenCount: 0, unsupportedCount: samples.count, message: "Unavailable in tests.")
    }
    func registerBackgroundDelivery(_ handler: @escaping @Sendable () async -> Void) async -> HealthKitAuthorizationResult {
        HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "Unavailable in tests.")
    }
}

private struct StubHealthSyncService: HealthSyncServicing {
    func uploadHealthSamples(
        _ samples: [HealthSample],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Skipped in tests.")
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Skipped in tests.")
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        HealthSummaryRestoreResult(status: .nothingToRestore, summaries: [], message: "Skipped in tests.")
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        HealthSampleRestoreResult(status: .nothingToRestore, samples: [], message: "Skipped in tests.")
    }
}

private final class StubBLEService: WearableBLEServicing {
    var currentDeviceState: WearableDeviceState
    private(set) var primeBluetoothPermissionCount = 0
    private(set) var startAutoConnectCount = 0
    private(set) var startScanningCount = 0
    private(set) var requestBluetoothAccessCount = 0
    private(set) var lastSyntheticCalibrationContext: WearableSyntheticCalibrationContext?

    init(state: WearableDeviceState = WearableDeviceState()) {
        self.currentDeviceState = state
    }

    func primeBluetoothPermission() { primeBluetoothPermissionCount += 1 }
    func startAutoConnect() { startAutoConnectCount += 1 }
    func startScanning() { startScanningCount += 1 }
    func requestBluetoothAccess() { requestBluetoothAccessCount += 1 }
    func connect(to candidate: WearableDeviceCandidate) {}
    func stopAll() {}
    func startRawCapture(scenario: WearableCaptureScenario) {}
    func stopRawCapture() {}
    func finishRawCapture(recordingName: String) -> WearableRawPayloadCaptureSave? { nil }
    func updateRawCaptureScenario(_ scenario: WearableCaptureScenario) {}
    func exportRawCaptureArchive() throws -> URL { FileManager.default.temporaryDirectory }
    func updateSyntheticCalibrationContext(_ context: WearableSyntheticCalibrationContext) {
        lastSyntheticCalibrationContext = context
    }
    func restoreBLECheckpoints(_ checkpoints: [BLECheckpoint]) {}
    func writeCommand(_ data: Data, requiresResponse: Bool) async throws {}
}

private struct StubHapticService: VibrationPreviewing {
    func preview(_ pattern: VibrationPattern, approval: ApprovalState?, device: WearableDeviceState) async -> VibrationPreviewResult {
        VibrationPreviewResult(status: .notConnected)
    }
    func cancel() async {}
}

private final class RecordingNotificationPermissionAuthorizer: NotificationPermissionAuthorizing {
    private let requestResult: NotificationPermissionResult
    private let currentResult: NotificationPermissionResult
    private(set) var requestCount = 0
    private(set) var currentCount = 0

    init(
        requestResult: NotificationPermissionResult,
        currentResult: NotificationPermissionResult = .notRequested
    ) {
        self.requestResult = requestResult
        self.currentResult = currentResult
    }

    func currentAuthorization() async -> NotificationPermissionResult {
        currentCount += 1
        return currentResult
    }

    func requestAuthorization() async -> NotificationPermissionResult {
        requestCount += 1
        return requestResult
    }
}

private actor BlockingConsentLoadStore: LocalStoring {
    private let base: FileProtectedLocalStore
    private let blocksConsentLoad: Bool
    private let dropsCallVibrationSaves: Bool
    private var didStartConsentLoad = false
    private var didReleaseConsentLoad = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(
        base: FileProtectedLocalStore,
        blocksConsentLoad: Bool = true,
        dropsCallVibrationSaves: Bool = false
    ) {
        self.base = base
        self.blocksConsentLoad = blocksConsentLoad
        self.dropsCallVibrationSaves = dropsCallVibrationSaves
    }

    func waitUntilConsentLoadStarted() async {
        if didStartConsentLoad { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func releaseConsentLoad() {
        didReleaseConsentLoad = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func loadConsentState() async -> ConsentState {
        didStartConsentLoad = true
        startContinuation?.resume()
        startContinuation = nil
        if blocksConsentLoad, !didReleaseConsentLoad {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        return await base.loadConsentState()
    }

    func saveConsentState(_ state: ConsentState) async {
        await base.saveConsentState(state)
    }

    func loadTodaySummary() async -> DailyHealthSummary {
        await base.loadTodaySummary()
    }

    func saveTodaySummary(_ summary: DailyHealthSummary) async {
        await base.saveTodaySummary(summary)
    }

    func loadBodyProfile() async -> BodyProfile {
        await base.loadBodyProfile()
    }

    func saveBodyProfile(_ profile: BodyProfile, updatedAt: Date) async throws {
        try await base.saveBodyProfile(profile, updatedAt: updatedAt)
    }

    func loadSkinTemperatureBaselineProfile() async -> SkinTemperatureBaselineProfile {
        await base.loadSkinTemperatureBaselineProfile()
    }

    func saveSkinTemperatureBaselineProfile(_ profile: SkinTemperatureBaselineProfile) async throws {
        try await base.saveSkinTemperatureBaselineProfile(profile)
    }

    func saveTemporarySkinTemperatureBaselineC(_ value: Double?, updatedAt: Date) async throws {
        try await base.saveTemporarySkinTemperatureBaselineC(value, updatedAt: updatedAt)
    }

    func loadCachedApprovalState() async -> ApprovalState? {
        await base.loadCachedApprovalState()
    }

    func saveCachedApprovalState(_ state: ApprovalState?) async {
        await base.saveCachedApprovalState(state)
    }

    func clearUnlockedCache() async {
        await base.clearUnlockedCache()
    }

    func exportLocalUserData(createdAt: Date) async throws -> URL {
        try await base.exportLocalUserData(createdAt: createdAt)
    }

    @discardableResult
    func saveHealthSamples(
        _ samples: [HealthSample],
        queueForSupabase: Bool,
        syncUserID: UUID?,
        queueForAppleHealth: Bool,
        importedAt: Date
    ) async throws -> LocalPersistenceResult {
        try await base.saveHealthSamples(
            samples,
            queueForSupabase: queueForSupabase,
            syncUserID: syncUserID,
            queueForAppleHealth: queueForAppleHealth,
            importedAt: importedAt
        )
    }

    func loadHealthSamples(on day: Date, calendar: Calendar) async -> [HealthSample] {
        await base.loadHealthSamples(on: day, calendar: calendar)
    }

    func loadHealthSamples(
        type: HealthSampleType?,
        source: DataSource?,
        start: Date?,
        end: Date?,
        limit: Int?
    ) async -> [HealthSample] {
        await base.loadHealthSamples(type: type, source: source, start: start, end: end, limit: limit)
    }

    func pendingSupabaseUploads(limit: Int, now: Date) async -> [QueuedHealthSampleUpload] {
        await base.pendingSupabaseUploads(limit: limit, now: now)
    }

    func markSupabaseUploadsUploaded(dedupeKeys: [String], syncedAt: Date) async throws {
        try await base.markSupabaseUploadsUploaded(dedupeKeys: dedupeKeys, syncedAt: syncedAt)
    }

    func markSupabaseUploadsFailed(dedupeKeys: [String], error: String, now: Date) async throws {
        try await base.markSupabaseUploadsFailed(dedupeKeys: dedupeKeys, error: error, now: now)
    }

    func repairSupabaseQueue(now: Date, userID: UUID?) async throws -> Int {
        try await base.repairSupabaseQueue(now: now, userID: userID)
    }

    func repairAppleHealthWriteQueue(now: Date) async throws -> Int {
        try await base.repairAppleHealthWriteQueue(now: now)
    }

    func pendingAppleHealthWrites(limit: Int) async -> [AppleHealthWriteQueueItem] {
        await base.pendingAppleHealthWrites(limit: limit)
    }

    func markAppleHealthWritesWritten(dedupeKeys: [String], writtenAt: Date) async throws {
        try await base.markAppleHealthWritesWritten(dedupeKeys: dedupeKeys, writtenAt: writtenAt)
    }

    func markAppleHealthWritesFailed(dedupeKeys: [String], error: String, now: Date) async throws {
        try await base.markAppleHealthWritesFailed(dedupeKeys: dedupeKeys, error: error, now: now)
    }

    func markAppleHealthWritesNotAuthorized(dedupeKeys: [String], error: String, now: Date) async throws {
        try await base.markAppleHealthWritesNotAuthorized(dedupeKeys: dedupeKeys, error: error, now: now)
    }

    func loadHealthKitCheckpoints() async -> [HealthKitCheckpoint] {
        await base.loadHealthKitCheckpoints()
    }

    func saveHealthKitCheckpoints(_ checkpoints: [HealthKitCheckpoint]) async throws {
        try await base.saveHealthKitCheckpoints(checkpoints)
    }

    func loadBLECheckpoints() async -> [BLECheckpoint] {
        await base.loadBLECheckpoints()
    }

    func loadBLECheckpoint(deviceID: String) async -> BLECheckpoint? {
        await base.loadBLECheckpoint(deviceID: deviceID)
    }

    func saveBLECheckpoint(_ checkpoint: BLECheckpoint) async throws {
        try await base.saveBLECheckpoint(checkpoint)
    }

    func saveWearableControlPlaneEvent(_ event: WearableControlPlaneEvent) async throws {
        try await base.saveWearableControlPlaneEvent(event)
    }

    func loadWearableControlPlaneEvents(limit: Int) async -> [WearableControlPlaneEvent] {
        await base.loadWearableControlPlaneEvents(limit: limit)
    }

    func saveSleepSession(_ session: SleepSession) async throws {
        try await base.saveSleepSession(session)
    }

    func loadSleepSessions(on day: Date, calendar: Calendar) async -> [SleepSession] {
        await base.loadSleepSessions(on: day, calendar: calendar)
    }

    func saveWorkout(_ workout: Workout) async throws {
        try await base.saveWorkout(workout)
    }

    func loadWorkouts(on day: Date, calendar: Calendar) async -> [Workout] {
        await base.loadWorkouts(on: day, calendar: calendar)
    }

    func saveJournalEntry(_ entry: JournalEntry) async throws {
        try await base.saveJournalEntry(entry)
    }

    func loadJournalEntries(on day: Date, calendar: Calendar) async -> [JournalEntry] {
        await base.loadJournalEntries(on: day, calendar: calendar)
    }

    func loadVibrationPatterns() async -> [VibrationPattern] {
        await base.loadVibrationPatterns()
    }

    func loadCallVibrationSettings() async -> CallVibrationSettings {
        await base.loadCallVibrationSettings()
    }

    func saveCallVibrationSettings(_ settings: CallVibrationSettings) async throws {
        if dropsCallVibrationSaves {
            return
        }
        try await base.saveCallVibrationSettings(settings)
    }

    func saveAlarm(_ alarm: Alarm) async throws {
        try await base.saveAlarm(alarm)
    }

    func loadAlarms() async -> [Alarm] {
        await base.loadAlarms()
    }

    func replaceAlarms(_ alarms: [Alarm]) async throws {
        try await base.replaceAlarms(alarms)
    }

    func deleteAlarm(id: UUID) async throws {
        try await base.deleteAlarm(id: id)
    }
}

private final class RecordingHapticService: VibrationPreviewing {
    private(set) var previewedPatternIDs: [UUID] = []
    private(set) var cancelCount = 0

    func preview(_ pattern: VibrationPattern, approval: ApprovalState?, device: WearableDeviceState) async -> VibrationPreviewResult {
        previewedPatternIDs.append(pattern.id)
        return VibrationPreviewResult(status: .started, message: "Started.")
    }

    func cancel() async {
        cancelCount += 1
    }
}

private final class RecordingAlarmNotificationScheduler: AlarmNotificationScheduling {
    private(set) var scheduledAlarmIDs: [UUID] = []
    private(set) var scheduledAlarms: [Alarm] = []
    private(set) var canceledAlarmIDs: [UUID] = []

    func scheduleLocalNotification(for alarm: Alarm) async -> AlarmSchedulingResult {
        scheduledAlarmIDs.append(alarm.id)
        scheduledAlarms.append(alarm)
        return AlarmSchedulingResult(status: .scheduled, message: "Scheduled in tests.", scheduledAt: alarm.nextTriggerAt)
    }

    func cancelLocalNotification(alarmID: UUID) async {
        canceledAlarmIDs.append(alarmID)
    }
}

private final class RecordingOperationalNotificationScheduler: OperationalNotificationScheduling {
    private(set) var scheduledRequests: [OperationalNotificationRequest] = []
    private(set) var canceledKinds: [OperationalNotificationKind] = []

    var scheduledKinds: [OperationalNotificationKind] {
        scheduledRequests.map(\.kind)
    }

    func schedule(_ request: OperationalNotificationRequest) async -> OperationalNotificationResult {
        scheduledRequests.append(request)
        return OperationalNotificationResult(status: .scheduled, message: "Scheduled in tests.")
    }

    func cancel(kind: OperationalNotificationKind) async {
        canceledKinds.append(kind)
    }
}
