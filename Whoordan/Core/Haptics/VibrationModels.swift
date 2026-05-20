import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

enum VibrationPreviewStatus: String, Codable, Equatable {
    case approvalRequired
    case deviceDisconnected
    case notConnected
    case unsupported
    case unsafe
    case sending
    case started
    case fired
    case failed
    case terminated
    case unsafePattern
}

enum VibrationPlaybackErrorCategory: String, Codable, Equatable {
    case approval
    case connection
    case unsupported
    case unsafe
    case transport
    case platformBlocked
}

enum VibrationSegmentKind: String, Codable, Equatable, CaseIterable {
    case on
    case off
}

struct VibrationSegment: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: VibrationSegmentKind
    let durationMs: Int
    let intensity: Double

    init(id: UUID = UUID(), kind: VibrationSegmentKind = .on, durationMs: Int, intensity: Double) {
        self.id = id
        self.kind = kind
        self.durationMs = durationMs
        self.intensity = intensity
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case durationMs
        case intensity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(VibrationSegmentKind.self, forKey: .kind) ?? .on
        durationMs = try container.decode(Int.self, forKey: .durationMs)
        intensity = try container.decode(Double.self, forKey: .intensity)
    }
}

enum VibrationSafetyStatus: String, Codable, Equatable {
    case safe
    case unsafe
}

