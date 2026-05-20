import Combine
import Foundation

#if canImport(CallKit)
import CallKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// swiftlint:disable file_length

enum CallStateEvent: Equatable {
    case incomingCellularRinging(id: UUID, receivedAt: Date)
    case cellularCallConnected(id: UUID)
    case cellularCallEnded(id: UUID)

    var diagnosticDescription: String {
        switch self {
        case .incomingCellularRinging:
            return "Incoming cellular call event received."
        case .cellularCallConnected:
            return "Cellular call connected event received."
        case .cellularCallEnded:
            return "Cellular call ended event received."
        }
    }
}

protocol CallStateObserving: AnyObject {
    var onEvent: ((CallStateEvent) -> Void)? { get set }
    func start()
}

protocol BackgroundTaskManaging: AnyObject {
    @MainActor
    func withBackgroundTask(
        named name: String,
        operation: @escaping @MainActor () async -> Void
    ) async
}

final class NoopBackgroundTaskManager: BackgroundTaskManaging {
    @MainActor
    func withBackgroundTask(
        named name: String,
        operation: @escaping @MainActor () async -> Void
    ) async {
        await operation()
    }
}

#if canImport(UIKit)
final class UIKitBackgroundTaskManager: BackgroundTaskManaging {
    @MainActor
    func withBackgroundTask(
        named name: String,
        operation: @escaping @MainActor () async -> Void
    ) async {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
                taskID = .invalid
            }
        }
        await operation()
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}
#endif

private enum BackgroundTaskManagerFactory {
    static func make() -> BackgroundTaskManaging {
        #if canImport(UIKit)
        return UIKitBackgroundTaskManager()
        #else
        return NoopBackgroundTaskManager()
        #endif
    }
}

#if canImport(CallKit)
final class CallKitCallStateObserver: NSObject, CallStateObserving, CXCallObserverDelegate {
    var onEvent: ((CallStateEvent) -> Void)?
    private let observer = CXCallObserver()
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        observer.setDelegate(self, queue: nil)
        observer.calls.forEach { emitEvent(for: $0) }
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        emitEvent(for: call)
    }

    private func emitEvent(for call: CXCall) {
        if call.hasEnded {
            onEvent?(.cellularCallEnded(id: call.uuid))
        } else if !call.isOutgoing && !call.hasConnected {
            onEvent?(.incomingCellularRinging(id: call.uuid, receivedAt: Date()))
        } else if call.hasConnected {
            onEvent?(.cellularCallConnected(id: call.uuid))
        }
    }
}
#endif

