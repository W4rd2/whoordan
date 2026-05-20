import XCTest
@testable import Whoordan

final class VibrationTests: XCTestCase {
    func testDefaultCallVibrationSettingsAreNotFreshRemoteWrites() {
        XCTAssertFalse(CallVibrationSettings().enabled)
        XCTAssertEqual(CallVibrationSettings().lastUpdatedAt, .distantPast)
    }

    func testPreviewRequiresApproval() async {
        let sink = RecordingCommandSink()
        let service = VibrationPreviewService(commandSink: sink)
        let result = await service.preview(.builtIns[0], approval: .pending(), device: WearableDeviceState(connection: .realtime))
        XCTAssertEqual(result.status, .approvalRequired)
        XCTAssertTrue(sink.commands.isEmpty)
    }

    func testLegacyUnsafePatternStillUsesStandardCommand() async {
        let sink = RecordingCommandSink()
        let service = VibrationPreviewService(commandSink: sink)
        let pattern = VibrationPattern(name: "Unsafe", segments: [VibrationSegment(durationMs: 20_000, intensity: 1)], repeats: 2, builtInPatternID: 2)
        let result = await service.preview(pattern, approval: .approved(), device: WearableDeviceState(connection: .realtime))
        XCTAssertEqual(result.status, .started)
        XCTAssertEqual(result.commandsSent, ["0x4F", "0x13"])
        XCTAssertEqual(sink.commands.count, 2)
    }

    func testBuiltInPreviewSendsHarvardAndMaverickCommands() async {
        let sink = RecordingCommandSink()
        let service = VibrationPreviewService(commandSink: sink)
        let result = await service.preview(.builtIns[0], approval: .approved(), device: WearableDeviceState(connection: .realtime))
        XCTAssertEqual(result.status, .started)
        XCTAssertEqual(result.commandsSent, ["0x4F", "0x13"])
        XCTAssertEqual(sink.commands.count, 2)
        let harvard = try! WearableProtocol.decodeFrame(sink.commands[0])
        let maverick = try! WearableProtocol.decodeFrame(sink.commands[1])
        XCTAssertEqual(Array(harvard.prefix(8)), [0x23, 0xA0, 0x4F, 0x02, 0x01, 0x00, 0x00, 0x00])
        XCTAssertEqual(Array(maverick.prefix(15)), [0x23, 0xA1, 0x13, 0x01, 0x2F, 0x98, 0, 0, 0, 0, 0, 0, 0, 0, 0x01])
    }

    func testPreviewAlwaysSendsStandardCommandForLegacyPatternInput() async {
        let sink = RecordingCommandSink()
        let service = VibrationPreviewService(commandSink: sink)
        let pattern = VibrationPattern(
            name: "Legacy Imported Pattern",
            segments: [
                VibrationSegment(durationMs: 120, intensity: 0.2),
                VibrationSegment(kind: .off, durationMs: 80, intensity: 0),
                VibrationSegment(durationMs: 900, intensity: 1)
            ],
            repeats: 4,
            builtInPatternID: nil
        )
        let result = await service.preview(pattern, approval: .approved(), device: WearableDeviceState(connection: .realtime))
        XCTAssertEqual(result.status, .started)
        XCTAssertEqual(result.commandsSent, ["0x4F", "0x13"])
        XCTAssertEqual(sink.commands.count, 2)
        let harvard = try! WearableProtocol.decodeFrame(sink.commands[0])
        XCTAssertEqual(Array(harvard.prefix(8)), [0x23, 0xA0, 0x4F, VibrationPattern.standardBuiltInPatternID, 0x01, 0x00, 0x00, 0x00])
    }

    func testCallVibrationRouterUsesStandardPatternForIncomingCellularCall() {
        let result = CallVibrationRouter.routeIncomingCellularCall(
            settings: CallVibrationSettings(enabled: true, patternID: UUID()),
            patterns: VibrationPattern.builtIns,
            approval: .approved(),
            device: WearableDeviceState(connection: .realtime)
        )

        XCTAssertEqual(result.pattern?.id, VibrationPattern.standardID)
        XCTAssertEqual(result.reason, .incomingCellularCall)
    }