struct VibrationPattern: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let segments: [VibrationSegment]
    let repeats: Int
    let builtInPatternID: UInt8?
    let createdAt: Date
    let updatedAt: Date

    static let softTapID = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
    static let standardID = softTapID
    static let standardBuiltInPatternID: UInt8 = 2
    static let verifiedFallbackBuiltInPatternID = standardBuiltInPatternID

    static let builtIns: [VibrationPattern] = {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            VibrationPattern(
                id: standardID,
                name: "Standard Vibration",
                segments: [VibrationSegment(durationMs: 250, intensity: 0.4)],
                repeats: 1,
                builtInPatternID: standardBuiltInPatternID,
                createdAt: created,
                updatedAt: created
            )
        ]
    }()

    static var standard: VibrationPattern { builtIns[0] }

    static func standardPattern(from patterns: [VibrationPattern]) -> VibrationPattern {
        patterns.first(where: { $0.id == standardID }) ?? standard
    }

    init(
        id: UUID = UUID(),
        name: String,
        segments: [VibrationSegment],
        repeats: Int,
        builtInPatternID: UInt8?,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.segments = segments
        self.repeats = repeats
        self.builtInPatternID = builtInPatternID ?? Self.standardBuiltInPatternID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case segments
        case repeats
        case builtInPatternID
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        segments = try container.decode([VibrationSegment].self, forKey: .segments)
        repeats = try container.decode(Int.self, forKey: .repeats)
        builtInPatternID = try container.decodeIfPresent(UInt8.self, forKey: .builtInPatternID) ?? Self.standardBuiltInPatternID
        let now = Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    var totalDurationMs: Int {
        segments.reduce(0) { $0 + $1.durationMs } * max(repeats, 1)
    }

    var repeatCount: Int { repeats }

    var safetyStatus: VibrationSafetyStatus {
        isSafe ? .safe : .unsafe
    }

    var isSafe: Bool {
        repeats >= 0 && repeats <= 5
            && totalDurationMs <= 10_000
            && !segments.isEmpty
            && segments.allSatisfy { segment in
                let durationIsSafe: Bool
                switch segment.kind {
                case .on:
                    durationIsSafe = segment.durationMs >= 80 && segment.durationMs <= 5_000
                case .off:
                    durationIsSafe = segment.durationMs >= 50 && segment.durationMs <= 5_000
                }
                return durationIsSafe && segment.intensity >= 0 && segment.intensity <= 1
            }
    }

    func renamed(_ name: String) -> VibrationPattern {
        VibrationPattern(
            id: id,
            name: name,
            segments: segments,
            repeats: repeats,
            builtInPatternID: builtInPatternID,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

enum CallPlatformStatus: String, Codable, Equatable {
    case notImplemented
    case appOwnedVoIPSupported
    case normalCellularPlatformBlocked
    case requiresEntitlement

    var label: String {
        switch self {
        case .notImplemented:
            return "Whoordan-owned calling is not implemented."
        case .appOwnedVoIPSupported:
            return "Supported for Whoordan-owned VoIP calls."
        case .normalCellularPlatformBlocked:
            return "Normal cellular call control is platform-blocked for third-party apps."
        case .requiresEntitlement:
            return "Requires an Apple entitlement not present in this build."
        }
    }
}

enum CallVibrationRoutingReason: String, Codable, Equatable {
    case disabled
    case incomingCellularCall
    case approvalRequired
    case deviceDisconnected
    case patternUnavailable
    case platformBlocked
}

struct CallVibrationRoutingResult: Codable, Equatable {
    var pattern: VibrationPattern?
    var reason: CallVibrationRoutingReason
    var safeMessage: String
}

struct CallVibrationSettings: Codable, Equatable {
    var enabled: Bool
    var patternID: UUID
    var declineOnDoubleTapEnabled: Bool
    var supportsDecline: Bool
    var platformStatus: CallPlatformStatus
    var lastUpdatedAt: Date

    init(
        enabled: Bool = false,
        patternID: UUID = VibrationPattern.standardID,
        declineOnDoubleTapEnabled: Bool = false,
        supportsDecline: Bool = false,
        platformStatus: CallPlatformStatus = .normalCellularPlatformBlocked,
        lastUpdatedAt: Date = .distantPast
    ) {
        self.enabled = enabled
        self.patternID = patternID
        self.declineOnDoubleTapEnabled = declineOnDoubleTapEnabled
        self.supportsDecline = supportsDecline
        self.platformStatus = platformStatus
        self.lastUpdatedAt = lastUpdatedAt
    }
}

enum CallVibrationRouter {
    static func routeIncomingCellularCall(
        settings: CallVibrationSettings,
        patterns: [VibrationPattern],
        approval: ApprovalState?,
        device: WearableDeviceState
    ) -> CallVibrationRoutingResult {
        guard approval?.allowsProtectedLocalAccess == true else {
            return CallVibrationRoutingResult(pattern: nil, reason: .approvalRequired, safeMessage: "Approval is required before wearable call vibration.")
        }
        guard device.connection == .realtime || device.connection == .historicalSync else {
            return CallVibrationRoutingResult(pattern: nil, reason: .deviceDisconnected, safeMessage: "Connect a supported wearable before call vibration.")
        }
        guard settings.enabled else {
            return CallVibrationRoutingResult(pattern: nil, reason: .disabled, safeMessage: "Call vibration is disabled.")
        }
        guard settings.platformStatus == .normalCellularPlatformBlocked else {
            return CallVibrationRoutingResult(pattern: nil, reason: .platformBlocked, safeMessage: settings.platformStatus.label)
        }
        let pattern = VibrationPattern.standardPattern(from: patterns)
        return CallVibrationRoutingResult(pattern: pattern, reason: .incomingCellularCall, safeMessage: "Incoming cellular call vibration selected.")
    }
}

enum DoubleTapAction: String, Codable, Equatable, CaseIterable {
    case none
    case previewHaptic
    case declineCallWhereSupported
    case snoozeAlarmWhereSupported
    case dismissAlarmWhereSupported
    case debugAction
}

enum AlarmDeliveryStatus: String, Codable, Equatable {
    case scheduled
    case triggered
    case deliveredToWearable
    case wearableDisconnected
    case unsupported
    case failed
    case snoozed
    case dismissed
}

struct Alarm: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String
    var enabled: Bool
    var hour: Int
    var minute: Int
    var timezone: String
    var repeatDays: [Int]
    var vibrationPatternID: UUID
    var snoozeEnabled: Bool
    var snoozeMinutes: Int
    var maxSnoozes: Int
    var currentSnoozeCount: Int
    var lastTriggeredAt: Date?
    var nextTriggerAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: LocalSyncStatus
    var deliveryStatus: AlarmDeliveryStatus

    init(
        id: UUID = UUID(),
        label: String = "Alarm",
        enabled: Bool = true,
        hour: Int,
        minute: Int,
        timezone: String = TimeZone.current.identifier,
        repeatDays: [Int] = [],
        vibrationPatternID: UUID = VibrationPattern.standardID,
        snoozeEnabled: Bool = true,
        snoozeMinutes: Int = 9,
        maxSnoozes: Int = 3,
        currentSnoozeCount: Int = 0,
        lastTriggeredAt: Date? = nil,
        nextTriggerAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: LocalSyncStatus = .notQueued,
        deliveryStatus: AlarmDeliveryStatus = .scheduled
    ) {
        self.id = id
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alarm" : label
        self.enabled = enabled
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.timezone = TimeZone(identifier: timezone)?.identifier ?? TimeZone.current.identifier
        self.repeatDays = Array(Set(repeatDays.filter { (1...7).contains($0) })).sorted()
        self.vibrationPatternID = vibrationPatternID
        self.snoozeEnabled = snoozeEnabled
        self.snoozeMinutes = min(max(snoozeMinutes, 1), 60)
        self.maxSnoozes = min(max(maxSnoozes, 0), 10)
        self.currentSnoozeCount = min(max(currentSnoozeCount, 0), self.maxSnoozes)
        self.lastTriggeredAt = lastTriggeredAt
        self.nextTriggerAt = nextTriggerAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.deliveryStatus = deliveryStatus
    }

    var displayTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func withNextTrigger(after date: Date = Date(), calendar: Calendar = .current) -> Alarm {
        var updated = self
        updated.nextTriggerAt = AlarmScheduler.nextTrigger(for: updated, after: date, calendar: calendar)
        updated.updatedAt = Date()
        return updated
    }
}

enum SettingsSyncPolicy {
    static func status(approval: ApprovalState?, consent: ConsentState, userID: UUID?) -> LocalSyncStatus {
        PrivacyAccessGuard().canQueueSettingsData(approval: approval, consent: consent, userID: userID) ? .pending : .blocked
    }
}

enum AlarmScheduler {
    static func nextTrigger(for alarm: Alarm, after now: Date = Date(), calendar baseCalendar: Calendar = .current) -> Date? {
        guard alarm.enabled else { return nil }
        var calendar = baseCalendar
        if let timezone = TimeZone(identifier: alarm.timezone) {
            calendar.timeZone = timezone
        }

        let repeatDays = Set(alarm.repeatDays)
        let startOfToday = calendar.startOfDay(for: now)
        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if !repeatDays.isEmpty && !repeatDays.contains(weekday) {
                continue
            }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            guard let candidate = calendar.date(from: components), candidate > now else {
                continue
            }
            return candidate
        }
        return nil
    }

    static func trigger(_ alarm: Alarm, now: Date = Date()) -> Alarm {
        var updated = alarm
        updated.lastTriggeredAt = now
        updated.nextTriggerAt = nil
        updated.currentSnoozeCount = 0
        updated.deliveryStatus = .triggered
        updated.updatedAt = now
        return updated
    }

    static func markDelivery(_ alarm: Alarm, status: AlarmDeliveryStatus, now: Date = Date()) -> Alarm {
        var updated = alarm
        updated.deliveryStatus = status
        updated.updatedAt = now
        return updated
    }

    static func snooze(_ alarm: Alarm, now: Date = Date()) -> Alarm {
        guard alarm.snoozeEnabled, alarm.currentSnoozeCount < alarm.maxSnoozes else {
            return dismiss(alarm, now: now)
        }
        var updated = alarm
        updated.currentSnoozeCount += 1
        updated.nextTriggerAt = now.addingTimeInterval(TimeInterval(updated.snoozeMinutes * 60))
        updated.deliveryStatus = .snoozed
        updated.updatedAt = now
        return updated
    }

    static func dismiss(_ alarm: Alarm, now: Date = Date(), calendar: Calendar = .current) -> Alarm {
        var updated = alarm
        updated.deliveryStatus = .dismissed
        updated.currentSnoozeCount = 0
        if updated.repeatDays.isEmpty {
            updated.enabled = false
            updated.nextTriggerAt = nil
        } else {
            updated.nextTriggerAt = nextTrigger(for: updated, after: now.addingTimeInterval(1), calendar: calendar)
        }
        updated.updatedAt = now
        return updated
    }
}

enum AlarmSchedulingStatus: String, Codable, Equatable {
    case scheduled
    case canceled
    case approvalRequired
    case unsupported
    case failed
}

struct AlarmSchedulingResult: Codable, Equatable {
    var status: AlarmSchedulingStatus
    var message: String
    var scheduledAt: Date?
}

enum NotificationPermissionStatus: String, Codable, Equatable {
    case notDetermined
    case authorized
    case provisional
    case ephemeral
    case denied
    case unavailable
    case failed

    var label: String {
        switch self {
        case .notDetermined: return "Not requested"
        case .authorized: return "Allowed"
        case .provisional: return "Provisional"
        case .ephemeral: return "Temporary"
        case .denied: return "Denied"
        case .unavailable: return "Unavailable"
        case .failed: return "Failed"
        }
    }
}

struct NotificationPermissionResult: Codable, Equatable {
    var status: NotificationPermissionStatus
    var message: String

    static let notRequested = NotificationPermissionResult(
        status: .notDetermined,
        message: "Notification permission has not been requested."
    )
}

protocol NotificationPermissionAuthorizing {
    func currentAuthorization() async -> NotificationPermissionResult
    func requestAuthorization() async -> NotificationPermissionResult
}

struct NoopNotificationPermissionAuthorizer: NotificationPermissionAuthorizing {
    func currentAuthorization() async -> NotificationPermissionResult {
        NotificationPermissionResult(status: .unavailable, message: "Notifications are unavailable in this runtime.")
    }

    func requestAuthorization() async -> NotificationPermissionResult {
        NotificationPermissionResult(status: .unavailable, message: "Notifications are unavailable in this runtime.")
    }
}

protocol AlarmNotificationScheduling {
    func scheduleLocalNotification(for alarm: Alarm) async -> AlarmSchedulingResult
    func cancelLocalNotification(alarmID: UUID) async
}

struct NoopAlarmNotificationScheduler: AlarmNotificationScheduling {
    func scheduleLocalNotification(for alarm: Alarm) async -> AlarmSchedulingResult {
        AlarmSchedulingResult(status: .scheduled, message: "Alarm scheduler skipped in this runtime.", scheduledAt: alarm.nextTriggerAt)
    }

    func cancelLocalNotification(alarmID: UUID) async {}
}

enum OperationalNotificationKind: String, Codable, Equatable, Hashable, CaseIterable {
    case wearableDisconnected = "wearable_disconnected"
    case wearableBatteryLow = "wearable_battery_low"
    case wearableOffWrist = "wearable_off_wrist"
    case openAppReminder = "open_app_reminder"

    var identifier: String {
        "whoordan.operational.\(rawValue)"
    }
}

struct OperationalNotificationRequest: Codable, Equatable {
    var kind: OperationalNotificationKind
    var title: String
    var body: String
    var timeInterval: TimeInterval?

    init(
        kind: OperationalNotificationKind,
        title: String,
        body: String,
        timeInterval: TimeInterval? = nil
    ) {
        self.kind = kind
        self.title = title
        self.body = body
        self.timeInterval = timeInterval
    }
}

enum OperationalNotificationStatus: String, Codable, Equatable {
    case scheduled
    case skipped
    case permissionRequired
    case failed
}

struct OperationalNotificationResult: Codable, Equatable {
    var status: OperationalNotificationStatus
    var message: String
}

protocol OperationalNotificationScheduling {
    func schedule(_ request: OperationalNotificationRequest) async -> OperationalNotificationResult
    func cancel(kind: OperationalNotificationKind) async
}

struct NoopOperationalNotificationScheduler: OperationalNotificationScheduling {
    func schedule(_ request: OperationalNotificationRequest) async -> OperationalNotificationResult {
        OperationalNotificationResult(status: .skipped, message: "Operational notifications are unavailable in this runtime.")
    }

    func cancel(kind: OperationalNotificationKind) async {}
}

#if canImport(UserNotifications)
final class WhoordanNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WhoordanNotificationCenterDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

struct UserNotificationPermissionAuthorizer: NotificationPermissionAuthorizing {
    func currentAuthorization() async -> NotificationPermissionResult {
        await settingsResult(messagePrefix: "Notification permission")
    }

    func requestAuthorization() async -> NotificationPermissionResult {
        let center = UNUserNotificationCenter.current()
        let granted = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        let result = await settingsResult(messagePrefix: "Notification permission request completed")
        if granted || result.status == .authorized || result.status == .provisional || result.status == .ephemeral {
            return result
        }
        return NotificationPermissionResult(status: .denied, message: "Notification permission was not granted.")
    }

    private func settingsResult(messagePrefix: String) async -> NotificationPermissionResult {
        let settings = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
        let status: NotificationPermissionStatus
        switch settings.authorizationStatus {
        case .notDetermined:
            status = .notDetermined
        case .denied:
            status = .denied
        case .authorized:
            status = .authorized
        case .provisional:
            status = .provisional
        case .ephemeral:
            status = .ephemeral
        @unknown default:
            status = .failed
        }
        return NotificationPermissionResult(
            status: status,
            message: "\(messagePrefix): \(status.label)."
        )
    }
}

struct UserNotificationAlarmScheduler: AlarmNotificationScheduling {
    private let permissionAuthorizer = UserNotificationPermissionAuthorizer()

    func scheduleLocalNotification(for alarm: Alarm) async -> AlarmSchedulingResult {
        guard alarm.enabled, let nextTriggerAt = alarm.nextTriggerAt else {
            return AlarmSchedulingResult(status: .canceled, message: "Alarm is disabled.", scheduledAt: nil)
        }

        let permission = await permissionAuthorizer.requestAuthorization()
        guard permission.status == .authorized || permission.status == .provisional || permission.status == .ephemeral else {
            return AlarmSchedulingResult(status: .unsupported, message: "Local notification permission is not granted.", scheduledAt: nil)
        }

        await cancelLocalNotification(alarmID: alarm.id)
        let content = UNMutableNotificationContent()
        content.title = "Whoordan Alarm"
        content.body = "Open Whoordan to send wearable vibration when available."
        content.sound = .default
        let requests = notificationRequests(for: alarm, content: content, nextTriggerAt: nextTriggerAt)

        do {
            for request in requests {
                try await UNUserNotificationCenter.current().add(request)
            }
            return AlarmSchedulingResult(status: .scheduled, message: "Local iOS alarm notification scheduled.", scheduledAt: nextTriggerAt)
        } catch {
            return AlarmSchedulingResult(status: .failed, message: "Local alarm scheduling failed.", scheduledAt: nil)
        }
    }

    func cancelLocalNotification(alarmID: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.identifiers(for: alarmID))
    }

    private func notificationRequests(
        for alarm: Alarm,
        content: UNMutableNotificationContent,
        nextTriggerAt: Date
    ) -> [UNNotificationRequest] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: alarm.timezone) ?? .current

        if alarm.repeatDays.isEmpty {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextTriggerAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return [UNNotificationRequest(identifier: Self.identifier(for: alarm.id), content: content, trigger: trigger)]
        }

        return alarm.repeatDays.map { weekday in
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            components.weekday = weekday
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(
                identifier: Self.weekdayIdentifier(for: alarm.id, weekday: weekday),
                content: content,
                trigger: trigger
            )
        }
    }

    private static func identifiers(for alarmID: UUID) -> [String] {
        [identifier(for: alarmID)] + (1...7).map { weekdayIdentifier(for: alarmID, weekday: $0) }
    }

    private static func identifier(for alarmID: UUID) -> String {
        "whoordan.alarm.\(alarmID.uuidString)"
    }

    private static func weekdayIdentifier(for alarmID: UUID, weekday: Int) -> String {
        "whoordan.alarm.\(alarmID.uuidString).weekday.\(weekday)"
    }
}