// swiftlint:disable type_body_length
@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var approvalState: ApprovalState?
    @Published private(set) var isRestoring = true
    @Published var consentState = ConsentState()
    @Published var todaySnapshot = DailyHealthSummary.empty
    @Published var deviceState = WearableDeviceState()
    @Published var healthKitResult = HealthKitAuthorizationResult(status: .notDetermined, requestedTypes: [], message: "Not requested.")
    @Published var notificationPermissionResult = NotificationPermissionResult.notRequested
    @Published var healthSyncResult = HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Health cloud sync has not run.")
    @Published var accountSyncResult = AccountSyncResult.notRun
    @Published private(set) var localDataExportURL: URL?
    @Published var privacyActionMessage = "No privacy action has run."
    @Published private(set) var healthKitImportedSampleCount = 0
    @Published private(set) var healthKitExportedSampleCount = 0
    @Published private(set) var hasLoadedApprovedLocalState = false
    @Published private(set) var hasLoadedCallVibrationSettings = false
    @Published var isCloudSyncConsentPromptPresented = false
    @Published private(set) var recentSummaries: [DailyHealthSummary] = []
    @Published private(set) var bodyProfile = BodyProfile()
    @Published private(set) var skinTemperatureBaselineProfile = SkinTemperatureBaselineProfile()
    @Published var lastVibrationResult = VibrationPreviewResult(status: .notConnected)
    @Published var vibrationPatterns = VibrationPattern.builtIns
    @Published var callVibrationSettings = CallVibrationSettings()
    @Published var lastCallVibrationRouting = CallVibrationRoutingResult(pattern: nil, reason: .disabled, safeMessage: "No call vibration routed.")
    @Published var lastCallStateEventMessage = "No cellular call event received in this app session."
    @Published var activeCellularCall: ActiveCallContext?
    @Published var isCellularCallVibrationActive = false
    @Published var alarms: [Alarm] = []
    @Published var activeAlarm: Alarm?
    @Published var lastAlarmSchedulingResult = AlarmSchedulingResult(status: .canceled, message: "No alarm scheduled.", scheduledAt: nil)
    @Published var lastDoubleTapRouting = DoubleTapRoutingResult(status: .ignored, message: "No double-tap action routed.")
    @Published var authMessage: String?
    @Published private(set) var availableUpdate: WhoordanUpdate?

    let authService: AuthServicing
    let approvalService: ApprovalServicing
    let localStore: LocalStoring
    let healthKitService: HealthKitServicing
    let healthSyncService: HealthSyncServicing
    let accountSyncService: AccountSyncServicing
    let bleService: WearableBLEServicing
    let hapticService: VibrationPreviewing
    let notificationPermissionService: NotificationPermissionAuthorizing
    let alarmScheduler: AlarmNotificationScheduling
    let operationalNotificationScheduler: OperationalNotificationScheduling
    let scoringService: ScoringServicing
    let updateService: UpdateServicing
    private let backgroundTaskManager: BackgroundTaskManaging
    let privacyGuard = PrivacyAccessGuard()
    private let ingestionPipeline = HealthIngestionPipeline()
    private let backgroundSyncCoordinator = BackgroundSyncCoordinator()
    private let now: () -> Date
    private let startupRestoreTimeoutNanoseconds: UInt64
    private let startupApprovalRecoveryDelayNanoseconds: UInt64
    private let wearableStateMinimumPublishInterval: TimeInterval
    private let vibrationRepeatIntervalNanoseconds: UInt64
    private let vibrationRepeatDelay: @Sendable (UInt64) async -> Void
    private var lastImportedHealthSamples: [HealthSample] = []
    private var lastWearableStatePublishedAt: Date?
    private var pendingWearableState: WearableDeviceState?
    private var wearableStatePublishTask: Task<Void, Never>?
    private var callVibrationRepeatTask: Task<Void, Never>?
    private var callVibrationSettingsPersistenceTask: Task<Void, Never>?
    private var alarmPersistenceTask: Task<Void, Never>?
    private var alarmVibrationRepeatTask: Task<Void, Never>?
    private var alarmMonitorTask: Task<Void, Never>?
    private var startupApprovalRecoveryTask: Task<Void, Never>?
    private var standardVibrationInFlight = false
    private var callStateObserver: CallStateObserving?
    private var didRunStartupPermissionRequest = false
    private var didPrimeBluetoothPermission = false
    private var lowBatteryNotificationArmed = true
    private var lastOperationalNotificationAt: [OperationalNotificationKind: Date] = [:]
    private var pendingOperationalNotificationKinds = Set<OperationalNotificationKind>()
    private var cloudRestoredDailySummaries: [Date: DailyHealthSummary] = [:]
    private var activeStartupRestoreID = UUID()
    private var completedStartupRestoreID: UUID?
    private static let callVibrationSettingsFallbackStorageKey = "whoordan.callVibrationSettings.fallback"
    private static let offlineApprovalGraceInterval: TimeInterval = 7 * 24 * 60 * 60
    private static let lowBatteryNotificationThreshold = 20
    private static let lowBatteryRearmThreshold = 30
    private static let wearableDisconnectedNotificationDelay: TimeInterval = 5
    private static let wearableOffWristReminderDelay: TimeInterval = 5 * 60
    private static let disconnectedNotificationCooldown: TimeInterval = 30 * 60
    private static let sleepAggregationLookbackHours = 12
    private static let startupRestorePollNanoseconds: UInt64 = 20_000_000
    private static let startupRestoreTimeoutMessage = "Session restore timed out. Check connection and try again."

    init(
        authService: AuthServicing,
        approvalService: ApprovalServicing,
        localStore: LocalStoring,
        healthKitService: HealthKitServicing,
        healthSyncService: HealthSyncServicing,
        accountSyncService: AccountSyncServicing = NoopAccountSyncService(),
        bleService: WearableBLEServicing,
        hapticService: VibrationPreviewing,
        notificationPermissionService: NotificationPermissionAuthorizing? = nil,
        alarmScheduler: AlarmNotificationScheduling = NoopAlarmNotificationScheduler(),
        operationalNotificationScheduler: OperationalNotificationScheduling = NoopOperationalNotificationScheduler(),
        scoringService: ScoringServicing,
        updateService: UpdateServicing = NoopUpdateService(),
        backgroundTaskManager: BackgroundTaskManaging = BackgroundTaskManagerFactory.make(),
        startupRestoreTimeoutNanoseconds: UInt64 = 8_000_000_000,
        startupApprovalRecoveryDelayNanoseconds: UInt64 = 2_000_000_000,
        wearableStateMinimumPublishInterval: TimeInterval = 0.75,
        vibrationRepeatIntervalNanoseconds: UInt64 = 1_000_000_000,
        vibrationRepeatDelay: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        now: @escaping () -> Date = Date.init
    ) {
        self.authService = authService
        self.approvalService = approvalService
        self.localStore = localStore
        self.healthKitService = healthKitService
        self.healthSyncService = healthSyncService
        self.accountSyncService = accountSyncService
        self.bleService = bleService
        self.hapticService = hapticService
        self.notificationPermissionService = notificationPermissionService ?? NoopNotificationPermissionAuthorizer()
        self.alarmScheduler = alarmScheduler
        self.operationalNotificationScheduler = operationalNotificationScheduler
        self.scoringService = scoringService
        self.updateService = updateService
        self.backgroundTaskManager = backgroundTaskManager
        self.startupRestoreTimeoutNanoseconds = max(startupRestoreTimeoutNanoseconds, Self.startupRestorePollNanoseconds)
        self.startupApprovalRecoveryDelayNanoseconds = startupApprovalRecoveryDelayNanoseconds
        self.wearableStateMinimumPublishInterval = max(0.1, wearableStateMinimumPublishInterval)
        self.vibrationRepeatIntervalNanoseconds = vibrationRepeatIntervalNanoseconds
        self.vibrationRepeatDelay = vibrationRepeatDelay
        self.now = now
    }

    deinit {
        wearableStatePublishTask?.cancel()
        callVibrationRepeatTask?.cancel()
        callVibrationSettingsPersistenceTask?.cancel()
        alarmPersistenceTask?.cancel()
        alarmVibrationRepeatTask?.cancel()
        alarmMonitorTask?.cancel()
    }

    static func live() -> AppEnvironment {
        let config = SupabaseConfig.fromBundle()
        let keychain = KeychainStore(service: "com.w4rd2.whoordan")
        let auth = SupabaseAuthService(config: config, keychain: keychain)
        let approval = SupabaseApprovalService(config: config, authTokenProvider: auth)
        let store = FileProtectedLocalStore()
        let ble = WearableBLEService(preferredDeviceName: ProcessInfo.processInfo.environment["WHOORDAN_PREFERRED_WEARABLE_NAME"])
        #if canImport(UserNotifications)
        WhoordanNotificationCenterDelegate.install()
        let alarmScheduler = UserNotificationAlarmScheduler()
        let operationalNotificationScheduler = UserNotificationOperationalScheduler()
        let notificationPermissionService = UserNotificationPermissionAuthorizer()
        #else
        let alarmScheduler = NoopAlarmNotificationScheduler()
        let operationalNotificationScheduler = NoopOperationalNotificationScheduler()
        let notificationPermissionService = NoopNotificationPermissionAuthorizer()
        #endif
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: store,
            healthKitService: HealthKitService(),
            healthSyncService: SupabaseHealthSyncService(config: config),
            accountSyncService: SupabaseAccountSyncService(config: config),
            bleService: ble,
            hapticService: VibrationPreviewService(commandSink: ble),
            notificationPermissionService: notificationPermissionService,
            alarmScheduler: alarmScheduler,
            operationalNotificationScheduler: operationalNotificationScheduler,
            scoringService: WhoordanScoringService(),
            updateService: DefaultUpdateService()
        )
        ble.onStateChange = { [weak environment] state in
            Task { @MainActor in
                environment?.receiveWearableState(state)
            }
        }
        ble.onHealthSamples = { [weak environment] samples in
            await environment?.ingestWearableSamples(samples) ?? false
        }
        ble.onBLECheckpoint = { [weak environment] checkpoint in
            Task {
                try? await environment?.localStore.saveBLECheckpoint(checkpoint)
            }
        }
        ble.onControlPlaneEvent = { [weak environment] event in
            Task {
                try? await environment?.localStore.saveWearableControlPlaneEvent(event)
            }
        }
        ble.onEvent = { [weak environment] event in
            Task { @MainActor in
                await environment?.receiveWearableEvent(event)
            }
        }
        Task { [weak environment, store, ble] in
            let checkpoints = await store.loadBLECheckpoints()
            await MainActor.run {
                ble.restoreBLECheckpoints(checkpoints)
                environment?.receiveWearableState(ble.currentDeviceState)
            }
        }
        #if canImport(CallKit)
        let callStateObserver = CallKitCallStateObserver()
        callStateObserver.onEvent = { [weak environment] event in
            Task { @MainActor in
                await environment?.receiveCallStateEvent(event)
            }
        }
        environment.callStateObserver = callStateObserver
        callStateObserver.start()
        #endif
        environment.registerBackgroundSync()
        return environment
    }

    var route: AppRoute {
        AppRouter.route(
            session: session,
            approval: approvalState,
            restoring: isRestoring
        )
    }

    var isApproved: Bool {
        approvalState?.allowsProtectedLocalAccess == true
    }

    func receiveWearableState(_ state: WearableDeviceState) {
        guard state != deviceState else { return }
        if shouldPublishWearableStateImmediately(state) {
            wearableStatePublishTask?.cancel()
            wearableStatePublishTask = nil
            pendingWearableState = nil
            publishWearableStateImmediately(state)
            return
        }

        let currentTime = now()
        guard let lastPublished = lastWearableStatePublishedAt else {
            publishWearableStateImmediately(state)
            return
        }

        let elapsed = currentTime.timeIntervalSince(lastPublished)
        if elapsed >= wearableStateMinimumPublishInterval {
            publishWearableStateImmediately(state)
        } else {
            pendingWearableState = state
            schedulePendingWearableStatePublish(after: wearableStateMinimumPublishInterval - elapsed)
        }
    }

    private func shouldPublishWearableStateImmediately(_ state: WearableDeviceState) -> Bool {
        deviceState.connection != state.connection
            || deviceState.deviceID != state.deviceID
            || deviceState.name != state.name
            || deviceState.rawCapture.isActive != state.rawCapture.isActive
            || deviceState.rawCapture.scenario != state.rawCapture.scenario
            || deviceState.candidates != state.candidates
            || deviceState.discoveredUUIDs != state.discoveredUUIDs
            || deviceState.lastError != state.lastError
            || deviceState.batteryPercent != state.batteryPercent
            || deviceState.isCharging != state.isCharging
            || deviceState.isOnWrist != state.isOnWrist
            || deviceState.syncDiagnostics != state.syncDiagnostics
    }

    private func publishWearableStateImmediately(_ state: WearableDeviceState) {
        let priorState = deviceState
        deviceState = state
        lastWearableStatePublishedAt = now()
        handleWearableOperationalNotifications(from: priorState, to: state)
    }

    private func schedulePendingWearableStatePublish(after delay: TimeInterval) {
        guard wearableStatePublishTask == nil else { return }
        let nanoseconds = UInt64(max(delay, 0.05) * 1_000_000_000)
        wearableStatePublishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            self?.flushPendingWearableState()
        }
    }

    private func flushPendingWearableState() {
        wearableStatePublishTask = nil
        guard let pendingWearableState else { return }
        self.pendingWearableState = nil
        publishWearableStateImmediately(pendingWearableState)
    }

    private func handleWearableOperationalNotifications(
        from priorState: WearableDeviceState,
        to currentState: WearableDeviceState
    ) {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }

        if shouldNotifyWearableDisconnected(from: priorState, to: currentState) {
            scheduleOperationalNotification(
                OperationalNotificationRequest(
                    kind: .wearableDisconnected,
                    title: "Whoordan wearable disconnected",
                    body: "Your wearable has been disconnected from Whoordan for 5 seconds. Open the app to reconnect and keep live data current.",
                    timeInterval: Self.wearableDisconnectedNotificationDelay
                ),
                minimumInterval: Self.disconnectedNotificationCooldown
            )
        } else if !isDisconnected(currentState) {
            cancelOperationalNotification(kind: .wearableDisconnected, clearCooldown: true)
        }

        if shouldNotifyLowBattery(from: priorState, to: currentState) {
            lowBatteryNotificationArmed = false
            scheduleOperationalNotification(
                OperationalNotificationRequest(
                    kind: .wearableBatteryLow,
                    title: "Charge your Whoordan wearable",
                    body: "Your wearable battery is low. Charge the wearable soon to keep recovery and sleep tracking available."
                ),
                minimumInterval: nil
            )
        }

        if shouldRearmLowBatteryNotification(currentState) {
            lowBatteryNotificationArmed = true
            cancelOperationalNotification(kind: .wearableBatteryLow)
        }

        if shouldScheduleOffWristReminder(from: priorState, to: currentState) {
            scheduleOperationalNotification(
                OperationalNotificationRequest(
                    kind: .wearableOffWrist,
                    title: "Wear your Whoordan wearable",
                    body: "Your wearable has been off-wrist for 5 minutes. Put it back on to keep recovery and sleep tracking complete.",
                    timeInterval: Self.wearableOffWristReminderDelay
                ),
                minimumInterval: nil
            )
        } else if shouldCancelOffWristReminder(currentState) {
            cancelOperationalNotification(kind: .wearableOffWrist, clearCooldown: true)
        }
    }

    private func isConnected(_ state: WearableDeviceState) -> Bool {
        state.connection == .realtime || state.connection == .historicalSync
    }

    private func isDisconnected(_ state: WearableDeviceState) -> Bool {
        state.connection == .disconnected || state.connection == .error
    }

    private func shouldNotifyWearableDisconnected(
        from priorState: WearableDeviceState,
        to currentState: WearableDeviceState
    ) -> Bool {
        isConnected(priorState) && isDisconnected(currentState)
    }

    private func shouldNotifyLowBattery(
        from priorState: WearableDeviceState,
        to currentState: WearableDeviceState
    ) -> Bool {
        guard lowBatteryNotificationArmed,
              currentState.connection == .realtime || currentState.connection == .historicalSync,
              currentState.isCharging != true,
              let batteryPercent = currentState.batteryPercent,
              batteryPercent <= Self.lowBatteryNotificationThreshold else {
            return false
        }
        guard priorState.isCharging != true else { return true }
        return priorState.batteryPercent.map { $0 > Self.lowBatteryNotificationThreshold } ?? true
    }

    private func shouldRearmLowBatteryNotification(_ state: WearableDeviceState) -> Bool {
        state.isCharging == true || (state.batteryPercent.map { $0 >= Self.lowBatteryRearmThreshold } ?? false)
    }

    private func shouldScheduleOffWristReminder(
        from priorState: WearableDeviceState,
        to currentState: WearableDeviceState
    ) -> Bool {
        guard isConnected(currentState),
              currentState.isCharging != true,
              currentState.isOnWrist == false,
              !pendingOperationalNotificationKinds.contains(.wearableOffWrist) else {
            return false
        }
        return priorState.isOnWrist != false || priorState.deviceID != currentState.deviceID
    }

    private func shouldCancelOffWristReminder(_ state: WearableDeviceState) -> Bool {
        state.isOnWrist == true || state.isOnWrist == nil || state.isCharging == true || !isConnected(state)
    }

    private func scheduleOperationalNotification(
        _ request: OperationalNotificationRequest,
        minimumInterval: TimeInterval?
    ) {
        let currentTime = now()
        if let minimumInterval,
           let lastSentAt = lastOperationalNotificationAt[request.kind],
           currentTime.timeIntervalSince(lastSentAt) < minimumInterval {
            return
        }
        pendingOperationalNotificationKinds.insert(request.kind)
        lastOperationalNotificationAt[request.kind] = currentTime
        Task { [operationalNotificationScheduler, weak self] in
            let result = await operationalNotificationScheduler.schedule(request)
            await MainActor.run {
                if result.status != .scheduled {
                    self?.pendingOperationalNotificationKinds.remove(request.kind)
                    if minimumInterval != nil {
                        self?.lastOperationalNotificationAt[request.kind] = nil
                    }
                }
            }
        }
    }

    private func cancelOperationalNotification(kind: OperationalNotificationKind, clearCooldown: Bool = false) {
        pendingOperationalNotificationKinds.remove(kind)
        if clearCooldown {
            lastOperationalNotificationAt[kind] = nil
        }
        Task { [operationalNotificationScheduler] in
            await operationalNotificationScheduler.cancel(kind: kind)
        }
    }

    private func cancelOperationalNotifications() async {
        for kind in OperationalNotificationKind.allCases {
            await operationalNotificationScheduler.cancel(kind: kind)
        }
        pendingOperationalNotificationKinds.removeAll()
    }

    func restore() async {
        primeBluetoothPermissionIfNeeded()
        isRestoring = true
        hasLoadedApprovedLocalState = false
        let attemptID = UUID()
        activeStartupRestoreID = attemptID
        completedStartupRestoreID = nil

        let completed = await restoreSessionAndApprovalWithTimeout(attemptID: attemptID)
        if !completed {
            await handleStartupRestoreTimeout(attemptID: attemptID)
        }

        isRestoring = false
        await loadLocalStateIfAllowed()
        await syncAccountStateIfAllowed(applyRemote: true, uploadAfterRemote: false)
        startApprovedServicesIfAllowed()
        await syncHealthDataIfAllowed(restoreCloudSamples: true, uploadAfterRestore: false)
        await scheduleStartupApprovalRecoveryIfNeeded()
        await checkForAppUpdate()
    }

    func checkForAppUpdate() async {
        guard UpdateCheckPolicy.isAutomaticCheckEnabled() else { return }
        let current = WhoordanAppBuild.current()
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.w4rd2.whoordan"
        let result = await updateService.checkForUpdate(currentBuild: current, bundleIdentifier: bundleIdentifier)
        if case .available(let update) = result {
            availableUpdate = update
        }
    }

    func dismissAvailableUpdate() {
        availableUpdate = nil
    }

    func openAvailableUpdate() {
        guard let url = availableUpdate?.installURL else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func restoreSessionAndApprovalWithTimeout(attemptID: UUID) async -> Bool {
        let restoreTask = Task { @MainActor [weak self] in
            await self?.restoreSessionAndApprovalIfCurrent(attemptID: attemptID)
            if self?.activeStartupRestoreID == attemptID {
                self?.completedStartupRestoreID = attemptID
            }
        }
        let timeoutAt = Date().addingTimeInterval(Double(startupRestoreTimeoutNanoseconds) / 1_000_000_000)
        while completedStartupRestoreID != attemptID && Date() < timeoutAt {
            try? await Task.sleep(nanoseconds: Self.startupRestorePollNanoseconds)
        }
        if completedStartupRestoreID == attemptID {
            restoreTask.cancel()
            return true
        }
        restoreTask.cancel()
        return false
    }

    private func restoreSessionAndApprovalIfCurrent(attemptID: UUID) async {
        do {
            let restoredSession = try await authService.restoreSession()
            guard isCurrentStartupRestore(attemptID) else { return }
            session = restoredSession
            if session != nil {
                await verifyApprovalWithRetry(restoreAttemptID: attemptID)
            }
        } catch AuthError.sessionExpired {
            guard isCurrentStartupRestore(attemptID) else { return }
            session = nil
            approvalState = .authExpired()
        } catch let error as URLError where Self.isNetworkUnavailable(error) {
            guard isCurrentStartupRestore(attemptID) else { return }
            approvalState = await offlineCapableNetworkState()
        } catch {
            guard isCurrentStartupRestore(attemptID) else { return }
            authMessage = error.localizedDescription
            session = nil
            approvalState = .unknownError(message: "Session restore failed.")
        }
    }

    private func handleStartupRestoreTimeout(attemptID: UUID) async {
        guard activeStartupRestoreID == attemptID else { return }
        activeStartupRestoreID = UUID()
        completedStartupRestoreID = nil
        authMessage = Self.startupRestoreTimeoutMessage
        if session != nil {
            approvalState = await offlineCapableNetworkState()
        } else {
            session = nil
            approvalState = nil
        }
    }

    private func isCurrentStartupRestore(_ attemptID: UUID?) -> Bool {
        guard let attemptID else { return !Task.isCancelled }
        return !Task.isCancelled && activeStartupRestoreID == attemptID
    }

    func signIn(email: String, password: String) async {
        do {
            authMessage = nil
            startupApprovalRecoveryTask?.cancel()
            startupApprovalRecoveryTask = nil
            hasLoadedApprovedLocalState = false
            session = try await authService.signIn(email: email, password: password)
            await verifyApprovalWithRetry()
            await loadLocalStateIfAllowed()
            await syncAccountStateIfAllowed(applyRemote: true, uploadAfterRemote: false)
            startApprovedServicesIfAllowed()
            await syncHealthDataIfAllowed(restoreCloudSamples: true, uploadAfterRestore: false)
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        do {
            authMessage = nil
            startupApprovalRecoveryTask?.cancel()
            startupApprovalRecoveryTask = nil
            hasLoadedApprovedLocalState = false
            session = try await authService.signUp(email: email, password: password)
            await verifyApprovalWithRetry()
            await loadLocalStateIfAllowed()
            await syncAccountStateIfAllowed(applyRemote: true, uploadAfterRemote: false)
            startApprovedServicesIfAllowed()
            await syncHealthDataIfAllowed(restoreCloudSamples: true, uploadAfterRestore: false)
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        do {
            try await authService.resetPassword(email: email)
            authMessage = "Password reset email requested."
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func signOut() async {
        bleService.stopAll()
        cancelCallVibrationLoop()
        cancelAlarmVibrationLoop()
        cancelAlarmMonitor()
        await hapticService.cancel()
        await cancelOperationalNotifications()
        alarmPersistenceTask?.cancel()
        alarmPersistenceTask = nil
        startupApprovalRecoveryTask?.cancel()
        startupApprovalRecoveryTask = nil
        await authService.signOut()
        clearCachedCallVibrationSettings()
        await localStore.clearUnlockedCache()
        session = nil
        approvalState = nil
        todaySnapshot = .empty
        recentSummaries = []
        cloudRestoredDailySummaries = [:]
        consentState = ConsentState()
        deviceState = WearableDeviceState()
        vibrationPatterns = VibrationPattern.builtIns
        callVibrationSettings = CallVibrationSettings()
        lastCallVibrationRouting = CallVibrationRoutingResult(pattern: nil, reason: .disabled, safeMessage: "No call vibration routed.")
        lastCallStateEventMessage = "No cellular call event received in this app session."
        activeCellularCall = nil
        isCellularCallVibrationActive = false
        alarms = []
        activeAlarm = nil
        lastAlarmSchedulingResult = AlarmSchedulingResult(status: .canceled, message: "No alarm scheduled.", scheduledAt: nil)
        lastDoubleTapRouting = DoubleTapRoutingResult(status: .ignored, message: "No double-tap action routed.")
        lastImportedHealthSamples = []
        healthKitImportedSampleCount = 0
        healthKitExportedSampleCount = 0
        hasLoadedApprovedLocalState = false
        hasLoadedCallVibrationSettings = false
        isCloudSyncConsentPromptPresented = false
        didRunStartupPermissionRequest = false
        healthSyncResult = HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "Health cloud sync has not run.")
        accountSyncResult = .notRun
        localDataExportURL = nil
        privacyActionMessage = "No privacy action has run."
        healthKitResult = HealthKitAuthorizationResult(status: .notDetermined, requestedTypes: [], message: "Not requested.")
        notificationPermissionResult = .notRequested
        bodyProfile = BodyProfile()
        skinTemperatureBaselineProfile = SkinTemperatureBaselineProfile()
        cloudRestoredDailySummaries = [:]
        didPrimeBluetoothPermission = false
        lowBatteryNotificationArmed = true
        lastOperationalNotificationAt = [:]
        pendingOperationalNotificationKinds.removeAll()
        updateWearableSyntheticCalibrationContext()
    }

    func refreshApproval() async throws {
        if session != nil {
            startupApprovalRecoveryTask?.cancel()
            startupApprovalRecoveryTask = nil
            await verifyApprovalWithRetry()
            await loadLocalStateIfAllowed()
            await syncAccountStateIfAllowed(applyRemote: true, uploadAfterRemote: false)
            startApprovedServicesIfAllowed()
            await syncHealthDataIfAllowed(restoreCloudSamples: true, uploadAfterRestore: false)
        }
    }

    func refreshApprovalInBackground() async {
        guard session != nil else { return }
        await verifyApprovalWithRetry(presentsCheckingState: false)
        await loadLocalStateIfAllowed()
        await syncAccountStateIfAllowed(applyRemote: true, uploadAfterRemote: false)
        startApprovedServicesIfAllowed()
        await syncHealthDataIfAllowed(restoreCloudSamples: true, uploadAfterRestore: false)
    }

    private func scheduleStartupApprovalRecoveryIfNeeded() async {
        guard session != nil,
              let status = approvalState?.status,
              status != .approved else {
            return
        }

        switch status {
        case .offlineApproved, .networkUnavailable, .approvalFetchFailed, .unknownError, .unknown, .error:
            break
        case .checkingApproval, .authExpired, .pending, .rejected, .revoked, .missing, .approved:
            return
        }

        startupApprovalRecoveryTask?.cancel()
        let scheduledUserID = session?.userID
        let scheduledStatus = approvalState?.status
        let recoveryDelay = startupApprovalRecoveryDelayNanoseconds
        if recoveryDelay == 0 {
            await runStartupApprovalRecoveryIfCurrent(
                scheduledUserID: scheduledUserID,
                scheduledStatus: scheduledStatus
            )
            return
        }
        startupApprovalRecoveryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: recoveryDelay)
            guard !Task.isCancelled else { return }
            let shouldRun = await MainActor.run { [weak self] in
                guard let self else { return false }
                return self.session?.userID == scheduledUserID
                    && self.approvalState?.status == scheduledStatus
            }
            guard shouldRun else { return }
            guard let self else { return }
            await self.runStartupApprovalRecoveryIfCurrent(
                scheduledUserID: scheduledUserID,
                scheduledStatus: scheduledStatus
            )
        }
    }

    private func runStartupApprovalRecoveryIfCurrent(
        scheduledUserID: UUID?,
        scheduledStatus: ApprovalStatus?
    ) async {
        guard session?.userID == scheduledUserID,
              approvalState?.status == scheduledStatus else {
            return
        }
        await refreshApprovalInBackground()
        startupApprovalRecoveryTask = nil
    }

    func loadLocalStateIfAllowed() async {
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else {
            hasLoadedApprovedLocalState = false
            todaySnapshot = .empty
            recentSummaries = []
            cloudRestoredDailySummaries = [:]
            vibrationPatterns = VibrationPattern.builtIns
            callVibrationSettings = CallVibrationSettings()
            hasLoadedCallVibrationSettings = false
            lastCallVibrationRouting = CallVibrationRoutingResult(pattern: nil, reason: .disabled, safeMessage: "No call vibration routed.")
            lastCallStateEventMessage = "No cellular call event received in this app session."
            activeCellularCall = nil
            isCellularCallVibrationActive = false
            alarms = []
            activeAlarm = nil
            bodyProfile = BodyProfile()
            skinTemperatureBaselineProfile = SkinTemperatureBaselineProfile()
            updateWearableSyntheticCalibrationContext()
            cancelCallVibrationLoop()
            cancelAlarmVibrationLoop()
            cancelAlarmMonitor()
            return
        }
        vibrationPatterns = await localStore.loadVibrationPatterns()
        callVibrationSettings = Self.standardizedCallSettings(await localStore.loadCallVibrationSettings())
        if let fallback = cachedCallVibrationSettings(),
           fallback.lastUpdatedAt > callVibrationSettings.lastUpdatedAt {
            callVibrationSettings = fallback
            try? await localStore.saveCallVibrationSettings(fallback)
        }
        hasLoadedCallVibrationSettings = true

        consentState = await localStore.loadConsentState()
        let loadedTodaySnapshot = await localStore.loadTodaySummary()
        todaySnapshot = normalizedTodaySnapshot(loadedTodaySnapshot)
        if todaySnapshot != loadedTodaySnapshot {
            await localStore.saveTodaySummary(todaySnapshot)
        }
        bodyProfile = await localStore.loadBodyProfile()
        skinTemperatureBaselineProfile = await localStore.loadSkinTemperatureBaselineProfile()
        await refreshTodaySummaryFromStoredSamples(preserveExistingWhenNoSamples: true)
        alarms = await localStore.loadAlarms()
        await triggerDueAlarms(now: now())
        scheduleNextAlarmMonitor()
        await rescheduleUpcomingAlarmNotifications()
        await refreshRecentSummaries()
        updateWearableSyntheticCalibrationContext()
        hasLoadedApprovedLocalState = true
    }

    func loadMetricDetailTimeline(
        for metricID: WhoordanMetricID,
        days: Int = 30,
        sampleLimit: Int = 160
    ) async -> MetricDetailTimeline {
        let rangeEnd = now()
        let boundedDays = max(1, min(days, 90))
        let boundedLimit = max(1, min(sampleLimit, 500))
        let rangeStart = Calendar.current.date(
            byAdding: .day,
            value: -boundedDays,
            to: rangeEnd
        ) ?? rangeEnd.addingTimeInterval(Double(-boundedDays) * 86_400)
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else {
            return .empty(metricID: metricID, rangeStart: rangeStart, rangeEnd: rangeEnd)
        }

        let sampleTypes = Self.lazySampleTypes(for: metricID)
        guard !sampleTypes.isEmpty else {
            return summaryTimeline(
                for: metricID,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                sampleLimit: boundedLimit
            )
        }

        let samples = await localStore.loadHealthSamples(
            types: sampleTypes,
            sources: DeviceMetricSourcePolicy.queryableProductionSources,
            start: rangeStart,
            end: rangeEnd,
            limit: boundedLimit + 1
        )

        let sorted = DeviceMetricSourcePolicy.productionSamples(from: samples)
            .sorted { $0.startDate < $1.startDate }
        let limited = Array(sorted.suffix(boundedLimit))
        return MetricDetailTimeline(
            metricID: metricID,
            points: limited.map(Self.timelinePoint(for:)),
            sampleTypesLoaded: sampleTypes,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            wasLimited: sorted.count > limited.count
        )
    }

    func updateConsent(_ mutate: (inout ConsentState) -> Void) {
        var updated = consentState
        mutate(&updated)
        updated = updated.normalizedForCurrentPrivacyModel
        consentState = updated
        Task {
            await localStore.saveConsentState(updated)
            await syncAccountStateIfAllowed(
                applyRemote: privacyGuard.canRestoreSettingsData(approval: approvalState, consent: updated)
            )
            await syncAppleHealthWritesIfAllowed()
            if privacyGuard.canRestoreHealthData(approval: approvalState, consent: updated) {
                await syncHealthDataIfAllowed(restoreCloudSamples: true)
            } else {
                cloudRestoredDailySummaries = [:]
                await refreshRecentSummaries()
            }
        }
    }

    func setCloudSyncEnabled(_ enabled: Bool) {
        updateConsent {
            $0.localModeEnabled = true
            $0.cloudSyncEnabled = enabled
            $0.healthDataCloudConsent = enabled
            $0.cloudSyncPromptDismissed = true
        }
    }

    func enableCloudHealthSyncFromPrompt() {
        setCloudSyncEnabled(true)
        isCloudSyncConsentPromptPresented = false
        Task { await requestRemainingStartupPermissionsAfterCloudPrompt(requestBluetooth: false) }
    }

    func keepHealthDataLocalFromPrompt() {
        updateConsent {
            $0.cloudSyncPromptDismissed = true
        }
        isCloudSyncConsentPromptPresented = false
        Task { await requestRemainingStartupPermissionsAfterCloudPrompt(requestBluetooth: false) }
    }

    private func markCloudSyncPromptDismissedIfNeeded() async {
        guard !consentState.cloudSyncPromptDismissed else { return }
        var updated = consentState
        updated.cloudSyncPromptDismissed = true
        updated = updated.normalizedForCurrentPrivacyModel
        consentState = updated
        await localStore.saveConsentState(updated)
    }

    func requestHealthKit() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            healthKitResult = HealthKitAuthorizationResult(status: .approvalRequired, requestedTypes: [], message: "Apple Health export is available after account approval.")
            authMessage = "Apple Health export is available after account approval."
            return
        }
        healthKitResult = await healthKitService.requestWriteAuthorization()
        if healthKitResult.status == .requested || healthKitResult.status == .authorized || healthKitResult.status == .partial {
            var updated = consentState
            updated.appleHealthEnabled = true
            updated = updated.normalizedForCurrentPrivacyModel
            consentState = updated
            await localStore.saveConsentState(updated)
            await syncAccountStateIfAllowed(applyRemote: false)
            await syncAppleHealthWritesNow()
        }
    }

    func refreshNotificationPermission() async {
        notificationPermissionResult = await notificationPermissionService.currentAuthorization()
    }

    func requestNotificationPermission() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            notificationPermissionResult = NotificationPermissionResult(
                status: .unavailable,
                message: "Notifications are available after account approval."
            )
            return
        }
        notificationPermissionResult = await notificationPermissionService.requestAuthorization()
    }

    func handleScenePhaseChange(_ phase: AppLifecyclePhase) {
        switch phase {
        case .active:
            cancelOperationalNotification(kind: .openAppReminder)
        case .inactive:
            cancelOperationalNotification(kind: .openAppReminder)
        case .background:
            cancelOperationalNotification(kind: .openAppReminder)
            startApprovedServicesIfAllowed()
            Task { [weak self] in
                guard let self else { return }
                await backgroundTaskManager.withBackgroundTask(named: "whoordan.background.flush") { [weak self] in
                    guard let self else { return }
                    await self.flushPendingCallVibrationSettingsPersistence()
                    await self.flushPendingAlarmPersistence()
                    await self.rescheduleUpcomingAlarmNotifications()
                    await self.syncAccountSettingsNow()
                    await self.syncAppleHealthWritesIfAllowed()
                    await self.syncHealthDataIfAllowed()
                }
            }
        }
    }

    func refreshHealthKitSamples() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            healthKitResult = HealthKitAuthorizationResult(status: .approvalRequired, requestedTypes: [], message: "Apple Health export is available after account approval.")
            return
        }
        lastImportedHealthSamples = []
        healthKitImportedSampleCount = 0
        healthKitResult = HealthKitAuthorizationResult(
            status: consentState.appleHealthEnabled ? .authorized : healthKitResult.status,
            requestedTypes: healthKitService.supportedWriteTypes(),
            message: "Apple Health is export-only. Whoordan writes supported source-labeled samples when available."
        )
    }

    func syncHealthDataNow(uploadDailySummary: Bool = true) async {
        guard privacyGuard.canUploadHealthData(approval: approvalState, consent: consentState) else {
            healthSyncResult = HealthSyncResult(status: .blocked, sampleCount: 0, message: "Cloud health sync requires approval and cloud sync enabled.")
            return
        }
        let syncStartedAt = now()
        _ = try? await localStore.repairSupabaseQueue(now: syncStartedAt, userID: session?.userID)

        var uploadedCount = 0
        let maxBatches = 50
        for _ in 0..<maxBatches {
            let currentTime = now()
            let pending = await localStore.pendingSupabaseUploads(limit: 500, now: currentTime)
            let samples = pending.map(\.sample)
            guard !samples.isEmpty else {
                if uploadDailySummary {
                    let summaryResult = await syncDailySummaryCacheIfAvailable()
                    if summaryResult.status == .uploaded {
                        healthSyncResult = uploadedCount == 0
                            ? summaryResult
                            : HealthSyncResult(status: .uploaded, sampleCount: uploadedCount, message: "Uploaded \(uploadedCount) queued local health samples and refreshed the daily summary cache.")
                        return
                    }
                }
                healthSyncResult = uploadedCount == 0
                    ? HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "No locally persisted health samples are queued for cloud sync.")
                    : HealthSyncResult(status: .uploaded, sampleCount: uploadedCount, message: "Uploaded \(uploadedCount) queued local health samples.")
                return
            }

            let result = await healthSyncService.uploadHealthSamples(
                samples,
                session: session,
                approval: approvalState,
                consent: consentState
            )
            let keys = pending.map(\.dedupeKey)
            switch result.status {
            case .uploaded:
                uploadedCount += result.sampleCount
                try? await localStore.markSupabaseUploadsUploaded(dedupeKeys: keys, syncedAt: now())
            case .failed:
                try? await localStore.markSupabaseUploadsFailed(dedupeKeys: keys, error: result.message, now: now())
                healthSyncResult = result
                return
            case .blocked, .nothingToSync:
                healthSyncResult = result
                return
            }
        }

        healthSyncResult = HealthSyncResult(
            status: .uploaded,
            sampleCount: uploadedCount,
            message: "Uploaded \(uploadedCount) queued local health samples. More historical samples remain queued and will continue syncing automatically."
        )
    }

    private func syncDailySummaryCacheIfAvailable() async -> HealthSyncResult {
        guard todaySnapshot.hasSyncableContent else {
            return HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "No daily metric summary is ready to sync.")
        }
        return await healthSyncService.uploadDailySummary(
            todaySnapshot,
            metricSnapshots: readyMetricSnapshotsForCloud(summary: todaySnapshot),
            session: session,
            approval: approvalState,
            consent: consentState
        )
    }

    private func restoreCloudMetricSummariesIfAvailable(days: Int = 3_650) async -> Bool {
        guard privacyGuard.canRestoreHealthData(approval: approvalState, consent: consentState) else {
            cloudRestoredDailySummaries = [:]
            return false
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        let since = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        let result = await healthSyncService.fetchRecentDailySummaries(
            session: session,
            approval: approvalState,
            consent: consentState,
            since: since,
            limit: days
        )
        guard result.status == .restored, !result.summaries.isEmpty else { return false }
        await applyCloudMetricSummaries(result.summaries, days: days, calendar: calendar)
        return true
    }

    private func restoreCloudHealthSamplesIfAvailable(days: Int = 3_650, limit: Int = 25_000) async -> Bool {
        guard privacyGuard.canRestoreHealthData(approval: approvalState, consent: consentState) else {
            return false
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        let since = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        let result = await healthSyncService.fetchRecentHealthSamples(
            session: session,
            approval: approvalState,
            consent: consentState,
            since: since,
            limit: limit
        )
        guard result.status == .restored, !result.samples.isEmpty else { return false }
        let summaryBeforeSampleRestore = todaySnapshot
        let ingestion = await ingestionPipeline.ingest(
            samples: result.samples,
            origin: .cloudRestore,
            approval: approvalState,
            consent: consentState,
            userID: session?.userID,
            localStore: localStore,
            scoringService: scoringService,
            priorSummary: todaySnapshot,
            calendar: calendar,
            now: now()
        )
        if let updated = ingestion.updatedSummary {
            let merged = Self.preferredMetricSummary(local: updated, remote: summaryBeforeSampleRestore)
            todaySnapshot = merged
            await localStore.saveTodaySummary(merged)
        }
        await refreshRecentSummaries(days: days)
        return true
    }

    private func applyCloudMetricSummaries(_ summaries: [DailyHealthSummary], days: Int, calendar: Calendar) async {
        guard !summaries.isEmpty else { return }
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.date)
            let scored = scoringService.score(summary: summary, bodyProfile: bodyProfile)
            if let existing = cloudRestoredDailySummaries[day] {
                cloudRestoredDailySummaries[day] = Self.preferredMetricSummary(local: existing, remote: scored)
            } else {
                cloudRestoredDailySummaries[day] = scored
            }
        }

        let today = calendar.startOfDay(for: now())
        let localToday = normalizedTodaySnapshot(todaySnapshot, calendar: calendar)
        if localToday != todaySnapshot {
            todaySnapshot = localToday
            await localStore.saveTodaySummary(localToday)
        }
        if let restoredToday = cloudRestoredDailySummaries[today] {
            let preferred = Self.preferredMetricSummary(local: localToday, remote: restoredToday)
            if preferred != todaySnapshot {
                todaySnapshot = preferred
                await localStore.saveTodaySummary(preferred)
            }
        }
        publishRecentSummaries(localSummaries: recentSummaries, days: days, calendar: calendar)
    }

    private func readyMetricSnapshotsForCloud(summary: DailyHealthSummary) -> [WhoordanMetricSnapshot] {
        WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: deviceState,
            baselineProfile: skinTemperatureBaselineProfile,
            bodyProfile: bodyProfile,
            recentSummaries: recentSummaries,
            now: now()
        )
        .filter { $0.readiness != .laterBlocked && $0.value != nil }
    }

    func syncAppleHealthWritesNow() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            healthKitResult = HealthKitAuthorizationResult(status: .approvalRequired, requestedTypes: [], message: "Apple Health export is available after account approval.")
            return
        }
        guard consentState.appleHealthEnabled else {
            healthKitResult = HealthKitAuthorizationResult(status: .notDetermined, requestedTypes: healthKitService.supportedWriteTypes(), message: "Apple Health export is off.")
            return
        }

        _ = try? await localStore.repairAppleHealthWriteQueue(now: now())
        let pending = await localStore.pendingAppleHealthWrites(limit: 100)
        let pendingSamples = pending.compactMap { item -> (item: AppleHealthWriteQueueItem, sample: HealthSample)? in
            guard let sample = item.sample else { return nil }
            return (item, sample)
        }
        let samples = pendingSamples.map { $0.sample }
        guard !samples.isEmpty else {
            healthKitResult = HealthKitAuthorizationResult(
                status: .authorized,
                requestedTypes: healthKitService.supportedWriteTypes(),
                message: "Apple Health export is enabled. No supported Whoordan-created samples are queued."
            )
            return
        }

        let result = await healthKitService.writeSamples(samples)
        let keys = pendingSamples.map { $0.item.dedupeKey }
        let keyBySampleDedupeID = Dictionary(uniqueKeysWithValues: pendingSamples.map { ($0.sample.dedupeID, $0.item.dedupeKey) })
        let writtenKeys = result.writtenDedupeIDs.isEmpty && result.status == .written
            ? keys
            : result.writtenDedupeIDs.compactMap { keyBySampleDedupeID[$0] }
        let notAuthorizedKeys = result.notAuthorizedDedupeIDs.isEmpty && result.status == .notAuthorized
            ? keys
            : result.notAuthorizedDedupeIDs.compactMap { keyBySampleDedupeID[$0] }
        let notAuthorizedKeySet = Set(notAuthorizedKeys)
        let failedKeys = keys.filter { !notAuthorizedKeySet.contains($0) }
        switch result.status {
        case .written:
            healthKitExportedSampleCount += result.writtenCount
            try? await localStore.markAppleHealthWritesWritten(dedupeKeys: writtenKeys, writtenAt: now())
            try? await localStore.markAppleHealthWritesNotAuthorized(dedupeKeys: notAuthorizedKeys, error: result.message, now: now())
            healthKitResult = HealthKitAuthorizationResult(
                status: notAuthorizedKeys.isEmpty ? .authorized : .partial,
                requestedTypes: healthKitService.supportedWriteTypes(),
                message: result.message
            )
        case .nothingToWrite, .unsupported:
            healthKitResult = HealthKitAuthorizationResult(
                status: .authorized,
                requestedTypes: healthKitService.supportedWriteTypes(),
                message: result.message
            )
        case .notAuthorized:
            try? await localStore.markAppleHealthWritesNotAuthorized(dedupeKeys: notAuthorizedKeys, error: result.message, now: now())
            healthKitResult = HealthKitAuthorizationResult(status: .partial, requestedTypes: healthKitService.supportedWriteTypes(), message: result.message)
        case .failed:
            try? await localStore.markAppleHealthWritesNotAuthorized(dedupeKeys: notAuthorizedKeys, error: result.message, now: now())
            try? await localStore.markAppleHealthWritesFailed(dedupeKeys: failedKeys, error: result.message, now: now())
            healthKitResult = HealthKitAuthorizationResult(status: .failed, requestedTypes: healthKitService.supportedWriteTypes(), message: result.message)
        }
    }

    private func syncHealthDataIfAllowed(
        restoreCloudSamples: Bool = false,
        uploadAfterRestore: Bool = true
    ) async {
        var attemptedRestore = false
        var restoredCloudData = false
        if privacyGuard.canRestoreHealthData(approval: approvalState, consent: consentState) {
            attemptedRestore = true
            restoredCloudData = await restoreCloudMetricSummariesIfAvailable()
            if restoreCloudSamples {
                let restoredSamples = await restoreCloudHealthSamplesIfAvailable()
                restoredCloudData = restoredSamples || restoredCloudData
            }
        } else {
            cloudRestoredDailySummaries = [:]
        }

        if attemptedRestore, !uploadAfterRestore {
            if privacyGuard.canUploadHealthData(approval: approvalState, consent: consentState) {
                await syncHealthDataNow(uploadDailySummary: restoredCloudData)
            }
            return
        }

        if privacyGuard.canUploadHealthData(approval: approvalState, consent: consentState) {
            await syncHealthDataNow()
        }
    }

    func syncAccountSettingsNow() async {
        await syncAccountStateIfAllowed(applyRemote: false)
    }

    func prepareLocalDataExport() async {
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else {
            privacyActionMessage = "Local data export is available after account approval."
            return
        }

        do {
            let exportURL = try await localStore.exportLocalUserData(createdAt: now())
            localDataExportURL = exportURL
            privacyActionMessage = "Local data export is ready to share. Review it before sending."
        } catch {
            localDataExportURL = nil
            privacyActionMessage = "Unable to prepare local data export."
        }
    }

    func eraseLocalDataAndSignOut() async {
        await signOut()
        privacyActionMessage = "Local Whoordan data on this device was erased and you were signed out."
    }

    func requestAccountDeletion() async {
        guard session != nil else {
            privacyActionMessage = "Sign in before requesting account deletion."
            return
        }
        let result = await accountSyncService.requestAccountDeletion(session: session)
        accountSyncResult = result
        privacyActionMessage = result.message
    }

    private func syncAccountStateIfAllowed(
        applyRemote: Bool,
        uploadAfterRemote: Bool = true
    ) async {
        if applyRemote, privacyGuard.canRestoreSettingsData(approval: approvalState, consent: consentState) {
            if let remote = await accountSyncService.fetchAccountSnapshot(
                session: session,
                approval: approvalState,
                includeHealthBaselines: privacyGuard.canRestoreHealthData(approval: approvalState, consent: consentState)
            ) {
                await applyRemoteAccountSnapshot(remote)
            }
            if !uploadAfterRemote {
                return
            }
        }
        guard privacyGuard.canUploadSettingsData(approval: approvalState, consent: consentState) else {
            return
        }
        let snapshot = currentAccountSnapshot()
        accountSyncResult = await accountSyncService.uploadAccountSnapshot(
            snapshot,
            session: session,
            approval: approvalState
        )
    }

    private func currentAccountSnapshot() -> AccountSyncSnapshot {
        AccountSyncSnapshot(
            email: session?.email,
            bodyProfile: bodyProfile,
            consentState: consentState,
            skinTemperatureBaselineProfile: privacyGuard.canUploadHealthData(approval: approvalState, consent: consentState)
                ? skinTemperatureBaselineProfile
                : nil,
            callVibrationSettings: callVibrationSettings,
            alarms: alarms,
            themePreference: UserDefaults.standard.string(forKey: AppThemePreference.storageKey) ?? AppThemePreference.system.rawValue,
            movementGoal: todaySnapshot.movement.goal,
            updatedAt: now()
        )
    }

    private func applyRemoteAccountSnapshot(_ snapshot: AccountSyncSnapshot) async {
        let remoteDate = snapshot.updatedAt ?? .distantPast
        let localProfileDate = bodyProfile.updatedAt ?? .distantPast
        if snapshot.includesProfile, !snapshot.bodyProfile.isEmpty, remoteDate >= localProfileDate {
            try? await localStore.saveBodyProfile(snapshot.bodyProfile, updatedAt: remoteDate)
            bodyProfile = await localStore.loadBodyProfile()
            todaySnapshot = scoringService.score(summary: todaySnapshot, bodyProfile: bodyProfile)
            await localStore.saveTodaySummary(todaySnapshot)
        }

        guard snapshot.includesSettings else {
            await refreshRecentSummaries()
            updateWearableSyntheticCalibrationContext()
            return
        }

        let mergedConsent = accountSyncedConsent(from: snapshot.consentState)
        if consentState != mergedConsent {
            consentState = mergedConsent
            await localStore.saveConsentState(consentState)
        }

        if privacyGuard.canRestoreHealthData(approval: approvalState, consent: consentState),
           let remoteBaseline = snapshot.skinTemperatureBaselineProfile,
           Self.shouldApplyRemoteBaseline(remoteBaseline, over: skinTemperatureBaselineProfile) {
            try? await localStore.saveSkinTemperatureBaselineProfile(remoteBaseline)
            skinTemperatureBaselineProfile = await localStore.loadSkinTemperatureBaselineProfile()
            todaySnapshot = scoringService.score(summary: todaySnapshot, bodyProfile: bodyProfile)
            await localStore.saveTodaySummary(todaySnapshot)
        }

        if snapshot.callVibrationSettings.lastUpdatedAt >= callVibrationSettings.lastUpdatedAt {
            callVibrationSettings = Self.standardizedCallSettings(snapshot.callVibrationSettings)
            cacheCallVibrationSettings(callVibrationSettings)
            hasLoadedCallVibrationSettings = true
            try? await localStore.saveCallVibrationSettings(callVibrationSettings)
        }

        if snapshot.alarms != alarms {
            alarms = snapshot.alarms.sorted { lhs, rhs in
                switch (lhs.nextTriggerAt, rhs.nextTriggerAt) {
                case let (left?, right?):
                    return left < right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return lhs.label < rhs.label
                }
            }
            try? await localStore.replaceAlarms(alarms)
            await triggerDueAlarms(now: now())
            scheduleNextAlarmMonitor()
            await rescheduleUpcomingAlarmNotifications()
        }

        if AppThemePreference(rawValue: snapshot.themePreference) != nil,
           UserDefaults.standard.string(forKey: AppThemePreference.storageKey) != snapshot.themePreference {
            UserDefaults.standard.set(snapshot.themePreference, forKey: AppThemePreference.storageKey)
        }

        if snapshot.movementGoal != todaySnapshot.movement.goal {
            todaySnapshot.movement.goal = min(max(snapshot.movementGoal, 1_000), 40_000)
            todaySnapshot = scoringService.score(summary: todaySnapshot, bodyProfile: bodyProfile)
            await localStore.saveTodaySummary(todaySnapshot)
        }

        await refreshRecentSummaries()
        updateWearableSyntheticCalibrationContext()
    }

    private static func shouldApplyRemoteBaseline(
        _ remote: SkinTemperatureBaselineProfile,
        over local: SkinTemperatureBaselineProfile
    ) -> Bool {
        let remote = remote.sanitizedForCloudSync
        guard remote.isMeaningfulForCloudSync else { return false }
        let local = local.sanitizedForCloudSync
        guard local.isMeaningfulForCloudSync else { return true }
        return remote.cloudConflictUpdatedAt >= local.cloudConflictUpdatedAt
    }

    private func accountSyncedConsent(from remoteConsent: ConsentState) -> ConsentState {
        let remoteConsent = remoteConsent.normalizedForCurrentPrivacyModel
        let cloudSyncEnabled = consentState.cloudSyncEnabled || remoteConsent.cloudSyncEnabled
        let healthDataCloudConsent = consentState.healthDataCloudConsent && cloudSyncEnabled
        let cloudSyncPromptDismissed = consentState.cloudSyncPromptDismissed
            || remoteConsent.cloudSyncPromptDismissed
            || remoteConsent.cloudSyncEnabled
        return ConsentState(
            cloudSyncEnabled: cloudSyncEnabled,
            healthDataCloudConsent: healthDataCloudConsent,
            appleHealthEnabled: remoteConsent.appleHealthEnabled,
            cloudSyncPromptDismissed: cloudSyncPromptDismissed
        )
    }

    private func syncAppleHealthWritesIfAllowed() async {
        if privacyGuard.canStartProtectedService(approval: approvalState), consentState.appleHealthEnabled {
            await syncAppleHealthWritesNow()
        }
    }

    func updateStepGoal(_ goal: Int) {
        let bounded = min(max(goal, 1_000), 40_000)
        todaySnapshot.movement.goal = bounded
        todaySnapshot = scoringService.score(summary: todaySnapshot, bodyProfile: bodyProfile)
        let snapshot = todaySnapshot
        Task {
            await localStore.saveTodaySummary(snapshot)
            await refreshRecentSummaries()
            await syncAccountStateIfAllowed(applyRemote: false)
        }
    }

    func updateBodyProfile(_ profile: BodyProfile) {
        Task {
            do {
                try await localStore.saveBodyProfile(profile, updatedAt: now())
                bodyProfile = await localStore.loadBodyProfile()
                todaySnapshot = scoringService.score(summary: todaySnapshot, bodyProfile: bodyProfile)
                await localStore.saveTodaySummary(todaySnapshot)
                await refreshRecentSummaries()
                await syncAccountStateIfAllowed(applyRemote: false)
            } catch {
                authMessage = error.localizedDescription
            }
        }
    }

    func updateTemporarySkinTemperatureBaselineC(_ value: Double?) {
        guard skinTemperatureBaselineProfile.canEditTemporaryBaseline else { return }
        Task {
            do {
                try await localStore.saveTemporarySkinTemperatureBaselineC(value, updatedAt: now())
                skinTemperatureBaselineProfile = await localStore.loadSkinTemperatureBaselineProfile()
                await refreshTodaySummaryFromStoredSamples()
                await refreshRecentSummaries()
                await syncAccountStateIfAllowed(applyRemote: false)
            } catch {
                authMessage = error.localizedDescription
            }
        }
    }

    func scanForWearable() {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            return
        }
        bleService.startScanning()
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func requestBluetoothAccess() {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            return
        }
        bleService.requestBluetoothAccess()
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func primeBluetoothPermissionIfNeeded() {
        guard !didPrimeBluetoothPermission else { return }
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        didPrimeBluetoothPermission = true
        bleService.primeBluetoothPermission()
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func retryBluetoothPermissionProbe() {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        bleService.primeBluetoothPermission()
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func connectToWearable(_ candidate: WearableDeviceCandidate) {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            return
        }
        bleService.connect(to: candidate)
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func startWearableCapture(scenario: WearableCaptureScenario) {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            deviceState.rawCapture.lastError = "Approval is required before wearable capture."
            return
        }
        bleService.startRawCapture(scenario: scenario)
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func updateWearableCaptureScenario(_ scenario: WearableCaptureScenario) {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            return
        }
        bleService.updateRawCaptureScenario(scenario)
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func stopWearableCapture() {
        bleService.stopRawCapture()
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func finishWearableCapture(recordingName: String) {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            deviceState.rawCapture.lastError = "Approval is required before wearable capture."
            return
        }
        guard !recordingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            deviceState.rawCapture.lastError = "Name the recording before saving it."
            return
        }
        _ = bleService.finishRawCapture(recordingName: recordingName)
        publishWearableStateImmediately(bleService.currentDeviceState)
    }

    func exportWearableCaptureArchive() -> URL? {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            deviceState.connection = .approvalRequired
            deviceState.rawCapture.lastError = "Approval is required before exporting wearable capture logs."
            return nil
        }
        do {
            let url = try bleService.exportRawCaptureArchive()
            deviceState.rawCapture.lastError = nil
            return url
        } catch {
            deviceState.rawCapture.lastError = "Unable to create BLE log export archive."
            return nil
        }
    }

    func startApprovedServicesIfAllowed() {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        callStateObserver?.start()
        scheduleNextAlarmMonitor()
        backgroundSyncCoordinator.schedule()
        switch deviceState.connection {
        case .idle, .disconnected, .error:
            bleService.startAutoConnect()
            publishWearableStateImmediately(bleService.currentDeviceState)
        case .approvalRequired, .scanning, .connecting, .discoveringServices, .subscribing, .initializing, .historicalSync, .realtime:
            break
        }
    }

    func requestStartupPermissionsIfNeeded() async {
        guard !didRunStartupPermissionRequest,
              !isRestoring,
              hasLoadedApprovedLocalState,
              privacyGuard.canStartProtectedService(approval: approvalState) else {
            return
        }
        didRunStartupPermissionRequest = true
        requestBluetoothAccess()

        if !consentState.cloudSyncPromptDismissed, !consentState.canUploadHealthData {
            await markCloudSyncPromptDismissedIfNeeded()
            isCloudSyncConsentPromptPresented = true
            return
        }

        await requestRemainingStartupPermissionsAfterCloudPrompt(requestBluetooth: false)
    }

    private func requestRemainingStartupPermissionsAfterCloudPrompt(requestBluetooth: Bool = true) async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        if requestBluetooth {
            requestBluetoothAccess()
        }
        await requestHealthKit()
        await requestNotificationPermission()
    }

    func preview(pattern: VibrationPattern) async {
        _ = pattern
        lastVibrationResult = await playStandardVibration()
    }

    private func playStandardVibration(pattern: VibrationPattern? = nil) async -> VibrationPreviewResult {
        guard !standardVibrationInFlight else { return lastVibrationResult }
        standardVibrationInFlight = true
        defer { standardVibrationInFlight = false }
        let selectedPattern = pattern ?? VibrationPattern.standardPattern(from: vibrationPatterns)
        return await hapticService.preview(
            selectedPattern,
            approval: approvalState,
            device: bleService.currentDeviceState
        )
    }

    func saveCallVibrationSettings(_ settings: CallVibrationSettings) {
        var updated = Self.standardizedCallSettings(settings)
        updated.lastUpdatedAt = now()
        callVibrationSettings = updated
        hasLoadedCallVibrationSettings = true
        cacheCallVibrationSettings(updated)
        if updated.enabled {
            startApprovedServicesIfAllowed()
        }
        callVibrationSettingsPersistenceTask?.cancel()
        callVibrationSettingsPersistenceTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            try? await self.localStore.saveCallVibrationSettings(updated)
            guard !Task.isCancelled, self.callVibrationSettings == updated else { return }
            self.callVibrationSettingsPersistenceTask = nil
            await self.syncAccountStateIfAllowed(applyRemote: false)
        }
    }

    private func flushPendingCallVibrationSettingsPersistence() async {
        guard let task = callVibrationSettingsPersistenceTask else { return }
        await task.value
    }

    private func cachedCallVibrationSettings() -> CallVibrationSettings? {
        guard let data = UserDefaults.standard.data(forKey: Self.callVibrationSettingsFallbackStorageKey),
              let entry = try? JSONDecoder.whoordan.decode(CachedCallVibrationSettings.self, from: data),
              entry.userID == session?.userID else {
            return nil
        }
        return Self.standardizedCallSettings(entry.settings)
    }

    private func cacheCallVibrationSettings(_ settings: CallVibrationSettings) {
        let entry = CachedCallVibrationSettings(userID: session?.userID, settings: settings)
        guard let data = try? JSONEncoder.whoordan.encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: Self.callVibrationSettingsFallbackStorageKey)
    }

    private func clearCachedCallVibrationSettings() {
        UserDefaults.standard.removeObject(forKey: Self.callVibrationSettingsFallbackStorageKey)
    }

    private static func standardizedCallSettings(_ settings: CallVibrationSettings) -> CallVibrationSettings {
        var updated = settings
        updated.patternID = VibrationPattern.standardID
        updated.supportsDecline = false
        updated.platformStatus = .normalCellularPlatformBlocked
        return updated
    }

    func receiveCallStateEvent(_ event: CallStateEvent) async {
        lastCallStateEventMessage = event.diagnosticDescription
        switch event {
        case let .incomingCellularRinging(id, receivedAt):
            await routeIncomingCellularCall(id: id, receivedAt: receivedAt)
        case let .cellularCallConnected(id), let .cellularCallEnded(id):
            await clearCellularCall(id: id)
        }
    }

    func routeIncomingCellularCall(id: UUID = UUID(), receivedAt: Date = Date()) async {
        let activeCall = ActiveCallContext(id: id, kind: .normalCellular, receivedAt: receivedAt)
        let result = CallVibrationRouter.routeIncomingCellularCall(
            settings: callVibrationSettings,
            patterns: vibrationPatterns,
            approval: approvalState,
            device: bleService.currentDeviceState
        )
        lastCallVibrationRouting = result
        guard let pattern = result.pattern else {
            isCellularCallVibrationActive = false
            cancelCallVibrationLoop()
            return
        }
        activeCellularCall = activeCall
        lastVibrationResult = await playStandardVibration(pattern: pattern)
        isCellularCallVibrationActive = lastVibrationResult.status == .started || lastVibrationResult.status == .fired
        if isCellularCallVibrationActive {
            startCallVibrationLoop(callID: id)
        }
    }

    private func startCallVibrationLoop(callID: UUID) {
        cancelCallVibrationLoop()
        let interval = vibrationRepeatIntervalNanoseconds
        let delay = vibrationRepeatDelay
        callVibrationRepeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await delay(interval)
                guard !Task.isCancelled else { return }
                await self?.repeatCallVibrationIfActive(callID: callID)
            }
        }
    }

    private func repeatCallVibrationIfActive(callID: UUID) async {
        guard activeCellularCall?.id == callID, isCellularCallVibrationActive else {
            cancelCallVibrationLoop()
            return
        }
        let result = await playStandardVibration()
        lastVibrationResult = result
        if result.status != .started && result.status != .fired {
            isCellularCallVibrationActive = false
            cancelCallVibrationLoop()
        }
    }

    private func cancelCallVibrationLoop() {
        callVibrationRepeatTask?.cancel()
        callVibrationRepeatTask = nil
    }

    func receiveWearableEvent(_ event: WearableEventPacket) async {
        guard event.kind == .doubleTap else { return }
        await routeDoubleTap(action: .declineCallWhereSupported)
    }

    private func clearCellularCall(id: UUID?) async {
        guard activeCellularCall == nil || activeCellularCall?.id == id else { return }
        activeCellularCall = nil
        cancelCallVibrationLoop()
        guard isCellularCallVibrationActive else { return }
        await hapticService.cancel()
        isCellularCallVibrationActive = false
        lastVibrationResult = VibrationPreviewResult(
            status: .terminated,
            message: "Wearable call vibration stopped."
        )
    }

    func saveAlarm(_ alarm: Alarm) {
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else {
            lastAlarmSchedulingResult = AlarmSchedulingResult(status: .approvalRequired, message: "Approval is required before alarms.", scheduledAt: nil)
            return
        }
        var updated = alarm
        updated.syncStatus = SettingsSyncPolicy.status(approval: approvalState, consent: consentState, userID: session?.userID)
        updated.nextTriggerAt = AlarmScheduler.nextTrigger(for: updated)
        updated.deliveryStatus = updated.enabled ? .scheduled : .dismissed
        let disabledActiveAlarm = activeAlarm?.id == updated.id && !updated.enabled
        if disabledActiveAlarm {
            activeAlarm = nil
            cancelAlarmVibrationLoop()
        }
        upsertAlarm(updated)
        scheduleNextAlarmMonitor()
        alarmPersistenceTask?.cancel()
        alarmPersistenceTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            if disabledActiveAlarm {
                await self.hapticService.cancel()
            }
            try? await self.localStore.saveAlarm(updated)
            guard !Task.isCancelled else { return }
            if updated.enabled {
                self.lastAlarmSchedulingResult = await self.alarmScheduler.scheduleLocalNotification(for: updated)
            } else {
                await self.alarmScheduler.cancelLocalNotification(alarmID: updated.id)
                self.lastAlarmSchedulingResult = AlarmSchedulingResult(status: .canceled, message: "Alarm disabled.", scheduledAt: nil)
            }
            guard !Task.isCancelled else { return }
            self.alarmPersistenceTask = nil
            await self.syncAccountStateIfAllowed(applyRemote: false)
        }
    }

    func deleteAlarm(id: UUID) {
        alarms.removeAll { $0.id == id }
        if activeAlarm?.id == id {
            activeAlarm = nil
            cancelAlarmVibrationLoop()
        }
        scheduleNextAlarmMonitor()
        Task {
            await hapticService.cancel()
            await alarmScheduler.cancelLocalNotification(alarmID: id)
            try? await localStore.deleteAlarm(id: id)
            await syncAccountStateIfAllowed(applyRemote: false)
        }
        scheduleNextAlarmMonitor()
    }

    func triggerDueAlarms(now: Date = Date()) async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        let due = alarms.filter { alarm in
            alarm.enabled && (alarm.nextTriggerAt.map { $0 <= now } ?? false)
        }
        for alarm in due {
            await triggerAlarm(alarm, now: now)
        }
    }

    func triggerAlarm(_ alarm: Alarm, now: Date = Date()) async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            lastAlarmSchedulingResult = AlarmSchedulingResult(status: .approvalRequired, message: "Approval is required before wearable alarm delivery.", scheduledAt: nil)
            return
        }
        var triggered = AlarmScheduler.trigger(alarm, now: now)
        activeAlarm = triggered
        let pattern = VibrationPattern.standardPattern(from: vibrationPatterns)
        if bleService.currentDeviceState.connection == .realtime || bleService.currentDeviceState.connection == .historicalSync {
            let result = await playStandardVibration(pattern: pattern)
            lastVibrationResult = result
            let status: AlarmDeliveryStatus = result.status == .started || result.status == .fired ? .deliveredToWearable : .failed
            triggered = AlarmScheduler.markDelivery(triggered, status: status, now: now)
            if status == .deliveredToWearable {
                startAlarmVibrationLoop(alarmID: alarm.id)
            } else {
                cancelAlarmVibrationLoop()
            }
            lastAlarmSchedulingResult = AlarmSchedulingResult(
                status: status == .deliveredToWearable ? .scheduled : .failed,
                message: result.safeMessage,
                scheduledAt: nil
            )
        } else {
            cancelAlarmVibrationLoop()
            triggered = AlarmScheduler.markDelivery(triggered, status: .wearableDisconnected, now: now)
            lastAlarmSchedulingResult = AlarmSchedulingResult(status: .unsupported, message: "Wearable disconnected at alarm time.", scheduledAt: nil)
        }
        activeAlarm = triggered
        upsertAlarm(triggered)
        try? await localStore.saveAlarm(triggered)
        await syncAccountStateIfAllowed(applyRemote: false)
        scheduleNextAlarmMonitor()
    }

    private func startAlarmVibrationLoop(alarmID: UUID) {
        cancelAlarmVibrationLoop()
        let interval = vibrationRepeatIntervalNanoseconds
        let delay = vibrationRepeatDelay
        alarmVibrationRepeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await delay(interval)
                guard !Task.isCancelled else { return }
                await self?.repeatAlarmVibrationIfActive(alarmID: alarmID)
            }
        }
    }

    private func repeatAlarmVibrationIfActive(alarmID: UUID) async {
        guard activeAlarm?.id == alarmID else {
            cancelAlarmVibrationLoop()
            return
        }
        let result = await playStandardVibration()
        lastVibrationResult = result
        if result.status != .started && result.status != .fired {
            cancelAlarmVibrationLoop()
        }
    }

    private func cancelAlarmVibrationLoop() {
        alarmVibrationRepeatTask?.cancel()
        alarmVibrationRepeatTask = nil
    }

    func snoozeAlarm(id: UUID) async -> Bool {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return false }
        guard let alarm = activeAlarm?.id == id ? activeAlarm : alarms.first(where: { $0.id == id }) else { return false }
        cancelAlarmVibrationLoop()
        await hapticService.cancel()
        let snoozed = AlarmScheduler.snooze(alarm)
        activeAlarm = nil
        upsertAlarm(snoozed)
        try? await localStore.saveAlarm(snoozed)
        if snoozed.enabled, snoozed.nextTriggerAt != nil {
            lastAlarmSchedulingResult = await alarmScheduler.scheduleLocalNotification(for: snoozed)
        }
        scheduleNextAlarmMonitor()
        await syncAccountStateIfAllowed(applyRemote: false)
        return snoozed.deliveryStatus == .snoozed
    }

    func dismissAlarm(id: UUID) async -> Bool {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return false }
        guard let alarm = activeAlarm?.id == id ? activeAlarm : alarms.first(where: { $0.id == id }) else { return false }
        cancelAlarmVibrationLoop()
        await hapticService.cancel()
        let dismissed = AlarmScheduler.dismiss(alarm)
        activeAlarm = nil
        upsertAlarm(dismissed)
        try? await localStore.saveAlarm(dismissed)
        if dismissed.enabled, dismissed.nextTriggerAt != nil {
            lastAlarmSchedulingResult = await alarmScheduler.scheduleLocalNotification(for: dismissed)
        } else {
            await alarmScheduler.cancelLocalNotification(alarmID: dismissed.id)
            lastAlarmSchedulingResult = AlarmSchedulingResult(status: .canceled, message: "Alarm dismissed.", scheduledAt: nil)
        }
        scheduleNextAlarmMonitor()
        await syncAccountStateIfAllowed(applyRemote: false)
        return dismissed.deliveryStatus == .dismissed
    }

    private func flushPendingAlarmPersistence() async {
        guard let task = alarmPersistenceTask else { return }
        await task.value
    }

    private func rescheduleUpcomingAlarmNotifications() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        let currentTime = now()
        let upcomingAlarms = alarms.filter { alarm in
            alarm.enabled && (alarm.nextTriggerAt.map { $0 > currentTime } ?? false)
        }
        for alarm in upcomingAlarms {
            lastAlarmSchedulingResult = await alarmScheduler.scheduleLocalNotification(for: alarm)
        }
    }

    private func scheduleNextAlarmMonitor() {
        alarmMonitorTask?.cancel()
        guard privacyGuard.canStartProtectedService(approval: approvalState) else {
            alarmMonitorTask = nil
            return
        }
        guard let nextTrigger = alarms.compactMap(\.nextTriggerAt).filter({ $0 > now() }).min() else {
            alarmMonitorTask = nil
            return
        }
        let delayNanoseconds = UInt64(max(nextTrigger.timeIntervalSince(now()), 0.05) * 1_000_000_000)
        alarmMonitorTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.handleAlarmMonitorWake()
        }
    }

    private func handleAlarmMonitorWake() async {
        await triggerDueAlarms(now: now())
        scheduleNextAlarmMonitor()
    }

    private func cancelAlarmMonitor() {
        alarmMonitorTask?.cancel()
        alarmMonitorTask = nil
    }

    private func upsertAlarm(_ alarm: Alarm) {
        var next = alarms.filter { $0.id != alarm.id }
        next.append(alarm)
        alarms = next.sorted { lhs, rhs in
            switch (lhs.nextTriggerAt, rhs.nextTriggerAt) {
            case let (left?, right?):
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.label < rhs.label
            }
        }
    }

    func routeDoubleTap(action: DoubleTapAction = .declineCallWhereSupported, activeCall: ActiveCallContext? = nil) async {
        let routedActiveCall = activeCall ?? activeCellularCall
        let result = await DoubleTapActionRouter.handleDoubleTap(
            action: action,
            callSettings: callVibrationSettings,
            activeCall: routedActiveCall,
            approval: approvalState,
            callController: nil,
            isCellularCallVibrationActive: routedActiveCall?.kind == .normalCellular && isCellularCallVibrationActive,
            activeAlarm: activeAlarm,
            alarmController: self
        )
        if result.status == .silencedCallVibration {
            cancelCallVibrationLoop()
            await hapticService.cancel()
            isCellularCallVibrationActive = false
            lastVibrationResult = VibrationPreviewResult(status: .terminated, message: result.message)
        }
        lastDoubleTapRouting = result
    }

    @discardableResult
    func ingestWearableSamples(_ samples: [HealthSample]) async -> Bool {
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else { return false }
        let result = await ingestionPipeline.ingest(
            samples: samples,
            origin: .wearableBLE,
            approval: approvalState,
            consent: consentState,
            userID: session?.userID,
            localStore: localStore,
            scoringService: scoringService,
            priorSummary: todaySnapshot,
            now: now()
        )
        if let updated = result.updatedSummary {
            let priorBaseline = skinTemperatureBaselineProfile
            skinTemperatureBaselineProfile = await localStore.loadSkinTemperatureBaselineProfile()
            todaySnapshot = updated
            await refreshRecentSummaries()
            if skinTemperatureBaselineProfile != priorBaseline {
                await syncAccountStateIfAllowed(applyRemote: false)
            }
        }
        if privacyGuard.canUploadHealthData(approval: approvalState, consent: consentState) {
            await syncHealthDataNow()
        }
        return result.status == .stored || result.status == .noSamples
    }

    private func registerBackgroundSync() {
        backgroundSyncCoordinator.register { [weak self] in
            await self?.runBackgroundRefresh()
        }
    }

    private func runBackgroundRefresh() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState) else { return }
        startApprovedServicesIfAllowed()
        await flushPendingCallVibrationSettingsPersistence()
        await flushPendingAlarmPersistence()
        await triggerDueAlarms(now: now())
        await rescheduleUpcomingAlarmNotifications()
        await syncAccountSettingsNow()
        await syncAppleHealthWritesIfAllowed()
        await syncHealthDataIfAllowed()
    }

    private func registerHealthKitBackgroundDeliveryIfAllowed() async {
        guard privacyGuard.canStartProtectedService(approval: approvalState), consentState.appleHealthEnabled else { return }
        await syncAppleHealthWritesNow()
    }

    private func refreshTodaySummaryFromStoredSamples(preserveExistingWhenNoSamples: Bool = false) async {
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else { return }
        let calendar = Calendar.current
        let currentTime = now()
        let daySamples = await loadSamplesForTodayAggregation(currentTime: currentTime, calendar: calendar)
        guard !daySamples.isEmpty || !preserveExistingWhenNoSamples else { return }
        var updated = DailyHealthAggregator.aggregate(
            samples: daySamples,
            day: currentTime,
            goal: todaySnapshot.movement.goal,
            calendar: calendar,
            prior: todaySnapshot,
            skinTemperatureBaseline: skinTemperatureBaselineProfile
        )
        updated = scoringService.score(summary: updated, bodyProfile: bodyProfile)
        todaySnapshot = updated
        await localStore.saveTodaySummary(updated)
    }

    private func loadSamplesForTodayAggregation(currentTime: Date, calendar: Calendar) async -> [HealthSample] {
        let dayStart = calendar.startOfDay(for: currentTime)
        let aggregationStart = calendar.date(
            byAdding: .hour,
            value: -Self.sleepAggregationLookbackHours,
            to: dayStart
        ) ?? dayStart.addingTimeInterval(TimeInterval(-Self.sleepAggregationLookbackHours * 60 * 60))
        let aggregationEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)
        return await localStore.loadHealthSamples(
            type: nil,
            source: nil,
            start: aggregationStart,
            end: aggregationEnd,
            limit: nil
        )
    }

    private func refreshRecentSummaries(days: Int = 30) async {
        guard privacyGuard.canAccessProtectedData(approval: approvalState) else {
            recentSummaries = []
            cloudRestoredDailySummaries = [:]
            updateWearableSyntheticCalibrationContext()
            return
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        let localToday = normalizedTodaySnapshot(todaySnapshot, calendar: calendar)
        if localToday != todaySnapshot {
            todaySnapshot = localToday
            await localStore.saveTodaySummary(localToday)
        }
        guard let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let rangeStart = calendar.date(byAdding: .hour, value: -18, to: firstDay),
              let rangeEnd = calendar.date(byAdding: .day, value: 1, to: today) else {
            publishRecentSummaries(localSummaries: [todaySnapshot], days: days, calendar: calendar)
            return
        }
        let samples = await localStore.loadHealthSamples(type: nil, source: nil, start: rangeStart, end: rangeEnd)
        let localSummaries: [DailyHealthSummary] = (0..<days).compactMap { offset -> DailyHealthSummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let prior = calendar.isDate(day, inSameDayAs: today) ? todaySnapshot : DailyHealthSummary.empty
            let summary = DailyHealthAggregator.aggregate(
                samples: samples,
                day: day,
                goal: todaySnapshot.movement.goal,
                calendar: calendar,
                prior: prior,
                skinTemperatureBaseline: skinTemperatureBaselineProfile
            )
            return scoringService.score(summary: summary, bodyProfile: bodyProfile)
        }
        publishRecentSummaries(localSummaries: localSummaries, days: days, calendar: calendar)
    }

    private func publishRecentSummaries(localSummaries: [DailyHealthSummary], days: Int, calendar: Calendar) {
        let today = calendar.startOfDay(for: now())
        let firstDay = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        var summariesByDay: [Date: DailyHealthSummary] = [:]

        func merge(_ candidate: DailyHealthSummary) {
            let day = calendar.startOfDay(for: candidate.date)
            guard day >= firstDay, day <= today else { return }
            if let existing = summariesByDay[day] {
                summariesByDay[day] = Self.preferredMetricSummary(local: existing, remote: candidate)
            } else {
                summariesByDay[day] = candidate
            }
        }

        localSummaries.forEach(merge)
        cloudRestoredDailySummaries.values.forEach(merge)
        merge(todaySnapshot)

        recentSummaries = summariesByDay.values.sorted { $0.date < $1.date }
        updateWearableSyntheticCalibrationContext()
    }

    private func normalizedTodaySnapshot(
        _ summary: DailyHealthSummary,
        calendar: Calendar = .current
    ) -> DailyHealthSummary {
        let today = calendar.startOfDay(for: now())
        guard calendar.isDate(summary.date, inSameDayAs: today) else {
            var fresh = DailyHealthSummary.empty
            fresh.date = today
            fresh.movement.goal = summary.movement.goal
            return fresh
        }
        return summary
    }

    private static func preferredMetricSummary(local: DailyHealthSummary, remote: DailyHealthSummary) -> DailyHealthSummary {
        let localWeight = metricSummaryContentWeight(local)
        let remoteWeight = metricSummaryContentWeight(remote)
        var preferred = remoteWeight > localWeight ? remote : local
        let fallback = remoteWeight > localWeight ? local : remote
        mergeMissingMetricFields(into: &preferred, from: fallback)
        return preferred
    }

    private static func mergeMissingMetricFields(
        into summary: inout DailyHealthSummary,
        from fallback: DailyHealthSummary
    ) {
        fillMissing(\.recovery, in: &summary, from: fallback)
        fillMissing(\.strain, in: &summary, from: fallback)
        if summary.sleepSummary?.hasSleep != true, fallback.sleepSummary?.hasSleep == true {
            summary.sleepSummary = fallback.sleepSummary
        }
        fillMissing(\.sleepMinutes, in: &summary, from: fallback)
        fillMissing(\.sleepNeedMinutes, in: &summary, from: fallback)
        fillMissing(\.sleepDebtMinutes, in: &summary, from: fallback)
        summary.movement = mergedMovementSummary(primary: summary.movement, fallback: fallback.movement)
        fillMissing(\.restingHeartRate, in: &summary, from: fallback)
        fillMissing(\.restingHeartRateSource, in: &summary, from: fallback)
        fillMissing(\.restingHeartRateConfidence, in: &summary, from: fallback)
        fillMissing(\.averageHeartRate, in: &summary, from: fallback)
        fillMissing(\.maxHeartRate, in: &summary, from: fallback)
        fillMissing(\.heartRateSampleCount, in: &summary, from: fallback)
        fillMissing(\.hrv, in: &summary, from: fallback)
        fillMissing(\.hrvSource, in: &summary, from: fallback)
        fillMissing(\.hrvConfidence, in: &summary, from: fallback)
        fillMissing(\.respiratoryRate, in: &summary, from: fallback)
        fillMissing(\.respiratoryRateSource, in: &summary, from: fallback)
        fillMissing(\.respiratoryRateConfidence, in: &summary, from: fallback)
        fillMissing(\.oxygenSaturation, in: &summary, from: fallback)
        fillMissing(\.oxygenSaturationSource, in: &summary, from: fallback)
        fillMissing(\.oxygenSaturationConfidence, in: &summary, from: fallback)
        fillMissing(\.vo2Max, in: &summary, from: fallback)
        fillMissing(\.vo2MaxSource, in: &summary, from: fallback)
        fillMissing(\.vo2MaxConfidence, in: &summary, from: fallback)
        fillMissing(\.rawWristTemperatureC, in: &summary, from: fallback)
        fillMissing(\.rawWristTemperatureSource, in: &summary, from: fallback)
        fillMissing(\.rawWristTemperatureConfidence, in: &summary, from: fallback)
        fillMissing(\.bodyTemperatureDelta, in: &summary, from: fallback)
        fillMissing(\.source, in: &summary, from: fallback)
        if summary.confidence == .unavailable, fallback.confidence != .unavailable {
            summary.confidence = fallback.confidence
        }
    }

    private static func mergedMovementSummary(
        primary: MovementSummary,
        fallback: MovementSummary
    ) -> MovementSummary {
        var movement = primary
        if movement.steps == nil { movement.steps = fallback.steps }
        if movement.activeEnergyKilocalories == nil {
            movement.activeEnergyKilocalories = fallback.activeEnergyKilocalories
        }
        if movement.walkingRunningDistanceMeters == nil {
            movement.walkingRunningDistanceMeters = fallback.walkingRunningDistanceMeters
        }
        if movement.movementMinutes == nil { movement.movementMinutes = fallback.movementMinutes }
        if movement.source == nil { movement.source = fallback.source }
        if movement.lastUpdated == nil { movement.lastUpdated = fallback.lastUpdated }
        if movement.trendDescription == nil { movement.trendDescription = fallback.trendDescription }
        if movement.confidence == .unavailable, fallback.confidence != .unavailable {
            movement.confidence = fallback.confidence
        }
        return movement
    }

    private static func fillMissing<Value>(
        _ keyPath: WritableKeyPath<DailyHealthSummary, Value?>,
        in summary: inout DailyHealthSummary,
        from fallback: DailyHealthSummary
    ) {
        if summary[keyPath: keyPath] == nil {
            summary[keyPath: keyPath] = fallback[keyPath: keyPath]
        }
    }

    private static func metricSummaryContentWeight(_ summary: DailyHealthSummary) -> Int {
        var weight = 0
        if summary.recovery != nil { weight += 2 }
        if summary.strain != nil { weight += 2 }
        if summary.sleepSummary?.hasSleep == true { weight += 2 }
        if summary.sleepMinutes != nil { weight += 1 }
        if summary.sleepNeedMinutes != nil { weight += 1 }
        if summary.sleepDebtMinutes != nil { weight += 1 }
        if summary.movement.steps != nil { weight += 1 }
        if summary.movement.activeEnergyKilocalories != nil { weight += 1 }
        if summary.movement.walkingRunningDistanceMeters != nil { weight += 1 }
        if summary.movement.movementMinutes != nil { weight += 1 }
        if summary.restingHeartRate != nil { weight += 1 }
        if summary.averageHeartRate != nil { weight += 1 }
        if summary.maxHeartRate != nil { weight += 1 }
        if summary.heartRateSampleCount != nil { weight += 1 }
        if summary.hrv != nil { weight += 1 }
        if summary.respiratoryRate != nil { weight += 1 }
        if summary.oxygenSaturation != nil { weight += 1 }
        if summary.vo2Max != nil { weight += 1 }
        if summary.rawWristTemperatureC != nil { weight += 1 }
        if summary.bodyTemperatureDelta != nil { weight += 1 }
        return weight
    }

    private func updateWearableSyntheticCalibrationContext() {
        let context = WearableSyntheticCalibrationContext.calibrated(
            bodyProfile: bodyProfile,
            recentSummaries: [todaySnapshot] + recentSummaries,
            now: now()
        )
        bleService.updateSyntheticCalibrationContext(context)
    }

    private func summaryTimeline(
        for metricID: WhoordanMetricID,
        rangeStart: Date,
        rangeEnd: Date,
        sampleLimit: Int
    ) -> MetricDetailTimeline {
        let sorted = recentSummaries
            .filter { $0.date >= rangeStart && $0.date <= rangeEnd }
            .sorted { $0.date < $1.date }
        let points = sorted.compactMap { summary -> MetricDetailTimelinePoint? in
            guard let value = Self.summaryTimelineValue(for: metricID, summary: summary) else { return nil }
            return MetricDetailTimelinePoint(
                date: summary.date,
                value: value,
                label: Self.compactMetricLabel(value: value, unit: nil)
            )
        }
        let limited = Array(points.suffix(max(1, sampleLimit)))
        return MetricDetailTimeline(
            metricID: metricID,
            points: limited,
            sampleTypesLoaded: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            wasLimited: points.count > limited.count
        )
    }

    private static func lazySampleTypes(for metricID: WhoordanMetricID) -> [HealthSampleType] {
        switch metricID {
        case .heartRate, .averageHeartRate, .heartRateZones:
            return [.heartRate]
        case .restingHeartRate:
            return [.restingHeartRate]
        case .hrv:
            return [.heartRateVariabilityRMSSD, .heartRateVariabilitySDNN]
        case .rawWristTemperature, .skinTemperatureDelta:
            return [.wristTemperature, .temperatureEvent, .bodyTemperature]
        case .steps:
            return [.steps]
        case .workoutCalories, .dailyCalories:
            return [.activeEnergy]
        case .respiratoryRate:
            return [.respiratoryRate]
        case .spo2:
            return [.oxygenSaturation]
        case .vo2Max:
            return [.vo2Max]
        case .sleepDuration,
             .sleepPerformance,
             .sleepNeed,
             .sleepDebt,
             .sleepConsistency,
             .sleepStages,
             .restorativeSleepPercent,
             .restorativeSleepHours,
             .recovery,
             .dayStrain,
             .activityStrain,
             .stress:
            return []
        }
    }

    private static func summaryTimelineValue(
        for metricID: WhoordanMetricID,
        summary: DailyHealthSummary
    ) -> Double? {
        switch metricID {
        case .sleepDuration:
            return summary.sleepMinutes
        case .sleepNeed:
            return summary.sleepNeedMinutes
        case .sleepDebt:
            return summary.sleepDebtMinutes
        case .recovery:
            return summary.recovery?.value
        case .dayStrain, .activityStrain:
            return summary.strain?.value
        default:
            return nil
        }
    }

    private static func timelinePoint(for sample: HealthSample) -> MetricDetailTimelinePoint {
        MetricDetailTimelinePoint(
            date: sample.startDate,
            value: sample.value,
            label: compactMetricLabel(value: sample.value, unit: sample.unit)
        )
    }

    private static func compactMetricLabel(value: Double, unit: String?) -> String {
        let numeric: String
        if value.rounded() == value {
            numeric = "\(Int(value))"
        } else {
            numeric = String(format: "%.1f", value)
        }
        guard let unit, !unit.isEmpty, unit != "count" else { return numeric }
        return "\(numeric) \(unit)"
    }

    private func verifyApprovalWithRetry(presentsCheckingState: Bool = true, restoreAttemptID: UUID? = nil) async {
        guard let currentSession = session else {
            approvalState = nil
            await stopProtectedServices()
            return
        }

        if presentsCheckingState, isCurrentStartupRestore(restoreAttemptID) {
            approvalState = .checkingApproval()
        }
        do {
            let state = try await approvalService.fetchApproval(for: currentSession.userID)
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(state)
        } catch ApprovalFetchError.unauthorized, ApprovalFetchError.forbidden {
            await refreshSessionAndRetryApproval(restoreAttemptID: restoreAttemptID)
        } catch ApprovalFetchError.networkUnavailable {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(await offlineCapableNetworkState())
        } catch let error as URLError where Self.isNetworkUnavailable(error) {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(await offlineCapableNetworkState())
        } catch let error as ApprovalFetchError {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(.approvalFetchFailed(message: error.localizedDescription))
        } catch {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(.unknownError(message: "Approval check failed."))
        }
    }

    private func refreshSessionAndRetryApproval(restoreAttemptID: UUID? = nil) async {
        guard let refresher = authService as? SessionRefreshing else {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(.authExpired())
            session = nil
            return
        }
        do {
            guard let refreshed = try await refresher.refreshStoredSession(force: true) else {
                guard isCurrentStartupRestore(restoreAttemptID) else { return }
                session = nil
                await applyApprovalState(.authExpired())
                return
            }
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            session = refreshed
            let state = try await approvalService.fetchApproval(for: refreshed.userID)
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(state)
        } catch AuthError.sessionExpired {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            session = nil
            await applyApprovalState(.authExpired())
        } catch ApprovalFetchError.networkUnavailable {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(await offlineCapableNetworkState())
        } catch let error as URLError where Self.isNetworkUnavailable(error) {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(await offlineCapableNetworkState())
        } catch let error as ApprovalFetchError {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(.approvalFetchFailed(message: error.localizedDescription))
        } catch {
            guard isCurrentStartupRestore(restoreAttemptID) else { return }
            await applyApprovalState(.unknownError(message: "Approval check failed after refreshing the session."))
        }
    }

    private func applyApprovalState(_ state: ApprovalState) async {
        approvalState = state
        if state.allowsProtectedLocalAccess {
            if state.status == .approved {
                await localStore.saveCachedApprovalState(state)
            }
            startApprovedServicesIfAllowed()
            await registerHealthKitBackgroundDeliveryIfAllowed()
        } else {
            await stopProtectedServices()
            if Self.isDurableApprovalStatus(state.status) {
                await localStore.saveCachedApprovalState(state)
            }
        }
    }

    private func stopProtectedServices() async {
        bleService.stopAll()
        cancelCallVibrationLoop()
        cancelAlarmVibrationLoop()
        cancelAlarmMonitor()
        await hapticService.cancel()
        await cancelOperationalNotifications()
        activeCellularCall = nil
        isCellularCallVibrationActive = false
        activeAlarm = nil
    }

    private func offlineCapableNetworkState() async -> ApprovalState {
        let cached = await localStore.loadCachedApprovalState()
        guard cached?.status == .approved, let lastApprovedAt = cached?.checkedAt else {
            return .networkUnavailable(lastVerifiedAt: nil)
        }
        guard now().timeIntervalSince(lastApprovedAt) <= Self.offlineApprovalGraceInterval else {
            return .networkUnavailable(lastVerifiedAt: lastApprovedAt)
        }
        return .offlineApproved(lastVerifiedAt: lastApprovedAt)
    }

    private static func isDurableApprovalStatus(_ status: ApprovalStatus) -> Bool {
        switch status {
        case .approved, .pending, .rejected, .revoked, .missing:
            return true
        case .offlineApproved, .checkingApproval, .authExpired, .networkUnavailable, .approvalFetchFailed, .unknown, .unknownError, .error:
            return false
        }
    }

    private static func isNetworkUnavailable(_ error: URLError) -> Bool {
        [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .timedOut
        ].contains(error.code)
    }

}
// swiftlint:enable type_body_length

private struct CachedCallVibrationSettings: Codable {
    let userID: UUID?
    let settings: CallVibrationSettings
}

extension AppEnvironment: AlarmControlling {}