    func testCallVibrationRouterRequiresEnabledApprovalAndConnection() {
        let disabled = CallVibrationRouter.routeIncomingCellularCall(
            settings: CallVibrationSettings(enabled: false),
            patterns: VibrationPattern.builtIns,
            approval: .approved(),
            device: WearableDeviceState(connection: .realtime)
        )
        let unapproved = CallVibrationRouter.routeIncomingCellularCall(
            settings: CallVibrationSettings(enabled: true),
            patterns: VibrationPattern.builtIns,
            approval: .pending(),
            device: WearableDeviceState(connection: .realtime)
        )
        let disconnected = CallVibrationRouter.routeIncomingCellularCall(
            settings: CallVibrationSettings(enabled: true),
            patterns: VibrationPattern.builtIns,
            approval: .approved(),
            device: WearableDeviceState(connection: .disconnected)
        )

        XCTAssertEqual(disabled.reason, .disabled)
        XCTAssertEqual(unapproved.reason, .approvalRequired)
        XCTAssertEqual(disconnected.reason, .deviceDisconnected)
    }

    func testDoubleTapDeclinesOnlyWhoordanOwnedCallWhenControllerExists() async {
        let controller = RecordingCallController()
        let callID = UUID()
        let settings = CallVibrationSettings(declineOnDoubleTapEnabled: true, supportsDecline: true, platformStatus: .appOwnedVoIPSupported)
        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: .declineCallWhereSupported,
            callSettings: settings,
            activeCall: ActiveCallContext(id: callID, kind: .whoordanOwnedVoIP),
            approval: .approved(),
            callController: controller
        )
        XCTAssertEqual(result.status, .declinedWhoordanCall)
        XCTAssertEqual(controller.declinedCallIDs, [callID])
    }

    func testDoubleTapDoesNotAttemptNormalCellularDecline() async {
        let controller = RecordingCallController()
        let settings = CallVibrationSettings(declineOnDoubleTapEnabled: true, supportsDecline: true, platformStatus: .normalCellularPlatformBlocked)
        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: .declineCallWhereSupported,
            callSettings: settings,
            activeCall: ActiveCallContext(kind: .normalCellular),
            approval: .approved(),
            callController: controller
        )
        XCTAssertEqual(result.status, .cellularDeclinePlatformBlocked)
        XCTAssertTrue(controller.declinedCallIDs.isEmpty)
    }

    func testDoubleTapSilencesActiveNormalCellularCallVibrationWithoutDeclining() async {
        let controller = RecordingCallController()
        let settings = CallVibrationSettings(enabled: true, declineOnDoubleTapEnabled: true, supportsDecline: false, platformStatus: .normalCellularPlatformBlocked)
        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: .declineCallWhereSupported,
            callSettings: settings,
            activeCall: ActiveCallContext(kind: .normalCellular),
            approval: .approved(),
            callController: controller,
            isCellularCallVibrationActive: true
        )

        XCTAssertEqual(result.status, .silencedCallVibration)
        XCTAssertTrue(controller.declinedCallIDs.isEmpty)
    }

    func testAlarmNextTriggerUsesNextOccurrenceAndRepeatDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 8, minute: 0))!
        let oneTime = Alarm(hour: 7, minute: 30, timezone: "UTC")
        let mondayRepeating = Alarm(hour: 6, minute: 45, timezone: "UTC", repeatDays: [2])

        let oneTimeNext = AlarmScheduler.nextTrigger(for: oneTime, after: now, calendar: calendar)
        let repeatingNext = AlarmScheduler.nextTrigger(for: mondayRepeating, after: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.day, from: oneTimeNext!), 13)
        XCTAssertEqual(calendar.component(.hour, from: oneTimeNext!), 7)
        XCTAssertEqual(calendar.component(.weekday, from: repeatingNext!), 2)
        XCTAssertEqual(calendar.component(.hour, from: repeatingNext!), 6)
    }

    func testAlarmSnoozeRespectsMaxSnoozesAndDismissesAfterLimit() {
        let alarm = Alarm(hour: 7, minute: 0, snoozeEnabled: true, snoozeMinutes: 5, maxSnoozes: 1)
        let now = Date(timeIntervalSince1970: 10_000)

        let snoozed = AlarmScheduler.snooze(alarm, now: now)
        let afterLimit = AlarmScheduler.snooze(snoozed, now: now.addingTimeInterval(300))

        XCTAssertEqual(snoozed.deliveryStatus, .snoozed)
        XCTAssertEqual(snoozed.currentSnoozeCount, 1)
        XCTAssertEqual(snoozed.nextTriggerAt, now.addingTimeInterval(300))
        XCTAssertEqual(afterLimit.deliveryStatus, .dismissed)
        XCTAssertFalse(afterLimit.enabled)
    }

    func testSettingsSyncPolicyQueuesAccountSettingsOnlyAfterCloudOptIn() {
        let userID = UUID()
        XCTAssertEqual(SettingsSyncPolicy.status(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true), userID: userID), .pending)
        XCTAssertEqual(SettingsSyncPolicy.status(
            approval: .offlineApproved(lastVerifiedAt: Date()),
            consent: ConsentState(cloudSyncEnabled: true),
            userID: userID
        ), .blocked)
        XCTAssertEqual(SettingsSyncPolicy.status(approval: .pending(), consent: ConsentState(cloudSyncEnabled: true), userID: userID), .blocked)
        XCTAssertEqual(SettingsSyncPolicy.status(approval: .approved(), consent: ConsentState(localModeEnabled: true, cloudSyncEnabled: true), userID: userID), .pending)
        XCTAssertEqual(SettingsSyncPolicy.status(
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: false),
            userID: userID
        ), .blocked)
        XCTAssertEqual(SettingsSyncPolicy.status(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true), userID: nil), .blocked)
    }

    @MainActor
    func testDoubleTapActiveCallWinsOverAlarm() async {
        let callController = RecordingCallController()
        let alarmController = RecordingAlarmController()
        let callID = UUID()
        let alarm = Alarm(hour: 7, minute: 0)
        let settings = CallVibrationSettings(declineOnDoubleTapEnabled: true, supportsDecline: true, platformStatus: .appOwnedVoIPSupported)

        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: .snoozeAlarmWhereSupported,
            callSettings: settings,
            activeCall: ActiveCallContext(id: callID, kind: .whoordanOwnedVoIP),
            approval: .approved(),
            callController: callController,
            activeAlarm: alarm,
            alarmController: alarmController
        )

        XCTAssertEqual(result.status, .declinedWhoordanCall)
        XCTAssertEqual(callController.declinedCallIDs, [callID])
        XCTAssertTrue(alarmController.snoozedAlarmIDs.isEmpty)
    }

    @MainActor
    func testDoubleTapSnoozesActiveAlarmWhenNoCall() async {
        let alarmController = RecordingAlarmController()
        let alarm = Alarm(hour: 7, minute: 0)

        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: .snoozeAlarmWhereSupported,
            callSettings: CallVibrationSettings(),
            activeCall: nil,
            approval: .approved(),
            callController: nil,
            activeAlarm: alarm,
            alarmController: alarmController
        )

        XCTAssertEqual(result.status, .snoozedAlarm)
        XCTAssertEqual(alarmController.snoozedAlarmIDs, [alarm.id])
    }

    @MainActor
    func testDoubleTapDismissesActiveAlarmWhenConfigured() async {
        let alarmController = RecordingAlarmController()
        let alarm = Alarm(hour: 7, minute: 0)

        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: .dismissAlarmWhereSupported,
            callSettings: CallVibrationSettings(),
            activeCall: nil,
            approval: .approved(),
            callController: nil,
            activeAlarm: alarm,
            alarmController: alarmController
        )

        XCTAssertEqual(result.status, .dismissedAlarm)
        XCTAssertEqual(alarmController.dismissedAlarmIDs, [alarm.id])
    }

    func testDoubleTapAlarmActionsDoNothingWithoutActiveAlarmAndApprovalBlocks() async {
        let noAlarm = await DoubleTapActionRouter.handleDoubleTap(
            action: .snoozeAlarmWhereSupported,
            callSettings: CallVibrationSettings(),
            activeCall: nil,
            approval: .approved(),
            callController: nil
        )
        let blocked = await DoubleTapActionRouter.handleDoubleTap(
            action: .snoozeAlarmWhereSupported,
            callSettings: CallVibrationSettings(),
            activeCall: nil,
            approval: .pending(),
            callController: nil
        )

        XCTAssertEqual(noAlarm.status, .noActiveAlarm)
        XCTAssertEqual(blocked.status, .approvalRequired)
    }
}

private final class RecordingCommandSink: WearableCommandSink {
    var commands: [Data] = []

    func writeCommand(_ data: Data, requiresResponse: Bool) async throws {
        XCTAssertTrue(requiresResponse)
        commands.append(data)
    }
}

private final class RecordingCallController: WhoordanCallControlling {
    var declinedCallIDs: [UUID] = []

    func declineWhoordanCall(id: UUID) async -> Bool {
        declinedCallIDs.append(id)
        return true
    }
}

@MainActor
private final class RecordingAlarmController: AlarmControlling {
    var snoozedAlarmIDs: [UUID] = []
    var dismissedAlarmIDs: [UUID] = []

    func snoozeAlarm(id: UUID) async -> Bool {
        snoozedAlarmIDs.append(id)
        return true
    }

    func dismissAlarm(id: UUID) async -> Bool {
        dismissedAlarmIDs.append(id)
        return true
    }
}