struct UserNotificationOperationalScheduler: OperationalNotificationScheduling {
    private let permissionAuthorizer = UserNotificationPermissionAuthorizer()

    func schedule(_ request: OperationalNotificationRequest) async -> OperationalNotificationResult {
        let permission = await permissionAuthorizer.currentAuthorization()
        guard permission.status == .authorized || permission.status == .provisional || permission.status == .ephemeral else {
            return OperationalNotificationResult(status: .permissionRequired, message: "Local notification permission is not granted.")
        }

        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = "whoordan.operational"
        content.threadIdentifier = "whoordan.operational"

        let trigger = request.timeInterval.map {
            UNTimeIntervalNotificationTrigger(timeInterval: max($0, 1), repeats: false)
        }
        let center = UNUserNotificationCenter.current()
        let identifier = request.kind.identifier
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        let notificationRequest = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(notificationRequest)
            return OperationalNotificationResult(status: .scheduled, message: "Local operational notification scheduled.")
        } catch {
            return OperationalNotificationResult(status: .failed, message: "Local operational notification scheduling failed.")
        }
    }

    func cancel(kind: OperationalNotificationKind) async {
        let identifier = kind.identifier
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
#endif

@MainActor
protocol AlarmControlling {
    func snoozeAlarm(id: UUID) async -> Bool
    func dismissAlarm(id: UUID) async -> Bool
}

enum ActiveCallKind: String, Codable, Equatable {
    case whoordanOwnedVoIP
    case normalCellular
}

struct ActiveCallContext: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: ActiveCallKind
    var receivedAt: Date

    init(id: UUID = UUID(), kind: ActiveCallKind, receivedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.receivedAt = receivedAt
    }
}

enum DoubleTapRoutingStatus: String, Codable, Equatable {
    case ignored
    case previewRequested
    case declinedWhoordanCall
    case silencedCallVibration
    case snoozedAlarm
    case dismissedAlarm
    case noActiveSupportedCall
    case noActiveAlarm
    case cellularDeclinePlatformBlocked
    case approvalRequired
    case disabled
    case unsupported
}

struct DoubleTapRoutingResult: Codable, Equatable {
    var status: DoubleTapRoutingStatus
    var message: String
    var occurredAt: Date = Date()
}

protocol WhoordanCallControlling {
    func declineWhoordanCall(id: UUID) async -> Bool
}

enum DoubleTapActionRouter {
    static func handleDoubleTap(
        action: DoubleTapAction,
        callSettings: CallVibrationSettings,
        activeCall: ActiveCallContext?,
        approval: ApprovalState?,
        callController: WhoordanCallControlling?,
        isCellularCallVibrationActive: Bool = false,
        activeAlarm: Alarm? = nil,
        alarmController: AlarmControlling? = nil
    ) async -> DoubleTapRoutingResult {
        guard approval?.allowsProtectedLocalAccess == true else {
            return DoubleTapRoutingResult(status: .approvalRequired, message: "Approval is required before wearable double-tap actions.")
        }

        if action == .none {
            return DoubleTapRoutingResult(status: .ignored, message: "No double-tap action is configured.")
        }

        if action == .declineCallWhereSupported,
           isCellularCallVibrationActive,
           activeCall?.kind == .normalCellular {
            return DoubleTapRoutingResult(
                status: .silencedCallVibration,
                message: "Wearable call vibration silenced. Normal cellular call decline remains platform-blocked."
            )
        }

        if callSettings.declineOnDoubleTapEnabled, let activeCall {
            return await handleCallDecline(callSettings: callSettings, activeCall: activeCall, callController: callController)
        }

        if let activeAlarm {
            guard let alarmController else {
                return DoubleTapRoutingResult(status: .unsupported, message: "Alarm double-tap handling is not wired in this build.")
            }
            let shouldDismiss = action == .dismissAlarmWhereSupported
                || !activeAlarm.snoozeEnabled
                || activeAlarm.currentSnoozeCount >= activeAlarm.maxSnoozes
            if shouldDismiss {
                let dismissed = await alarmController.dismissAlarm(id: activeAlarm.id)
                return DoubleTapRoutingResult(
                    status: dismissed ? .dismissedAlarm : .unsupported,
                    message: dismissed ? "Active alarm dismissed from wearable double tap." : "Alarm dismissal failed."
                )
            }
            let snoozed = await alarmController.snoozeAlarm(id: activeAlarm.id)
            return DoubleTapRoutingResult(
                status: snoozed ? .snoozedAlarm : .unsupported,
                message: snoozed ? "Active alarm snoozed from wearable double tap." : "Alarm snooze failed."
            )
        }

        switch action {
        case .none:
            return DoubleTapRoutingResult(status: .ignored, message: "No double-tap action is configured.")
        case .previewHaptic:
            return DoubleTapRoutingResult(status: .previewRequested, message: "Double tap requested a haptic preview.")
        case .snoozeAlarmWhereSupported, .dismissAlarmWhereSupported:
            return DoubleTapRoutingResult(status: .noActiveAlarm, message: "No active alarm is available for double-tap action.")
        case .debugAction:
            return DoubleTapRoutingResult(status: .ignored, message: "Debug double-tap action recorded without private data.")
        case .declineCallWhereSupported:
            guard callSettings.declineOnDoubleTapEnabled else {
                return DoubleTapRoutingResult(status: .disabled, message: "Decline on double tap is disabled.")
            }
            return DoubleTapRoutingResult(status: .noActiveSupportedCall, message: "No supported Whoordan-owned incoming call or active alarm is available.")
        }
    }

    private static func handleCallDecline(
        callSettings: CallVibrationSettings,
        activeCall: ActiveCallContext,
        callController: WhoordanCallControlling?
    ) async -> DoubleTapRoutingResult {
        switch activeCall.kind {
        case .normalCellular:
            return DoubleTapRoutingResult(
                status: .cellularDeclinePlatformBlocked,
                message: "Normal cellular call decline is platform-blocked for third-party apps."
            )
        case .whoordanOwnedVoIP:
            guard callSettings.supportsDecline, let callController else {
                return DoubleTapRoutingResult(status: .noActiveSupportedCall, message: "Whoordan-owned call decline is not wired in this build.")
            }
            let declined = await callController.declineWhoordanCall(id: activeCall.id)
            return DoubleTapRoutingResult(
                status: declined ? .declinedWhoordanCall : .unsupported,
                message: declined ? "Whoordan-owned call declined." : "Whoordan-owned call decline failed."
            )
        }
    }
}

protocol VibrationPreviewing {
    func preview(_ pattern: VibrationPattern, approval: ApprovalState?, device: WearableDeviceState) async -> VibrationPreviewResult
    func cancel() async
}

final class VibrationPreviewService: VibrationPreviewing {
    private weak var commandSink: WearableCommandSink?
    private var sequence: UInt8 = 0xA0

    init(commandSink: WearableCommandSink?) {
        self.commandSink = commandSink
    }

    func preview(_ pattern: VibrationPattern, approval: ApprovalState?, device: WearableDeviceState) async -> VibrationPreviewResult {
        _ = pattern
        guard approval?.allowsProtectedLocalAccess == true else {
            return VibrationPreviewResult(status: .approvalRequired, message: "Approval is required before wearable vibration preview.", errorCategory: .approval)
        }
        guard device.connection == .realtime || device.connection == .historicalSync else {
            return VibrationPreviewResult(status: .deviceDisconnected, message: "Connect a supported wearable before previewing.", errorCategory: .connection)
        }

        return await playStandardPattern()
    }

    func cancel() async {
        let stop = WearableProtocol.buildCommand(sequence: nextSequence(), command: .stopHaptics, payload: [0x00])
        try? await commandSink?.writeCommand(stop, requiresResponse: true)
    }

    private func playStandardPattern() async -> VibrationPreviewResult {
        do {
            try await sendStart(patternID: VibrationPattern.standardBuiltInPatternID, repeatCount: 1)
            return VibrationPreviewResult(
                status: .started,
                commandsSent: ["0x4F", "0x13"],
                message: "Standard wearable vibration command sent. Device event confirmation is still required for physical validation."
            )
        } catch {
            return VibrationPreviewResult(status: .failed, commandsSent: ["0x4F", "0x13"], message: error.localizedDescription, errorCategory: .transport)
        }
    }

    private func sendStart(patternID: UInt8, repeatCount: UInt8) async throws {
        let harvard = WearableProtocol.buildCommand(
            sequence: nextSequence(),
            command: .runHapticPatternHarvard,
            payload: [patternID, repeatCount, 0, 0, 0]
        )
        let maverickPayload: [UInt8] = [0x01, 0x2F, 0x98, 0, 0, 0, 0, 0, 0, 0, 0, 0x01]
        let maverick = WearableProtocol.buildCommand(
            sequence: nextSequence(),
            command: .runHapticPatternMaverick,
            payload: maverickPayload
        )
        try await commandSink?.writeCommand(harvard, requiresResponse: true)
        try await commandSink?.writeCommand(maverick, requiresResponse: true)
    }

    private func nextSequence() -> UInt8 {
        defer { sequence = sequence &+ 1 }
        return sequence
    }
}
