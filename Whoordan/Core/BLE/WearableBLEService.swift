import Foundation

#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

#if canImport(UIKit)
import UIKit
#endif

enum WearableConnectionState: String, Codable, Equatable {
    case idle
    case approvalRequired
    case scanning
    case connecting
    case discoveringServices
    case subscribing
    case initializing
    case historicalSync
    case realtime
    case disconnected
    case error
}

enum WearableCatchUpState: String, Codable, Equatable {
    case idle
    case restorePending
    case catchingUp
    case waitingForDurableStorage
    case caughtUp
    case realtimeActive
    case stalled
    case unknown

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .restorePending: return "Restore pending"
        case .catchingUp: return "Catching up"
        case .waitingForDurableStorage: return "Saving"
        case .caughtUp: return "Caught up"
        case .realtimeActive: return "Live"
        case .stalled: return "Stalled"
        case .unknown: return "Unknown"
        }
    }
}

enum WearableGapStatus: String, Codable, Equatable {
    case liveGapBackfilled
    case catchingUp
    case iosBackgroundLimited
    case resubscribing
    case bleDisconnected
    case deviceOffBody
    case deviceBatteryDead
    case bufferEvicted
    case unknown

    var label: String {
        switch self {
        case .liveGapBackfilled: return "Backfilled"
        case .catchingUp: return "Catching up"
        case .iosBackgroundLimited: return "Background limited"
        case .resubscribing: return "Resubscribing"
        case .bleDisconnected: return "Disconnected"
        case .deviceOffBody: return "Off wrist"
        case .deviceBatteryDead: return "Battery empty"
        case .bufferEvicted: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }
}

enum WearableControlPlaneEventKind: String, Codable, Equatable {
    case appSyncRequested
    case centralRestored
    case restoredPeripheralConnected
    case connected
    case disconnected
    case servicesDiscovered
    case notifyEnabled
    case initSent
    case historicalSyncStarted
    case batchMarkerReceived
    case batchAckDeferred
    case batchAckSent
    case realtimeEnabled
    case durableSampleStoreCompleted
    case durableSampleStoreFailed
    case gapClassified
    case writerError
}

struct WearableControlPlaneEvent: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: WearableControlPlaneEventKind
    var message: String
    var occurredAt: Date
    var deviceID: String?
    var connectionState: WearableConnectionState

    init(
        id: UUID = UUID(),
        kind: WearableControlPlaneEventKind,
        message: String,
        occurredAt: Date = Date(),
        deviceID: String?,
        connectionState: WearableConnectionState
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.occurredAt = occurredAt
        self.deviceID = deviceID
        self.connectionState = connectionState
    }
}

struct WearableSyncDiagnostics: Codable, Equatable {
    var catchUpState: WearableCatchUpState = .idle
    var lastGapStatus: WearableGapStatus?
    var lastGapSeconds: Int?
    var lastCheckpointTokenFingerprint: String?
    var lastAckedBatchTokenFingerprint: String?
    var pendingDurableSampleStores = 0
    var deferredBatchAckCount = 0
    var lastControlPlaneEvent: WearableControlPlaneEvent?
    var recentControlPlaneEvents: [WearableControlPlaneEvent] = []

    var detail: String {
        if let lastGapStatus, let lastGapSeconds {
            return "\(lastGapStatus.label), \(lastGapSeconds)s gap"
        }
        if pendingDurableSampleStores > 0 {
            return "Saving \(pendingDurableSampleStores) local batch\(pendingDurableSampleStores == 1 ? "" : "es")"
        }
        if deferredBatchAckCount > 0 {
            return "\(deferredBatchAckCount) ACK\(deferredBatchAckCount == 1 ? "" : "s") waiting"
        }
        return lastControlPlaneEvent?.message ?? "Waiting for wearable history"
    }
}

enum WearableGapClassifier {
    static let significantGapSeconds: TimeInterval = 60

    static func classify(
        gapSeconds: TimeInterval,
        previousConnection: WearableConnectionState?,
        currentConnection: WearableConnectionState,
        previousAppState: String?,
        currentAppState: String,
        isOnWrist: Bool?,
        batteryPercent: Int?
    ) -> WearableGapStatus? {
        guard gapSeconds >= significantGapSeconds else { return nil }
        if batteryPercent == 0 { return .deviceBatteryDead }
        if isOnWrist == false { return .deviceOffBody }
        if currentConnection == .subscribing || currentConnection == .initializing || currentConnection == .discoveringServices {
            return .resubscribing
        }
        if currentConnection == .disconnected || currentConnection == .error {
            return .bleDisconnected
        }
        if previousAppState == "background" || currentAppState == "background" {
            return .iosBackgroundLimited
        }
        if previousConnection == .historicalSync || currentConnection == .historicalSync {
            return .catchingUp
        }
        return .unknown
    }
}

struct WearableBatchAckGate: Equatable {
    private(set) var pendingDurableSampleStores = 0
    private(set) var deferredBatchAckCount = 0
    private(set) var durabilityFailed = false

    mutating func beginDurableSampleStore() {
        pendingDurableSampleStores += 1
    }

    mutating func finishDurableSampleStore(succeeded: Bool) {
        pendingDurableSampleStores = max(0, pendingDurableSampleStores - 1)
        if !succeeded {
            durabilityFailed = true
        }
    }

    mutating func markBatchAckDeferred() {
        deferredBatchAckCount += 1
    }

    mutating func markDeferredBatchAckFlushed() {
        deferredBatchAckCount = max(0, deferredBatchAckCount - 1)
    }

    var shouldDeferBatchAck: Bool {
        pendingDurableSampleStores > 0 || durabilityFailed
    }

    var canFlushDeferredBatchAck: Bool {
        pendingDurableSampleStores == 0 && !durabilityFailed && deferredBatchAckCount > 0
    }
}

struct WearableDeviceState: Codable, Equatable {
    var connection: WearableConnectionState = .idle
    var deviceID: String?
    var name: String?
    var advertisingName: String?
    var deviceFingerprint: String?
    var rssi: Int?
    var liveHeartRateBPM: Int?
    var liveHeartRateSource: String?
    var liveHeartRateAt: Date?
    var batteryPercent: Int?
    var isCharging: Bool?
    var isOnWrist: Bool?
    var skinTemperatureC: Double?
    var skinTemperatureAt: Date?
    var lastPacketAt: Date?
    var lastError: String?
    var discoveredUUIDs: [String] = []
    var discoveredAttributes: [WearableAttributeSummary] = []
    var candidates: [WearableDeviceCandidate] = []
    var lastNotificationSample: WearableNotificationSample?
    var payloadProcessing = WearablePayloadProcessingSummary()
    var lastCommandResponse: String?
    var dataRangeSummary: String?
    var alarmSummary: String?
    var historicalSyncSummary: String?
    var firmwareLogSummary: String?
    var lastEventDescription: String?
    var unavailableSignalReasons: [String] = []
    var rawCaptureRecordCount = 0
    var rawCapture = WearableCaptureDiagnostics()
    var liveAnalytics = WearableLiveAnalyticsSummary()
    var unknownFrameObservations: [WearableFrameObservation] = []
    var unknownFrameTrends: [WearableFrameTrendStat] = []
    var syncDiagnostics = WearableSyncDiagnostics()

    var hasConnectedWearable: Bool {
        switch connection {
        case .historicalSync, .realtime:
            return true
        case .idle, .approvalRequired, .scanning, .connecting, .discoveringServices,
             .subscribing, .initializing, .disconnected, .error:
            return candidates.contains { $0.matchesExpectedService && $0.isConnectedToPhone }
        }
    }

    var shouldShowPairWearableCTA: Bool {
        switch connection {
        case .idle, .approvalRequired, .disconnected, .error:
            return !hasConnectedWearable
        case .scanning, .connecting, .discoveringServices, .subscribing,
             .initializing, .historicalSync, .realtime:
            return false
        }
    }

    mutating func applyDisplayedBatteryPercent(_ percent: Int, source: WearableBatteryDisplaySource) {
        guard WearableBatteryDisplayPolicy.shouldPromoteToDisplay(source),
              (0...100).contains(percent) else {
            return
        }
        batteryPercent = percent
    }
}

enum WearableBatteryDisplaySource: Equatable {
    case standardGattBatteryLevel
    case proprietaryHelloCandidate
    case proprietaryEventCandidate
}

enum WearableBatteryDisplayPolicy {
    static func shouldPromoteToDisplay(_ source: WearableBatteryDisplaySource) -> Bool {
        source == .proprietaryHelloCandidate
    }
}

enum WearableCaptureScenario: String, Codable, Equatable, CaseIterable, Identifiable {
    case idle
    case walking
    case running
    case workout
    case postWorkout = "post_workout"
    case preSleep = "pre_sleep"
    case overnight
    case postWake = "post_wake"
    case nap
    case charging
    case wristOff = "wrist_off"
    case wristOn = "wrist_on"
    case hapticPreview = "haptic_preview"
    case alarm
    case doubleTap = "double_tap"
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .walking: return "Walking"
        case .running: return "Running"
        case .workout: return "Workout"
        case .postWorkout: return "Post-workout"
        case .preSleep: return "Pre-sleep"
        case .overnight: return "Overnight"
        case .postWake: return "Post-wake"
        case .nap: return "Nap"
        case .charging: return "Charging"
        case .wristOff: return "Wrist off"
        case .wristOn: return "Wrist on"
        case .hapticPreview: return "Haptic preview"
        case .alarm: return "Alarm"
        case .doubleTap: return "Double tap"
        case .unknown: return "Unknown"
        }
    }
}

enum WearableCaptureDirection: String, Codable, Equatable {
    case notify
    case write
}

struct WearableCaptureDiagnostics: Codable, Equatable {
    var isActive = false
    var scenario: WearableCaptureScenario = .unknown
    var recordCount = 0
    var maxRecords = 0
    var lastCapturedAt: Date?
    var lastDirection: WearableCaptureDirection?
    var lastDecodedPacketType: String?
    var fileFingerprint: String?
    var lastSavedRecordingName: String?
    var lastSavedFileName: String?
    var lastError: String?
}

struct WearableRawPayloadCaptureSave: Codable, Equatable {
    let recordingName: String
    let fileName: String
    let recordCount: Int
}

struct WearableRawPayloadCaptureRecord: Codable, Equatable {
    let schemaVersion: Int
    let capturedAt: String
    let characteristicUUID: String
    let byteCount: Int
    let payloadLength: Int
    let direction: WearableCaptureDirection
    let payloadBase64: String
    let packetType: String?
    let decodedPacketType: String?
    let connectionState: WearableConnectionState
    let rssi: Int?
    let batteryPercent: Int?
    let isCharging: Bool?
    let deviceTimeUnix: Int?
    let appState: String
    let scenario: WearableCaptureScenario
    let appVersion: String
    let deviceModel: String
    let sessionLabel: String?

    init(
        capturedAt: String,
        characteristicUUID: String,
        byteCount: Int,
        payloadLength: Int? = nil,
        direction: WearableCaptureDirection,
        payloadBase64: String,
        packetType: String? = nil,
        decodedPacketType: String?,
        connectionState: WearableConnectionState,
        rssi: Int?,
        batteryPercent: Int? = nil,
        isCharging: Bool? = nil,
        deviceTimeUnix: Int?,
        appState: String,
        scenario: WearableCaptureScenario,
        appVersion: String = "unknown",
        deviceModel: String = "unknown",
        sessionLabel: String? = nil,
        schemaVersion: Int = 2
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.characteristicUUID = characteristicUUID
        self.byteCount = byteCount
        self.payloadLength = payloadLength ?? byteCount
        self.direction = direction
        self.payloadBase64 = payloadBase64
        self.packetType = packetType ?? decodedPacketType
        self.decodedPacketType = decodedPacketType
        self.connectionState = connectionState
        self.rssi = rssi
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.deviceTimeUnix = deviceTimeUnix
        self.appState = appState
        self.scenario = scenario
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.sessionLabel = sessionLabel
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case capturedAt
        case characteristicUUID
        case byteCount
        case payloadLength
        case direction
        case payloadBase64
        case packetType
        case decodedPacketType
        case connectionState
        case rssi
        case batteryPercent
        case isCharging
        case deviceTimeUnix
        case appState
        case scenario
        case appVersion
        case deviceModel
        case sessionLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let byteCount = try container.decode(Int.self, forKey: .byteCount)
        let decodedPacketType = try container.decodeIfPresent(String.self, forKey: .decodedPacketType)
        self.init(
            capturedAt: try container.decode(String.self, forKey: .capturedAt),
            characteristicUUID: try container.decode(String.self, forKey: .characteristicUUID),
            byteCount: byteCount,
            payloadLength: try container.decodeIfPresent(Int.self, forKey: .payloadLength) ?? byteCount,
            direction: try container.decode(WearableCaptureDirection.self, forKey: .direction),
            payloadBase64: try container.decode(String.self, forKey: .payloadBase64),
            packetType: try container.decodeIfPresent(String.self, forKey: .packetType) ?? decodedPacketType,
            decodedPacketType: decodedPacketType,
            connectionState: try container.decode(WearableConnectionState.self, forKey: .connectionState),
            rssi: try container.decodeIfPresent(Int.self, forKey: .rssi),
            batteryPercent: try container.decodeIfPresent(Int.self, forKey: .batteryPercent),
            isCharging: try container.decodeIfPresent(Bool.self, forKey: .isCharging),
            deviceTimeUnix: try container.decodeIfPresent(Int.self, forKey: .deviceTimeUnix),
            appState: try container.decode(String.self, forKey: .appState),
            scenario: try container.decode(WearableCaptureScenario.self, forKey: .scenario),
            appVersion: try container.decodeIfPresent(String.self, forKey: .appVersion) ?? "unknown",
            deviceModel: try container.decodeIfPresent(String.self, forKey: .deviceModel) ?? "unknown",
            sessionLabel: try container.decodeIfPresent(String.self, forKey: .sessionLabel),
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        )
    }
}

enum WearableSyntheticCalibrationProvenance: String, Codable, Equatable {
    case syntheticCalibrationShadow = "synthetic_calibration_shadow"
}

struct WearableSyntheticCalibrationProfile: Codable, Equatable {
    let heightCentimeters: Double
    let weightKilograms: Double
    let ageYears: Int
    let baselineRestingHeartRateBPM: Double
    let baselineHRVRMSSDMS: Double
    let baselineRespiratoryRate: Double
    let baselineSleepMinutes: Double
    let baselineSleepNeedMinutes: Double
    let baselineRecoveryPercent: Double
    let baselineDayStrain: Double
    let baselineVO2Max: Double
    let baselineSpO2Percent: Double
}

struct WearableSyntheticCalibrationPacketAnchor: Codable, Equatable {
    let packetType: String?
    let decodedPacketType: String?
    let recordType: UInt8?
    let heartRateBPM: Int?
    let skinTemperatureC: Double?
    let motionIntensity: Double
}

struct WearableSyntheticCalibrationMetrics: Codable, Equatable {
    let heartRateBPM: Double
    let restingHeartRateBPM: Double
    let hrvRMSSDMS: Double
    let respiratoryRate: Double
    let oxygenSaturationPercent: Double
    let sleepMinutes: Double
    let sleepNeedMinutes: Double
    let sleepDebtMinutes: Double
    let sleepPerformancePercent: Double
    let sleepConsistencyPercent: Double
    let restorativeSleepPercent: Double
    let recoveryPercent: Double
    let dayStrain: Double
    let activityStrain: Double
    let activeEnergyKilocalories: Double
    let stressPercent: Double
    let vo2Max: Double
    let steps: Int
    let skinTemperatureDeltaC: Double
}

struct WearableSyntheticCalibrationRecord: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: String
    let linkedRawPayloadFileName: String
    let linkedRawPayloadRecordIndex: Int
    let capturedAt: String
    let provenance: WearableSyntheticCalibrationProvenance
    let personID: String
    let profile: WearableSyntheticCalibrationProfile
    let packetAnchor: WearableSyntheticCalibrationPacketAnchor
    let metrics: WearableSyntheticCalibrationMetrics
    let calibrationSource: String
    let privacyNote: String
}

struct WearableSyntheticCalibrationContext: Codable, Equatable {
    let personID: String
    let profile: WearableSyntheticCalibrationProfile
    let calibrationSource: String

    static func person1Default() -> WearableSyntheticCalibrationContext {
        WearableSyntheticCalibrationContext(
            personID: "person_1",
            profile: WearableSyntheticCalibrationProfile(
                heightCentimeters: 167,
                weightKilograms: 69,
                ageYears: 22,
                baselineRestingHeartRateBPM: 56,
                baselineHRVRMSSDMS: 65,
                baselineRespiratoryRate: 15.2,
                baselineSleepMinutes: 440,
                baselineSleepNeedMinutes: 470,
                baselineRecoveryPercent: 66,
                baselineDayStrain: 8.5,
                baselineVO2Max: 52,
                baselineSpO2Percent: 97.5
            ),
            calibrationSource: "person_1_default_profile_167cm_69kg_22y"
        )
    }

    static func calibrated(
        bodyProfile: BodyProfile,
        recentSummaries: [DailyHealthSummary],
        now: Date
    ) -> WearableSyntheticCalibrationContext {
        let fallback = person1Default()
        let profile = fallback.profile
        let ageYears = bodyProfile.resolvedAgeYears(on: now) ?? bodyProfile.ageYears ?? profile.ageYears
        let maxHeartRate = bodyProfile.preferredMaxHeartRate(on: now)?.value ?? (208 - (0.7 * Double(ageYears)))
        let restingHeartRate = median(recentSummaries.compactMap(\.restingHeartRate)) ?? profile.baselineRestingHeartRateBPM
        let vo2FromHR = max(30, min(68, 15.3 * maxHeartRate / max(restingHeartRate, 42)))
        let baselineSleepMinutes = median(recentSummaries.compactMap(\.sleepMinutes)) ?? profile.baselineSleepMinutes
        let baselineSleepNeed = median(recentSummaries.compactMap(\.sleepNeedMinutes))
            ?? max(profile.baselineSleepNeedMinutes, baselineSleepMinutes + 25)
        let baselineRecovery = median(recentSummaries.compactMap { $0.recovery?.value }) ?? profile.baselineRecoveryPercent
        let baselineStrain = median(recentSummaries.compactMap { $0.strain?.value }) ?? profile.baselineDayStrain

        return WearableSyntheticCalibrationContext(
            personID: fallback.personID,
            profile: WearableSyntheticCalibrationProfile(
                heightCentimeters: bodyProfile.heightCentimeters ?? profile.heightCentimeters,
                weightKilograms: bodyProfile.weightKilograms ?? profile.weightKilograms,
                ageYears: ageYears,
                baselineRestingHeartRateBPM: restingHeartRate,
                baselineHRVRMSSDMS: median(recentSummaries.compactMap(\.hrv)) ?? profile.baselineHRVRMSSDMS,
                baselineRespiratoryRate: median(recentSummaries.compactMap(\.respiratoryRate)) ?? profile.baselineRespiratoryRate,
                baselineSleepMinutes: baselineSleepMinutes,
                baselineSleepNeedMinutes: baselineSleepNeed,
                baselineRecoveryPercent: baselineRecovery,
                baselineDayStrain: baselineStrain,
                baselineVO2Max: median(recentSummaries.compactMap(\.vo2Max)) ?? vo2FromHR,
                baselineSpO2Percent: median(recentSummaries.compactMap(\.oxygenSaturation)) ?? profile.baselineSpO2Percent
            ),
            calibrationSource: recentSummaries.contains(where: \.hasSyncableContent)
                ? "local_wearable_history_with_profile_fallbacks"
                : fallback.calibrationSource
        )
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

struct WearablePayloadProcessingSummary: Codable, Equatable {
    var processedPayloadCount = 0
    var unsupportedPayloadCount = 0
    var malformedFrameCount = 0
    var droppedFragmentCount = 0
    var lastPacketType: String?
    var lastRecordType: String?
    var lastEventType: UInt16?
    var imuSampleCount = 0
    var ppgSampleCount = 0
    var ppgChannelCount = 0
    var safeHealthSampleCount = 0
    var imuBatchCount = 0
    var unknownPacketCount = 0
    var historicalSyncComplete = false
    var realtimeStreamActive = false
    var lastBatchAckAt: Date?
    var lastBatchAckTokenFingerprint: String?
    var lastHapticStatus: String?
    var lastProcessedAt: Date?
}

struct WearableLiveAnalyticsSummary: Codable, Equatable {
    var directMetricCount = 0
    var candidateMetricCount = 0
    var unknownFrameCount = 0
    var lastDirectMetric: String?
    var lastCandidateMetric: String?
    var lastUpdatedAt: Date?
}

struct WearableFrameObservation: Codable, Equatable, Identifiable {
    let id: String
    var packetType: String
    var recordType: UInt8?
    var label: String
    var observationKind: String
    var byteCount: Int
    var sampleCount: Int?
    var candidateValue: String?
    var caveat: String
    var observedAt: Date

    static func unknownPacket(packetByte: UInt8?, byteCount: Int, observedAt: Date) -> WearableFrameObservation {
        let packetLabel = packetByte.map { "packet class \(Int($0))" } ?? "packet class unknown"
        let idMaterial = "\(packetLabel)|\(byteCount)"
        return WearableFrameObservation(
            id: "unknown-packet-\(WearablePrivacy.fingerprint(idMaterial))",
            packetType: "unknown packet",
            recordType: nil,
            label: "Unknown \(packetLabel)",
            observationKind: "unknown",
            byteCount: max(0, byteCount),
            sampleCount: nil,
            candidateValue: nil,
            caveat: "Packet class is validly framed but has no decoded app metric mapping.",
            observedAt: observedAt
        )
    }
}

struct WearableFrameTrendStat: Codable, Equatable, Identifiable {
    let frameClass: String
    var packetType: String
    var recordType: UInt8?
    var label: String
    var observationKind: String
    var count: Int
    var firstObservedAt: Date
    var lastObservedAt: Date
    var lastByteCount: Int
    var lastCandidateValue: String?

    var id: String { frameClass }

    static func frameClass(for observation: WearableFrameObservation) -> String {
        let record = observation.recordType.map { "R\($0)" } ?? "event"
        return [observation.packetType, record, observation.observationKind].joined(separator: ":")
    }

    static func upsert(observation: WearableFrameObservation, into stats: inout [WearableFrameTrendStat]) {
        let frameClass = frameClass(for: observation)
        if let index = stats.firstIndex(where: { $0.frameClass == frameClass }) {
            stats[index].count += 1
            stats[index].label = observation.label
            stats[index].lastObservedAt = observation.observedAt
            stats[index].lastByteCount = observation.byteCount
            stats[index].lastCandidateValue = observation.candidateValue
        } else {
            stats.insert(
                WearableFrameTrendStat(
                    frameClass: frameClass,
                    packetType: observation.packetType,
                    recordType: observation.recordType,
                    label: observation.label,
                    observationKind: observation.observationKind,
                    count: 1,
                    firstObservedAt: observation.observedAt,
                    lastObservedAt: observation.observedAt,
                    lastByteCount: observation.byteCount,
                    lastCandidateValue: observation.candidateValue
                ),
                at: 0
            )
        }
        stats.sort {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.lastObservedAt > $1.lastObservedAt
        }
        if stats.count > 30 {
            stats.removeLast(stats.count - 30)
        }
    }
}

struct WearableAttributeSummary: Codable, Equatable, Identifiable {
    let id: String
    var serviceUUID: String
    var characteristicUUID: String
    var properties: [String]
    var canRead: Bool
    var canNotify: Bool
    var isNotifying: Bool
    var lastValueSummary: String?
}

struct WearableDeviceCandidate: Codable, Equatable, Identifiable {
    let id: String
    var name: String?
    var rssi: Int
    var advertisedServiceUUIDs: [String]
    var matchesExpectedService: Bool
    var isConnectedToPhone: Bool
    var isPreferredOwnedDevice: Bool
    var lastSeen: Date

    var displayName: String {
        name?.isEmpty == false ? name! : "Nearby BLE device"
    }

    var statusLabel: String {
        if matchesExpectedService && isConnectedToPhone {
            return "Compatible and connected to this iPhone"
        }
        if isPreferredOwnedDevice && !matchesExpectedService {
            return "Preferred owned device; compatibility pending"
        }
        if matchesExpectedService {
            return "Compatible service advertised"
        }
        return "Not paired or compatibility unknown"
    }
}

struct WearableNotificationSample: Codable, Equatable {
    var characteristicUUID: String
    var byteCount: Int
    var frameCount: Int
    var packetType: String?
    var decodeStatus: String
    var sampledAt: Date
}

protocol WearableCommandSink: AnyObject {
    func writeCommand(_ data: Data, requiresResponse: Bool) async throws
}

protocol WearableBLEServicing: WearableCommandSink {
    var currentDeviceState: WearableDeviceState { get }
    func primeBluetoothPermission()
    func startAutoConnect()
    func startScanning()
    func requestBluetoothAccess()
    func connect(to candidate: WearableDeviceCandidate)
    func stopAll()
    func startRawCapture(scenario: WearableCaptureScenario)
    func stopRawCapture()
    func finishRawCapture(recordingName: String) -> WearableRawPayloadCaptureSave?
    func updateRawCaptureScenario(_ scenario: WearableCaptureScenario)
    func exportRawCaptureArchive() throws -> URL
    func updateSyntheticCalibrationContext(_ context: WearableSyntheticCalibrationContext)
    func restoreBLECheckpoints(_ checkpoints: [BLECheckpoint])
}

final class WearableBLEService: NSObject, ObservableObject, WearableBLEServicing, @unchecked Sendable {
    @Published private(set) var currentDeviceState = WearableDeviceState()
    var onStateChange: ((WearableDeviceState) -> Void)?
    var onHealthSamples: (([HealthSample]) async -> Bool)?
    var onBLECheckpoint: ((BLECheckpoint) -> Void)?
    var onControlPlaneEvent: ((WearableControlPlaneEvent) -> Void)?
    var onEvent: ((WearableEventPacket) -> Void)?
    private let preferredDeviceName: String?
    private var continuousRawPayloadCapture: WearableContinuousRawPayloadCapture?
    private var rawPayloadCapture: WearableRawPayloadCapture?
    private var rawCaptureScenario: WearableCaptureScenario = .unknown

    #if canImport(CoreBluetooth)
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var notifyCharacteristics: [CBUUID: CBCharacteristic] = [:]
    private var subscribedNotifyUUIDs = Set<CBUUID>()
    private var reassembler = FrameReassembler()
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var hasSentInitSequence = false
    private var autoConnectEnabled = false
    private var scanningForAutoConnect = false
    private var manualScanRequested = false
    private var permissionProbeScanRequested = false
    private var permissionProbeScanActive = false
    private var permissionProbeStopWorkItem: DispatchWorkItem?
    private static let restorationIdentifier = "com.w4rd2.whoordan.ble.central"
    #endif

    private var sentCommands: [Data] = []
    private var batchAckCounter: UInt8 = 0xA0
    private var realtimeDisableSequence: UInt8 = 0xB8
    private var restoredBLECheckpoints: [String: BLECheckpoint] = [:]
    private var batchAckGate = WearableBatchAckGate()
    private var deferredBatchAckTokens: [Data] = []
    private var lastNotifyPayloadAt: Date?
    private var lastNotifyConnectionState: WearableConnectionState?
    private var lastNotifyAppState: String?
    private static let maxRecentControlPlaneEvents = 30

    init(preferredDeviceName: String? = nil) {
        let trimmedName = preferredDeviceName?.trimmed
        self.preferredDeviceName = trimmedName?.isEmpty == false ? trimmedName : nil
        #if DEBUG
        self.continuousRawPayloadCapture = WearableContinuousRawPayloadCapture()
        self.rawPayloadCapture = WearableRawPayloadCapture.fromEnvironment()
        #else
        self.continuousRawPayloadCapture = nil
        self.rawPayloadCapture = nil
        #endif
        self.rawCaptureScenario = self.rawPayloadCapture?.scenario ?? .unknown
        super.init()
        if let rawPayloadCapture {
            updateState {
                $0.rawCapture = rawPayloadCapture.diagnostics(
                    lastDirection: nil,
                    lastDecodedPacketType: nil,
                    lastCapturedAt: nil,
                    lastError: nil
                )
            }
        }
    }

    func restoreBLECheckpoints(_ checkpoints: [BLECheckpoint]) {
        restoredBLECheckpoints = Dictionary(uniqueKeysWithValues: checkpoints.map { ($0.deviceID, $0) })
        guard let latest = checkpoints.sorted(by: { $0.updatedAt > $1.updatedAt }).first else { return }
        let fingerprint = latest.lastBatchToken.map(WearablePrivacy.fingerprint)
        updateState {
            $0.deviceID = $0.deviceID ?? latest.deviceID
            $0.payloadProcessing.historicalSyncComplete = latest.historicalSyncComplete
            $0.syncDiagnostics.catchUpState = latest.historicalSyncComplete ? .caughtUp : .restorePending
            $0.syncDiagnostics.lastCheckpointTokenFingerprint = fingerprint
        }
        recordControlPlaneEvent(
            kind: .appSyncRequested,
            message: latest.historicalSyncComplete ? "Restored caught-up BLE checkpoint." : "Restored pending BLE checkpoint."
        )
    }

    func startAutoConnect() {
        #if canImport(CoreBluetooth)
        guard canInitializeBluetooth(explicitRequest: false) else { return }
        cancelPermissionProbeScan(stopActiveScan: true)
        autoConnectEnabled = true
        if central == nil {
            updateState { $0.connection = .idle }
            central = makeCentralManager()
            return
        }
        autoConnectIfReady()
        #else
        updateState {
            $0.connection = .error
            $0.lastError = "CoreBluetooth is unavailable in this build."
        }
        #endif
    }

    func startScanning() {
        #if canImport(CoreBluetooth)
        guard canInitializeBluetooth(explicitRequest: true) else { return }
        cancelPermissionProbeScan(stopActiveScan: true)
        autoConnectEnabled = true
        scanningForAutoConnect = false
        manualScanRequested = true
        if central == nil {
            updateState { $0.connection = .idle }
            central = makeCentralManager()
            return
        }
        if recreateCentralManagerForExplicitPowerAlertIfNeeded() {
            return
        }
        scanIfReady(serviceFiltered: false)
        #else
        updateState {
            $0.connection = .error
            $0.lastError = "CoreBluetooth is unavailable in this build."
        }
        #endif
    }

    func requestBluetoothAccess() {
        #if canImport(CoreBluetooth)
        guard canInitializeBluetooth(explicitRequest: true) else { return }
        cancelPermissionProbeScan(stopActiveScan: true)
        permissionProbeScanRequested = true
        autoConnectEnabled = true
        scanningForAutoConnect = false
        manualScanRequested = true
        if central == nil {
            updateState { $0.connection = .idle }
            central = makeCentralManager()
            scheduleForcedPermissionProbeScan(allowWhileManualRequest: true)
            return
        }
        if recreateCentralManagerForExplicitPowerAlertIfNeeded() {
            scheduleForcedPermissionProbeScan(allowWhileManualRequest: true)
            return
        }
        runBluetoothPermissionProbeScanIfReady(forceWhenNotDetermined: true, allowWhileManualRequest: true)
        scanIfReady(serviceFiltered: false)
        #else
        updateState {
            $0.connection = .error
            $0.lastError = "CoreBluetooth is unavailable in this build."
        }
        #endif
    }

    func primeBluetoothPermission() {
        #if canImport(CoreBluetooth)
        guard canInitializeBluetooth(explicitRequest: true) else { return }
        permissionProbeScanRequested = true
        if central == nil {
            updateState { $0.connection = .idle }
            central = makeCentralManager()
            scheduleForcedPermissionProbeScan(allowWhileManualRequest: false)
        } else {
            if recreateCentralManagerForExplicitPowerAlertIfNeeded() {
                scheduleForcedPermissionProbeScan(allowWhileManualRequest: false)
                return
            }
            runBluetoothPermissionProbeScanIfReady(forceWhenNotDetermined: true, allowWhileManualRequest: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.runBluetoothPermissionProbeScanIfReady(forceWhenNotDetermined: true, allowWhileManualRequest: false)
        }
        #endif
    }

    func connect(to candidate: WearableDeviceCandidate) {
        #if canImport(CoreBluetooth)
        autoConnectEnabled = true
        scanningForAutoConnect = false
        manualScanRequested = false
        guard let peripheral = discoveredPeripherals[candidate.id] else {
            updateState {
                $0.connection = .error
                $0.lastError = "Selected wearable candidate is no longer available."
            }
            return
        }
        central?.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        hasSentInitSequence = false
        reassembler = FrameReassembler()
        updateState {
            $0.connection = .connecting
            $0.deviceID = candidate.id
            $0.name = candidate.name
            $0.rssi = candidate.rssi
            $0.batteryPercent = nil
            $0.isCharging = nil
            $0.isOnWrist = nil
            $0.lastError = nil
        }
        central?.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
        #else
        updateState {
            $0.connection = .error
            $0.lastError = "CoreBluetooth is unavailable in this build."
        }
        #endif
    }

    #if canImport(CoreBluetooth)
    private func makeCentralManager() -> CBCentralManager {
        CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: Self.restorationIdentifier
        ])
    }

    private var permissionProbeServiceUUID: CBUUID {
        CBUUID(string: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
    }

    private func scheduleForcedPermissionProbeScan(allowWhileManualRequest: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.runBluetoothPermissionProbeScanIfReady(
                forceWhenNotDetermined: true,
                allowWhileManualRequest: allowWhileManualRequest
            )
        }
    }

    private func recreateCentralManagerForExplicitPowerAlertIfNeeded() -> Bool {
        guard central?.state == .poweredOff else { return false }
        updateState {
            $0.connection = .disconnected
            $0.lastError = bluetoothPoweredOffMessage()
        }
        central?.stopScan()
        central = makeCentralManager()
        return true
    }

    private func runBluetoothPermissionProbeScanIfReady(
        forceWhenNotDetermined: Bool = false,
        allowWhileManualRequest: Bool = false
    ) {
        guard permissionProbeScanRequested else { return }
        let canProbeNormally = central?.state == .poweredOn
        let canForceUndeterminedProbe = forceWhenNotDetermined && CBManager.authorization == .notDetermined
        guard canProbeNormally || canForceUndeterminedProbe else { return }
        permissionProbeScanRequested = false
        if !allowWhileManualRequest {
            guard !manualScanRequested, !autoConnectEnabled else { return }
        }
        permissionProbeScanActive = true
        central?.scanForPeripherals(withServices: [permissionProbeServiceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        let stopWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.permissionProbeScanActive else { return }
            self.central?.stopScan()
            self.permissionProbeScanActive = false
            self.permissionProbeStopWorkItem = nil
        }
        permissionProbeStopWorkItem?.cancel()
        permissionProbeStopWorkItem = stopWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: stopWorkItem)
    }

    private func cancelPermissionProbeScan(stopActiveScan: Bool) {
        permissionProbeScanRequested = false
        permissionProbeStopWorkItem?.cancel()
        permissionProbeStopWorkItem = nil
        if stopActiveScan, permissionProbeScanActive {
            central?.stopScan()
        }
        permissionProbeScanActive = false
    }

    private func canInitializeBluetooth(explicitRequest: Bool) -> Bool {
        switch CBManager.authorization {
        case .allowedAlways:
            return true
        case .notDetermined:
            return true
        case .denied:
            updateState {
                $0.connection = .error
                $0.lastError = "Bluetooth permission is off for Whoordan. Allow Bluetooth access in iOS Settings, then scan again."
            }
            return false
        case .restricted:
            updateState {
                $0.connection = .error
                $0.lastError = "Bluetooth access is restricted on this iPhone."
            }
            return false
        @unknown default:
            return true
        }
    }

    private func bluetoothAuthorizationLabel() -> String {
        switch CBManager.authorization {
        case .allowedAlways:
            return "allowed"
        case .notDetermined:
            return "not determined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        @unknown default:
            return "unknown"
        }
    }

    private func bluetoothPoweredOffMessage() -> String {
        "CoreBluetooth state: poweredOff. iOS says Bluetooth is off or unavailable to apps. Open the iPhone Settings app, turn Bluetooth on, then return to Whoordan; when CoreBluetooth becomes poweredOn, Whoordan will request app permission and scan. App authorization: \(bluetoothAuthorizationLabel())."
    }
    #endif

    func stopAll() {
        #if canImport(CoreBluetooth)
        autoConnectEnabled = false
        scanningForAutoConnect = false
        manualScanRequested = false
        cancelPermissionProbeScan(stopActiveScan: true)
        sendRealtimeDisableCommands()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        central?.stopScan()
        peripheral = nil
        commandCharacteristic = nil
        notifyCharacteristics.removeAll()
        subscribedNotifyUUIDs.removeAll()
        hasSentInitSequence = false
        discoveredPeripherals.removeAll()
        #endif
        updateState {
            $0.connection = .disconnected
            $0.payloadProcessing.realtimeStreamActive = false
        }
    }

    func startRawCapture(scenario: WearableCaptureScenario) {
        #if DEBUG
        rawCaptureScenario = scenario
        rawPayloadCapture = WearableRawPayloadCapture(scenario: scenario, sessionLabel: scenario.label)
        updateState {
            if let rawPayloadCapture {
                $0.rawCaptureRecordCount = 0
                $0.rawCapture = rawPayloadCapture.diagnostics(
                    lastDirection: nil,
                    lastDecodedPacketType: nil,
                    lastCapturedAt: nil,
                    lastError: nil
                )
            } else {
                $0.rawCapture = WearableCaptureDiagnostics(
                    isActive: false,
                    scenario: scenario,
                    recordCount: $0.rawCaptureRecordCount,
                    maxRecords: 0,
                    lastCapturedAt: nil,
                    lastDirection: nil,
                    lastDecodedPacketType: nil,
                    fileFingerprint: nil,
                    lastError: "Unable to create local capture file."
                )
            }
        }
        #else
        rawCaptureScenario = scenario
        updateState {
            $0.rawCapture = WearableCaptureDiagnostics(
                isActive: false,
                scenario: scenario,
                recordCount: $0.rawCaptureRecordCount,
                maxRecords: 0,
                lastCapturedAt: nil,
                lastDirection: nil,
                lastDecodedPacketType: nil,
                fileFingerprint: nil,
                lastError: "Raw BLE capture is disabled in production builds."
            )
        }
        #endif
    }

    func stopRawCapture() {
        rawPayloadCapture = nil
        updateState {
            $0.rawCapture.isActive = false
            $0.rawCapture.lastError = nil
        }
    }

    func finishRawCapture(recordingName: String) -> WearableRawPayloadCaptureSave? {
        guard let rawPayloadCapture else {
            updateState {
                $0.rawCapture.lastError = "No active capture is recording."
            }
            return nil
        }
        do {
            let saved = try rawPayloadCapture.save(named: recordingName)
            self.rawPayloadCapture = nil
            updateState {
                $0.rawCapture.isActive = false
                $0.rawCapture.scenario = rawCaptureScenario
                $0.rawCapture.recordCount = saved.recordCount
                $0.rawCapture.lastSavedRecordingName = saved.recordingName
                $0.rawCapture.lastSavedFileName = saved.fileName
                $0.rawCapture.fileFingerprint = WearablePrivacy.fingerprint(saved.fileName)
                $0.rawCapture.lastError = nil
            }
            return saved
        } catch {
            updateState {
                $0.rawCapture.lastError = "Unable to save named capture file."
            }
            return nil
        }
    }

    func updateRawCaptureScenario(_ scenario: WearableCaptureScenario) {
        rawCaptureScenario = scenario
        rawPayloadCapture?.scenario = scenario
        rawPayloadCapture?.sessionLabel = scenario.label
        updateState {
            $0.rawCapture.scenario = scenario
        }
    }

    func exportRawCaptureArchive() throws -> URL {
        try WearableRawPayloadCapture.makeExportArchive()
    }

    func updateSyntheticCalibrationContext(_ context: WearableSyntheticCalibrationContext) {
        continuousRawPayloadCapture?.updateSyntheticCalibrationContext(context)
    }

    func writeCommand(_ data: Data, requiresResponse: Bool) async throws {
        #if canImport(CoreBluetooth)
        guard let peripheral, let commandCharacteristic else {
            throw WearableBLEError.notConnected
        }
        let type: CBCharacteristicWriteType
        if requiresResponse && commandCharacteristic.properties.contains(.write) {
            type = .withResponse
        } else if commandCharacteristic.properties.contains(.writeWithoutResponse) {
            type = .withoutResponse
        } else if commandCharacteristic.properties.contains(.write) {
            type = .withResponse
        } else {
            throw WearableBLEError.notWritable
        }
        peripheral.writeValue(data, for: commandCharacteristic, type: type)
        recordCapturedPayload(data, characteristicUUID: commandCharacteristic.uuid.uuidString, direction: .write)
        #endif
        sentCommands.append(data)
        updateState { $0.lastPacketAt = Date() }
    }

    private func recordCapturedPayload(
        _ data: Data,
        characteristicUUID: String,
        direction: WearableCaptureDirection,
        decodedPacketType: String? = nil
    ) {
        let decoded = WearablePacketDecoder.decode(frame: data)
        let packetType = decodedPacketType ?? decoded?.packetType.description ?? packetTypeDescription(from: data)
        let capturedAt = Date()
        let appState = appStateLabel()
        if direction == .notify {
            classifyNotifyGapIfNeeded(capturedAt: capturedAt, appState: appState)
        }
        let continuousCount = continuousRawPayloadCapture?.record(
            data: data,
            characteristicUUID: characteristicUUID,
            direction: direction,
            decodedPacketType: packetType,
            connectionState: currentDeviceState.connection,
            rssi: currentDeviceState.rssi,
            batteryPercent: currentDeviceState.batteryPercent,
            isCharging: currentDeviceState.isCharging,
            deviceTime: captureDeviceTime(from: decoded),
            appState: appState,
            appVersion: appVersionLabel(),
            deviceModel: deviceModelLabel()
        )
        if continuousRawPayloadCapture != nil && continuousCount == nil {
            recordControlPlaneEvent(kind: .writerError, message: "Continuous raw payload writer failed.")
        }
        guard let rawPayloadCapture else { return }
        let count = rawPayloadCapture.record(
            data: data,
            characteristicUUID: characteristicUUID,
            direction: direction,
            decodedPacketType: packetType,
            connectionState: currentDeviceState.connection,
            rssi: currentDeviceState.rssi,
            batteryPercent: currentDeviceState.batteryPercent,
            isCharging: currentDeviceState.isCharging,
            deviceTime: captureDeviceTime(from: decoded),
            appState: appState,
            appVersion: appVersionLabel(),
            deviceModel: deviceModelLabel(),
            sessionLabel: rawPayloadCapture.sessionLabel
        )
        if count == nil {
            recordControlPlaneEvent(kind: .writerError, message: "Manual raw payload writer failed.")
        }
        updateState {
            if let count {
                $0.rawCaptureRecordCount = count
                $0.rawCapture = rawPayloadCapture.diagnostics(
                    lastDirection: direction,
                    lastDecodedPacketType: packetType,
                    lastCapturedAt: capturedAt,
                    lastError: nil
                )
            }
        }
    }

    private func classifyNotifyGapIfNeeded(capturedAt: Date, appState: String) {
        defer {
            lastNotifyPayloadAt = capturedAt
            lastNotifyConnectionState = currentDeviceState.connection
            lastNotifyAppState = appState
        }
        guard let lastNotifyPayloadAt else { return }
        let gapSeconds = capturedAt.timeIntervalSince(lastNotifyPayloadAt)
        guard let status = WearableGapClassifier.classify(
            gapSeconds: gapSeconds,
            previousConnection: lastNotifyConnectionState,
            currentConnection: currentDeviceState.connection,
            previousAppState: lastNotifyAppState,
            currentAppState: appState,
            isOnWrist: currentDeviceState.isOnWrist,
            batteryPercent: currentDeviceState.batteryPercent
        ) else { return }
        let roundedGap = Int(gapSeconds.rounded())
        updateState {
            $0.syncDiagnostics.lastGapStatus = status
            $0.syncDiagnostics.lastGapSeconds = roundedGap
        }
        recordControlPlaneEvent(
            kind: .gapClassified,
            message: "\(status.label) gap classified over \(roundedGap)s."
        )
    }

    private func packetTypeDescription(from data: Data) -> String? {
        guard let inner = try? WearableProtocol.decodeFrame(data),
              let type = inner.first.flatMap(WearablePacketType.init(rawValue:)) else {
            return nil
        }
        return type.description
    }

    private func captureDeviceTime(from decoded: WearableDecodedPacket?) -> Date? {
        if let timestamp = decoded?.event?.timestamp {
            return timestamp
        }
        if let rawTimestamp = decoded?.dataRecord?.rawTimestamp {
            return Date(timeIntervalSince1970: TimeInterval(rawTimestamp))
        }
        if let rtcSeconds = decoded?.commandResponse?.hello?.rtcSeconds {
            return Date(timeIntervalSince1970: TimeInterval(rtcSeconds))
        }
        return nil
    }

    private func appStateLabel() -> String {
        #if canImport(UIKit)
        switch UIApplication.shared.applicationState {
        case .active:
            return "foreground"
        case .background:
            return "background"
        case .inactive:
            return "inactive"
        @unknown default:
            return "unknown"
        }
        #else
        return "unknown"
        #endif
    }

    private func appVersionLabel() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case let (short?, _) where !short.isEmpty:
            return short
        case let (_, build?) where !build.isEmpty:
            return build
        default:
            return "unknown"
        }
    }

    private func deviceModelLabel() -> String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "unknown"
        #endif
    }

    private func updateState(_ update: (inout WearableDeviceState) -> Void) {
        update(&currentDeviceState)
        onStateChange?(currentDeviceState)
    }

    private func recordControlPlaneEvent(
        kind: WearableControlPlaneEventKind,
        message: String,
        occurredAt: Date = Date()
    ) {
        let event = WearableControlPlaneEvent(
            kind: kind,
            message: message,
            occurredAt: occurredAt,
            deviceID: currentDeviceState.deviceID,
            connectionState: currentDeviceState.connection
        )
        updateState {
            $0.syncDiagnostics.lastControlPlaneEvent = event
            $0.syncDiagnostics.recentControlPlaneEvents.append(event)
            if $0.syncDiagnostics.recentControlPlaneEvents.count > Self.maxRecentControlPlaneEvents {
                $0.syncDiagnostics.recentControlPlaneEvents.removeFirst(
                    $0.syncDiagnostics.recentControlPlaneEvents.count - Self.maxRecentControlPlaneEvents
                )
            }
        }
        onControlPlaneEvent?(event)
    }
}

enum WearableBLEError: LocalizedError {
    case notConnected
    case notWritable

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "A connected wearable command characteristic is required."
        case .notWritable:
            return "The wearable command characteristic is not writable."
        }
    }
}

final class WearableRawPayloadCapture {
    private var fileURL: URL
    private let directoryURL: URL
    private let maxRecords: Int
    private var writtenRecords = 0
    private let encoder = JSONEncoder()
    var scenario: WearableCaptureScenario
    var sessionLabel: String?
    var filePath: String { fileURL.path }

    init?(
        scenario: WearableCaptureScenario = .unknown,
        maxRecords: Int = 10_000,
        directoryURL: URL? = nil,
        sessionLabel: String? = nil
    ) {
        let baseURL = directoryURL ?? Self.documentsDirectoryURL()
        guard let baseURL else {
            return nil
        }
        let directory = baseURL.appendingPathComponent("whoordan-ble-debug", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let warning = """
            Raw BLE payload capture is private health/wearable debug data.
            Do not commit this directory or paste payload contents into chat, docs, logs, or tests.
            Do not upload this directory to Supabase or include it in normal exports.
            Delete this directory after local analysis.
            """
            try warning.data(using: .utf8)?.write(to: directory.appendingPathComponent("README_DO_NOT_COMMIT.txt"), options: [.atomic])
        } catch {
            return nil
        }
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        self.directoryURL = directory
        self.fileURL = directory.appendingPathComponent("raw-payloads-\(timestamp).jsonl")
        self.maxRecords = max(1, min(maxRecords, 50_000))
        self.scenario = scenario
        self.sessionLabel = Self.cleanSessionLabel(sessionLabel)
    }

    static func documentsDirectoryURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static func defaultDirectoryURL() -> URL? {
        documentsDirectoryURL()?.appendingPathComponent("whoordan-ble-debug", isDirectory: true)
    }

    static func fileNameBase(for recordingName: String) -> String {
        let lowercased = recordingName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = ""
        var previousWasSeparator = false
        for scalar in lowercased.unicodeScalars {
            let isASCIILetter = (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
            let isDigit = (48...57).contains(Int(scalar.value))
            if isASCIILetter || isDigit {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("_")
                previousWasSeparator = true
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return trimmed.isEmpty ? "recording" : trimmed
    }

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> WearableRawPayloadCapture? {
        guard environment["WHOORDAN_RAW_BLE_CAPTURE"] == "1" || arguments.contains("--whoordan-raw-ble-capture") else {
            return nil
        }
        let maxRecords = environment["WHOORDAN_RAW_BLE_CAPTURE_MAX"].flatMap(Int.init) ?? 10_000
        let scenario = environment["WHOORDAN_RAW_BLE_CAPTURE_SCENARIO"]
            .flatMap(WearableCaptureScenario.init(rawValue:)) ?? .unknown
        return WearableRawPayloadCapture(scenario: scenario, maxRecords: maxRecords, sessionLabel: scenario.label)
    }

    func record(
        data: Data,
        characteristicUUID: String,
        direction: WearableCaptureDirection,
        decodedPacketType: String?,
        connectionState: WearableConnectionState,
        rssi: Int?,
        batteryPercent: Int? = nil,
        isCharging: Bool? = nil,
        deviceTime: Date?,
        appState: String,
        appVersion: String = "unknown",
        deviceModel: String = "unknown",
        sessionLabel: String? = nil
    ) -> Int? {
        guard writtenRecords < maxRecords else { return writtenRecords }
        let packetType = decodedPacketType
        let record = WearableRawPayloadCaptureRecord(
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            characteristicUUID: characteristicUUID,
            byteCount: data.count,
            payloadLength: data.count,
            direction: direction,
            payloadBase64: data.base64EncodedString(),
            packetType: packetType,
            decodedPacketType: decodedPacketType,
            connectionState: connectionState,
            rssi: rssi,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            deviceTimeUnix: deviceTime.map { Int($0.timeIntervalSince1970) },
            appState: appState,
            scenario: scenario,
            appVersion: appVersion,
            deviceModel: deviceModel,
            sessionLabel: Self.cleanSessionLabel(sessionLabel) ?? self.sessionLabel
        )
        guard let encoded = try? encoder.encode(record) else { return nil }
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: encoded)
            try handle.write(contentsOf: Data([0x0A]))
            writtenRecords += 1
        } catch {
            try? encoded.write(to: fileURL, options: [.atomic])
            writtenRecords += 1
        }
        return writtenRecords
    }

    func save(named recordingName: String) throws -> WearableRawPayloadCaptureSave {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        let base = Self.fileNameBase(for: recordingName)
        var sequence = nextSequence(for: base)
        var destinationURL = directoryURL.appendingPathComponent(Self.fileName(base: base, sequence: sequence))
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            sequence += 1
            destinationURL = directoryURL.appendingPathComponent(Self.fileName(base: base, sequence: sequence))
        }
        try FileManager.default.moveItem(at: fileURL, to: destinationURL)
        fileURL = destinationURL
        return WearableRawPayloadCaptureSave(
            recordingName: recordingName.trimmingCharacters(in: .whitespacesAndNewlines),
            fileName: destinationURL.lastPathComponent,
            recordCount: writtenRecords
        )
    }

    func diagnostics(
        lastDirection: WearableCaptureDirection?,
        lastDecodedPacketType: String?,
        lastCapturedAt: Date?,
        lastSaved: WearableRawPayloadCaptureSave? = nil,
        lastError: String?
    ) -> WearableCaptureDiagnostics {
        WearableCaptureDiagnostics(
            isActive: true,
            scenario: scenario,
            recordCount: writtenRecords,
            maxRecords: maxRecords,
            lastCapturedAt: lastCapturedAt,
            lastDirection: lastDirection,
            lastDecodedPacketType: lastDecodedPacketType,
            fileFingerprint: WearablePrivacy.fingerprint(fileURL.lastPathComponent),
            lastSavedRecordingName: lastSaved?.recordingName,
            lastSavedFileName: lastSaved?.fileName,
            lastError: lastError
        )
    }

    private static func fileName(base: String, sequence: Int) -> String {
        "\(base)_\(String(format: "%02d", sequence)).jsonl"
    }

    private func nextSequence(for base: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: base)
        let pattern = "^\(escaped)_(\\d+)\\.jsonl$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path)) ?? []
        let highest = fileNames.compactMap { fileName -> Int? in
            let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
            guard let match = regex.firstMatch(in: fileName, range: range),
                  match.numberOfRanges == 2,
                  let sequenceRange = Range(match.range(at: 1), in: fileName) else {
                return nil
            }
            return Int(fileName[sequenceRange])
        }.max()
        return (highest ?? 0) + 1
    }

    static func makeExportArchive(
        directoryURL: URL? = nil,
        createdAt: Date = Date()
    ) throws -> URL {
        let directory = directoryURL ?? defaultDirectoryURL()
        guard let directory else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: createdAt).replacingOccurrences(of: ":", with: "-")
        let archiveURL = directory.appendingPathComponent("whoordan-ble-debug-export-\(timestamp).zip")
        let sourceURLs = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let files = sourceURLs
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return values?.isDirectory != true && url.pathExtension.lowercased() != "zip"
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var entries: [(name: String, data: Data, modifiedAt: Date)] = []
        for file in files {
            if let data = try? Data(contentsOf: file) {
                entries.append((file.lastPathComponent, data, createdAt))
            }
        }
        let manifestContents = entries.map { "\"\($0.name)\"" }.joined(separator: ", ")
        let manifest = """
        {
          "schemaVersion": 1,
          "createdAt": "\(ISO8601DateFormatter().string(from: createdAt))",
          "privacy": "Local BLE debug export. Do not commit, paste, or upload unless intentionally sharing for decoding analysis.",
          "contents": [\(manifestContents)]
        }
        """
        entries.append(("EXPORT_MANIFEST.json", Data(manifest.utf8), createdAt))
        let archiveData = makeZipData(entries: entries)
        try archiveData.write(to: archiveURL, options: [.atomic])
        return archiveURL
    }

    private static func cleanSessionLabel(_ label: String?) -> String? {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(80))
    }

    private static func makeZipData(entries: [(name: String, data: Data, modifiedAt: Date)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var entryCount: UInt16 = 0
        for entry in entries {
            guard let nameData = entry.name.data(using: .utf8) else { continue }
            let localHeaderOffset = UInt32(archive.count)
            let crc = WearableProtocol.crc32(entry.data)
            let size = UInt32(entry.data.count)
            let dos = dosDateTime(from: entry.modifiedAt)

            appendUInt32(0x04034B50, to: &archive)
            appendUInt16(20, to: &archive)
            appendUInt16(0x0800, to: &archive)
            appendUInt16(0, to: &archive)
            appendUInt16(dos.time, to: &archive)
            appendUInt16(dos.date, to: &archive)
            appendUInt32(crc, to: &archive)
            appendUInt32(size, to: &archive)
            appendUInt32(size, to: &archive)
            appendUInt16(UInt16(nameData.count), to: &archive)
            appendUInt16(0, to: &archive)
            archive.append(nameData)
            archive.append(entry.data)

            appendUInt32(0x02014B50, to: &centralDirectory)
            appendUInt16(20, to: &centralDirectory)
            appendUInt16(20, to: &centralDirectory)
            appendUInt16(0x0800, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(dos.time, to: &centralDirectory)
            appendUInt16(dos.date, to: &centralDirectory)
            appendUInt32(crc, to: &centralDirectory)
            appendUInt32(size, to: &centralDirectory)
            appendUInt32(size, to: &centralDirectory)
            appendUInt16(UInt16(nameData.count), to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)
            appendUInt32(0, to: &centralDirectory)
            appendUInt32(localHeaderOffset, to: &centralDirectory)
            centralDirectory.append(nameData)
            entryCount += 1
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        appendUInt32(0x06054B50, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(entryCount, to: &archive)
        appendUInt16(entryCount, to: &archive)
        appendUInt32(UInt32(centralDirectory.count), to: &archive)
        appendUInt32(centralDirectoryOffset, to: &archive)
        appendUInt16(0, to: &archive)
        return archive
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }

    private static func dosDateTime(from date: Date) -> (date: UInt16, time: UInt16) {
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let year = max((components.year ?? 1980) - 1980, 0)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2
        return (
            date: UInt16((year << 9) | (month << 5) | day),
            time: UInt16((hour << 11) | (minute << 5) | second)
        )
    }
}

final class WearableContinuousRawPayloadCapture {
    private let directoryURL: URL
    private let maxRecordsPerFile: Int
    private let maxFiles: Int
    private let dateProvider: () -> Date
    private let encoder = JSONEncoder()
    private var fileURL: URL
    private var fileSequence = 1
    private var writtenRecordsInCurrentFile = 0
    private var writtenRecordsTotal = 0
    private var syntheticCalibrationContext = WearableSyntheticCalibrationContext.person1Default()

    var filePath: String { fileURL.path }

    init?(
        directoryURL: URL? = nil,
        maxRecordsPerFile: Int = 25_000,
        maxFiles: Int = 384,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        let baseURL = directoryURL ?? WearableRawPayloadCapture.documentsDirectoryURL()
        guard let baseURL else {
            return nil
        }
        let directory = baseURL.appendingPathComponent("whoordan-ble-debug", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let warning = """
            Raw BLE payload capture is private health/wearable debug data.
            Whoordan keeps a rolling local JSONL capture here for decoder QA.
            Do not commit this directory or paste payload contents into chat, docs, logs, or tests.
            Do not upload this directory to Supabase or include it in normal exports.
            Delete this directory after local analysis.
            """
            try warning.data(using: .utf8)?.write(to: directory.appendingPathComponent("README_DO_NOT_COMMIT.txt"), options: [.atomic])
        } catch {
            return nil
        }
        self.directoryURL = directory
        self.maxRecordsPerFile = max(1, min(maxRecordsPerFile, 50_000))
        self.maxFiles = max(1, min(maxFiles, 384))
        self.dateProvider = dateProvider
        self.fileURL = directory.appendingPathComponent("continuous_raw-payloads-placeholder.jsonl")
        self.fileURL = uniqueFileURL()
        pruneOldContinuousFiles()
    }

    func updateSyntheticCalibrationContext(_ context: WearableSyntheticCalibrationContext) {
        syntheticCalibrationContext = context
    }

    @discardableResult
    func record(
        data: Data,
        characteristicUUID: String,
        direction: WearableCaptureDirection,
        decodedPacketType: String?,
        connectionState: WearableConnectionState,
        rssi: Int?,
        batteryPercent: Int? = nil,
        isCharging: Bool? = nil,
        deviceTime: Date?,
        appState: String,
        appVersion: String = "unknown",
        deviceModel: String = "unknown"
    ) -> Int? {
        rotateIfNeeded()
        let now = dateProvider()
        let record = WearableRawPayloadCaptureRecord(
            capturedAt: ISO8601DateFormatter().string(from: now),
            characteristicUUID: characteristicUUID,
            byteCount: data.count,
            payloadLength: data.count,
            direction: direction,
            payloadBase64: data.base64EncodedString(),
            packetType: decodedPacketType,
            decodedPacketType: decodedPacketType,
            connectionState: connectionState,
            rssi: rssi,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            deviceTimeUnix: deviceTime.map { Int($0.timeIntervalSince1970) },
            appState: appState,
            scenario: .unknown,
            appVersion: appVersion,
            deviceModel: deviceModel,
            sessionLabel: "continuous"
        )
        guard let encoded = try? encoder.encode(record) else { return nil }
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: encoded)
            try handle.write(contentsOf: Data([0x0A]))
            writtenRecordsInCurrentFile += 1
            writtenRecordsTotal += 1
            writeSyntheticCalibrationRecord(
                linkedRawPayloadFileURL: fileURL,
                linkedRawPayloadRecordIndex: writtenRecordsInCurrentFile,
                rawRecord: record,
                data: data,
                generatedAt: now
            )
            if writtenRecordsInCurrentFile == 1 {
                pruneOldContinuousFiles()
            }
        } catch {
            return nil
        }
        return writtenRecordsTotal
    }

    private func writeSyntheticCalibrationRecord(
        linkedRawPayloadFileURL: URL,
        linkedRawPayloadRecordIndex: Int,
        rawRecord: WearableRawPayloadCaptureRecord,
        data: Data,
        generatedAt: Date
    ) {
        let calibrationURL = syntheticCalibrationURL(for: linkedRawPayloadFileURL)
        let record = makeSyntheticCalibrationRecord(
            linkedRawPayloadFileName: linkedRawPayloadFileURL.lastPathComponent,
            linkedRawPayloadRecordIndex: linkedRawPayloadRecordIndex,
            rawRecord: rawRecord,
            data: data,
            generatedAt: generatedAt
        )
        guard let encoded = try? encoder.encode(record) else { return }
        do {
            if !FileManager.default.fileExists(atPath: calibrationURL.path) {
                FileManager.default.createFile(atPath: calibrationURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: calibrationURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: encoded)
            try handle.write(contentsOf: Data([0x0A]))
        } catch {
            return
        }
    }

    private func makeSyntheticCalibrationRecord(
        linkedRawPayloadFileName: String,
        linkedRawPayloadRecordIndex: Int,
        rawRecord: WearableRawPayloadCaptureRecord,
        data: Data,
        generatedAt: Date
    ) -> WearableSyntheticCalibrationRecord {
        let decoded = WearablePacketDecoder.decode(frame: data)
        let r10 = decoded?.dataRecord?.r10
        let estimatedSteps = r10.flatMap(WearableR10DerivedMetricEstimator.estimatedStepCount(from:))
        let isSleepLike = r10.flatMap(WearableR10DerivedMetricEstimator.estimatedSleepStage(from:)) != nil
        let motionIntensity = syntheticMotionIntensity(estimatedSteps: estimatedSteps, isSleepLike: isSleepLike, decoded: decoded)
        let metrics = syntheticMetrics(
            heartRateBPM: decoded?.heartRateBPM,
            skinTemperatureC: r10?.skinTemperatureC,
            motionIntensity: motionIntensity,
            fileName: linkedRawPayloadFileName,
            recordIndex: linkedRawPayloadRecordIndex,
            generatedAt: generatedAt
        )
        return WearableSyntheticCalibrationRecord(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            linkedRawPayloadFileName: linkedRawPayloadFileName,
            linkedRawPayloadRecordIndex: linkedRawPayloadRecordIndex,
            capturedAt: rawRecord.capturedAt,
            provenance: .syntheticCalibrationShadow,
            personID: syntheticCalibrationContext.personID,
            profile: syntheticCalibrationContext.profile,
            packetAnchor: WearableSyntheticCalibrationPacketAnchor(
                packetType: decoded?.packetType.description ?? rawRecord.packetType,
                decodedPacketType: rawRecord.decodedPacketType,
                recordType: decoded?.recordType,
                heartRateBPM: decoded?.heartRateBPM,
                skinTemperatureC: r10?.skinTemperatureC,
                motionIntensity: motionIntensity
            ),
            metrics: metrics,
            calibrationSource: syntheticCalibrationContext.calibrationSource,
            privacyNote: "Synthetic calibration shadow only; not a real health record, not synced, no raw payload included."
        )
    }

    private func syntheticMotionIntensity(
        estimatedSteps: Int?,
        isSleepLike: Bool,
        decoded: WearableDecodedPacket?
    ) -> Double {
        if isSleepLike { return 0.02 }
        if let estimatedSteps {
            return min(max(Double(estimatedSteps) / 24.0, 0.05), 1.0)
        }
        guard decoded?.packetType == .rawRealtimeData else { return 0.03 }
        return 0.12
    }

    private func syntheticMetrics(
        heartRateBPM: Int?,
        skinTemperatureC: Double?,
        motionIntensity: Double,
        fileName: String,
        recordIndex: Int,
        generatedAt: Date
    ) -> WearableSyntheticCalibrationMetrics {
        let profile = syntheticCalibrationContext.profile
        let hour = Self.fractionalHour(from: generatedAt)
        let circadian = sin(((hour - 14.0) / 24.0) * 2.0 * Double.pi)
        let sleepWindow = hour >= 22.0 || hour < 8.0
        let jitter = Self.stableNoise(key: "\(fileName):\(recordIndex)") - 0.5
        let dailyJitter = Self.stableNoise(key: "\(fileName):daily") - 0.5
        let restingHeartRate = Self.clamped(
            profile.baselineRestingHeartRateBPM + dailyJitter * 3.0 + (sleepWindow ? -1.5 : 1.0),
            42,
            85
        )
        let anchoredHeartRate = Double(heartRateBPM ?? 0)
        let heartRate = heartRateBPM == nil
            ? restingHeartRate + 8.0 + (motionIntensity * 62.0) + (circadian * 4.0) + (jitter * 6.0)
            : anchoredHeartRate
        let dayStrain = Self.clamped(
            (profile.baselineDayStrain * 0.55) + (motionIntensity * 13.0) + max(heartRate - restingHeartRate - 22.0, 0) / 12.0,
            0,
            21
        )
        let sleepMinutes = Self.clamped(
            profile.baselineSleepMinutes + (dailyJitter * 36.0) - (max(dayStrain - 10.0, 0) * 2.2),
            240,
            570
        )
        let sleepNeed = Self.clamped(
            profile.baselineSleepNeedMinutes + max(dayStrain - profile.baselineDayStrain, 0) * 4.0,
            360,
            620
        )
        let sleepDebt = Self.clamped(sleepNeed - sleepMinutes, -45, 240)
        let hrv = Self.clamped(
            profile.baselineHRVRMSSDMS - motionIntensity * 18.0 - max(sleepDebt, 0) * 0.04 + dailyJitter * 8.0,
            18,
            140
        )
        let sleepPerformance = Self.clamped((sleepMinutes / max(sleepNeed, 1)) * 100.0, 35, 100)
        let restorativeSleepPercent = Self.clamped(22.0 + (hrv - profile.baselineHRVRMSSDMS) * 0.08 + dailyJitter * 5.0, 8, 42)
        let recovery = Self.clamped(
            profile.baselineRecoveryPercent
                + ((hrv - profile.baselineHRVRMSSDMS) / max(profile.baselineHRVRMSSDMS, 1)) * 24.0
                - max(restingHeartRate - profile.baselineRestingHeartRateBPM, 0) * 1.3
                - max(sleepDebt, 0) * 0.055
                - max(dayStrain - 13.0, 0) * 1.5,
            1,
            99
        )
        let stress = Self.clamped(
            18.0 + motionIntensity * 54.0 + max(heartRate - restingHeartRate - 18.0, 0) * 0.45 - (hrv - profile.baselineHRVRMSSDMS) * 0.12,
            1,
            99
        )
        let activeEnergy = Self.clamped(
            140.0 + dayStrain * 38.0 + motionIntensity * 420.0 + (profile.weightKilograms - 69.0) * 4.0,
            40,
            1_500
        )
        let steps = Int(Self.clamped(1_500.0 + dayStrain * 650.0 + motionIntensity * 4_800.0, 0, 28_000).rounded())
        let skinDelta = Self.clamped((skinTemperatureC.map { $0 - 34.2 } ?? dailyJitter * 0.22), -2.5, 2.5)

        return WearableSyntheticCalibrationMetrics(
            heartRateBPM: Self.rounded(heartRate, digits: 1),
            restingHeartRateBPM: Self.rounded(restingHeartRate, digits: 1),
            hrvRMSSDMS: Self.rounded(hrv, digits: 1),
            respiratoryRate: Self.rounded(profile.baselineRespiratoryRate + max(stress - 45.0, 0) * 0.015 + jitter * 0.5, digits: 1),
            oxygenSaturationPercent: Self.rounded(
                Self.clamped(profile.baselineSpO2Percent - max(stress - 70.0, 0) * 0.01 + jitter * 0.15, 92, 100),
                digits: 1
            ),
            sleepMinutes: Self.rounded(sleepMinutes, digits: 1),
            sleepNeedMinutes: Self.rounded(sleepNeed, digits: 1),
            sleepDebtMinutes: Self.rounded(sleepDebt, digits: 1),
            sleepPerformancePercent: Self.rounded(sleepPerformance, digits: 1),
            sleepConsistencyPercent: Self.rounded(
                Self.clamped(82.0 - abs(dailyJitter) * 18.0 - max(sleepDebt, 0) * 0.03, 45, 98),
                digits: 1
            ),
            restorativeSleepPercent: Self.rounded(restorativeSleepPercent, digits: 1),
            recoveryPercent: Self.rounded(recovery, digits: 1),
            dayStrain: Self.rounded(dayStrain, digits: 1),
            activityStrain: Self.rounded(Self.clamped(dayStrain * (0.62 + motionIntensity * 0.25), 0, 21), digits: 1),
            activeEnergyKilocalories: Self.rounded(activeEnergy, digits: 0),
            stressPercent: Self.rounded(stress, digits: 1),
            vo2Max: Self.rounded(
                Self.clamped(
                    profile.baselineVO2Max
                        + (recovery - profile.baselineRecoveryPercent) * 0.035
                        - max(dayStrain - 14, 0) * 0.08,
                    25,
                    70
                ),
                digits: 1
            ),
            steps: steps,
            skinTemperatureDeltaC: Self.rounded(skinDelta, digits: 2)
        )
    }

    private func rotateIfNeeded() {
        guard writtenRecordsInCurrentFile >= maxRecordsPerFile else { return }
        fileSequence += 1
        writtenRecordsInCurrentFile = 0
        fileURL = uniqueFileURL()
        pruneOldContinuousFiles()
    }

    private func uniqueFileURL() -> URL {
        while true {
            let timestamp = ISO8601DateFormatter()
                .string(from: dateProvider())
                .replacingOccurrences(of: ":", with: "-")
            let candidate = directoryURL.appendingPathComponent(
                "continuous_raw-payloads-\(timestamp)-\(String(format: "%04d", fileSequence)).jsonl"
            )
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            fileSequence += 1
        }
    }

    private func syntheticCalibrationURL(for rawPayloadURL: URL) -> URL {
        let rawName = rawPayloadURL.lastPathComponent
        let calibrationName = rawName.replacingOccurrences(
            of: "continuous_raw-payloads-",
            with: "continuous_synthetic-calibration-"
        )
        return rawPayloadURL.deletingLastPathComponent().appendingPathComponent(calibrationName)
    }

    private func pruneOldContinuousFiles() {
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
        .filter {
            $0.lastPathComponent.hasPrefix("continuous_raw-payloads-")
                && $0.pathExtension.lowercased() == "jsonl"
        }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.lastPathComponent < rhs.lastPathComponent
            }
            return lhsDate < rhsDate
        }

        let retainedRawPayloadFiles = Set(files.suffix(maxFiles).map(\.lastPathComponent))
        if files.count > maxFiles {
            for file in files.prefix(files.count - maxFiles) where file != fileURL {
                try? FileManager.default.removeItem(at: file)
                try? FileManager.default.removeItem(at: syntheticCalibrationURL(for: file))
            }
        }
        pruneOrphanSyntheticCalibrationFiles(retainedRawPayloadFiles: retainedRawPayloadFiles)
    }

    private func pruneOrphanSyntheticCalibrationFiles(retainedRawPayloadFiles: Set<String>) {
        let calibrationFiles = ((try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
        .filter {
            $0.lastPathComponent.hasPrefix("continuous_synthetic-calibration-")
                && $0.pathExtension.lowercased() == "jsonl"
        }

        for file in calibrationFiles {
            let linkedRawFile = file.lastPathComponent.replacingOccurrences(
                of: "continuous_synthetic-calibration-",
                with: "continuous_raw-payloads-"
            )
            if !retainedRawPayloadFiles.contains(linkedRawFile) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private static func fractionalHour(from date: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(components.hour ?? 0)
            + (Double(components.minute ?? 0) / 60.0)
            + (Double(components.second ?? 0) / 3_600.0)
    }

    private static func stableNoise(key: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000.0
    }

    private static func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func rounded(_ value: Double, digits: Int) -> Double {
        let multiplier = pow(10.0, Double(digits))
        return (value * multiplier).rounded() / multiplier
    }

}

private extension WearableBLEService {
    static func sampleTimestampToken(_ date: Date) -> String {
        "\(Int((date.timeIntervalSince1970 * 1_000).rounded()))"
    }
}

#if canImport(CoreBluetooth)
extension WearableBLEService: CBCentralManagerDelegate, CBPeripheralDelegate {
    private var serviceUUID: CBUUID { CBUUID(string: WearableUUIDs.service) }
    private var commandUUID: CBUUID { CBUUID(string: WearableUUIDs.commandWrite) }
    private var standardHeartRateServiceUUID: CBUUID { CBUUID(string: StandardBLEUUIDs.heartRateService) }
    private var standardHeartRateMeasurementUUID: CBUUID { CBUUID(string: StandardBLEUUIDs.heartRateMeasurement) }
    private var standardBatteryLevelUUID: CBUUID { CBUUID(string: StandardBLEUUIDs.batteryLevel) }
    private var notifyUUIDs: [CBUUID] {
        [
            CBUUID(string: WearableUUIDs.commandResponse),
            CBUUID(string: WearableUUIDs.events),
            CBUUID(string: WearableUUIDs.sensorData),
            CBUUID(string: WearableUUIDs.diagnostics)
        ]
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            runBluetoothPermissionProbeScanIfReady()
            if manualScanRequested {
                scanIfReady(serviceFiltered: false)
            } else if autoConnectEnabled {
                autoConnectIfReady()
            }
        case .unsupported:
            updateState {
                $0.connection = .error
                $0.lastError = "Bluetooth is unsupported on this device."
            }
        case .unauthorized:
            updateState {
                $0.connection = .error
                $0.lastError = "Bluetooth permission is off for Whoordan. Allow Bluetooth access in iOS Settings, then scan again."
            }
        case .poweredOff:
            runBluetoothPermissionProbeScanIfReady(forceWhenNotDetermined: true, allowWhileManualRequest: manualScanRequested)
            updateState {
                $0.connection = .disconnected
                $0.lastError = bluetoothPoweredOffMessage()
            }
        case .resetting, .unknown:
            updateState { $0.connection = .idle }
        @unknown default:
            updateState {
                $0.connection = .error
                $0.lastError = "Bluetooth is in an unknown state."
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        guard let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
              let restoredPeripheral = restoredPeripherals.first else {
            return
        }
        recordControlPlaneEvent(kind: .centralRestored, message: "CoreBluetooth restoration delivered peripherals.")
        autoConnectEnabled = true
        scanningForAutoConnect = false
        manualScanRequested = false
        restoredPeripherals.forEach { peripheral in
            discoveredPeripherals[peripheral.identifier.uuidString] = peripheral
            peripheral.delegate = self
        }
        peripheral = restoredPeripheral
        updateState {
            $0.deviceID = restoredPeripheral.identifier.uuidString
            $0.name = restoredPeripheral.name ?? $0.name
            $0.connection = restoredPeripheral.state == .connected ? .discoveringServices : .connecting
            $0.lastError = nil
        }
        switch restoredPeripheral.state {
        case .connected:
            restoredPeripheral.discoverServices(nil)
        case .connecting:
            break
        case .disconnected, .disconnecting:
            if autoConnectEnabled {
                central.connect(restoredPeripheral, options: [
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                ])
            }
        @unknown default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !permissionProbeScanActive else { return }
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let advertisedCBUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisedServices = advertisedCBUUIDs.map(\.uuidString)
            .sorted()
        let isProtocolCapable = WearableServiceCompatibility.isProtocolCapable(
            advertisedServiceUUIDs: advertisedServices
        )
        let candidate = WearableDeviceCandidate(
            id: peripheral.identifier.uuidString,
            name: advertisedName ?? peripheral.name,
            rssi: RSSI.intValue,
            advertisedServiceUUIDs: advertisedServices,
            matchesExpectedService: isProtocolCapable,
            isConnectedToPhone: false,
            isPreferredOwnedDevice: isPreferredDeviceName(advertisedName ?? peripheral.name),
            lastSeen: Date()
        )
        discoveredPeripherals[candidate.id] = peripheral
        updateState {
            $0.connection = .scanning
            $0.rssi = RSSI.intValue
            $0.lastError = nil
        }
        upsert(candidate: candidate)
        if autoConnectEnabled && (candidate.matchesExpectedService || candidate.isPreferredOwnedDevice) {
            connect(to: candidate)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        recordControlPlaneEvent(kind: .connected, message: "Wearable BLE link connected.")
        updateState {
            $0.connection = .discoveringServices
            $0.lastError = nil
        }
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        updateState {
            $0.connection = .error
            $0.batteryPercent = nil
            $0.isCharging = nil
            $0.isOnWrist = nil
            $0.lastError = error?.localizedDescription ?? "Failed to connect to wearable."
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        recordControlPlaneEvent(kind: .disconnected, message: error == nil ? "Wearable BLE link disconnected." : "Wearable BLE link disconnected with error.")
        self.peripheral = nil
        commandCharacteristic = nil
        notifyCharacteristics.removeAll()
        subscribedNotifyUUIDs.removeAll()
        hasSentInitSequence = false
        reassembler = FrameReassembler()
        updateState {
            $0.connection = .disconnected
            $0.batteryPercent = nil
            $0.isCharging = nil
            $0.isOnWrist = nil
            $0.lastError = error?.localizedDescription
            $0.payloadProcessing.realtimeStreamActive = false
        }
        if autoConnectEnabled {
            autoConnectIfReady()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            updateState {
                $0.connection = .error
                $0.lastError = error.localizedDescription
            }
            return
        }
        let services = peripheral.services ?? []
        recordControlPlaneEvent(kind: .servicesDiscovered, message: "Wearable services discovered.")
        let discoveredServiceUUIDs = services.map(\.uuid.uuidString).sorted()
        let hasProtocolService = services.contains(where: { $0.uuid == serviceUUID })
        let hasStandardHeartRateService = services.contains(where: { $0.uuid == standardHeartRateServiceUUID })
        guard hasProtocolService || hasStandardHeartRateService else {
            updateState {
                $0.connection = .error
                $0.discoveredUUIDs = discoveredServiceUUIDs
                $0.lastError = "Expected wearable protocol or Bluetooth Heart Rate service was not discovered."
            }
            return
        }
        updateState {
            $0.discoveredUUIDs = discoveredServiceUUIDs
            $0.discoveredAttributes = []
        }
        services.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            updateState {
                $0.connection = .error
                $0.lastError = error.localizedDescription
            }
            return
        }
        let characteristics = service.characteristics ?? []
        if let command = characteristics.first(where: { $0.uuid == commandUUID }) {
            commandCharacteristic = command
        }

        updateState {
            $0.connection = .subscribing
            $0.discoveredUUIDs = Array(Set($0.discoveredUUIDs + ([service.uuid] + characteristics.map(\.uuid)).map(\.uuidString))).sorted()
            mergeAttributeSummaries(
                serviceUUID: service.uuid.uuidString,
                characteristics: characteristics,
                into: &$0.discoveredAttributes
            )
            $0.lastError = service.uuid == serviceUUID && commandCharacteristic == nil
                ? "Command characteristic was not discovered."
                : nil
        }

        for characteristic in characteristics {
            if notifyUUIDs.contains(characteristic.uuid) {
                notifyCharacteristics[characteristic.uuid] = characteristic
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        if service.uuid == serviceUUID && notifyCharacteristics.isEmpty {
            updateState {
                $0.connection = .error
                $0.lastError = "No notify characteristics were discovered."
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            updateState {
                $0.connection = .error
                $0.lastError = error.localizedDescription
            }
            return
        }
        guard characteristic.isNotifying else { return }
        recordControlPlaneEvent(kind: .notifyEnabled, message: "Notify enabled for wearable characteristic.")
        subscribedNotifyUUIDs.insert(characteristic.uuid)
        updateState {
            updateAttribute(
                serviceUUID: characteristic.service?.uuid.uuidString,
                characteristicUUID: characteristic.uuid.uuidString,
                in: &$0.discoveredAttributes
            ) { $0.isNotifying = true }
        }
        guard !hasSentInitSequence,
              subscribedNotifyUUIDs.isSuperset(of: Set(notifyCharacteristics.keys)),
              commandCharacteristic != nil else {
            return
        }
        hasSentInitSequence = true
        updateState {
            $0.connection = .initializing
            $0.lastError = nil
        }
        sendInitSequence()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            updateState {
                $0.connection = .error
                $0.lastError = error.localizedDescription
            }
            return
        }
        guard let data = characteristic.value else { return }
        let standardStatus = processStandardAttribute(data, characteristic: characteristic)
        let isProtocolCharacteristic = notifyUUIDs.contains(characteristic.uuid)
        let frames = isProtocolCharacteristic ? reassembler.append(data) : []
        let decodeStatus = standardStatus ?? (frames.isEmpty ? "fragment or non-frame notification" : "frame candidate")
        let decodedPacketTypeSummary = frames
            .compactMap { WearablePacketDecoder.decode(frame: $0)?.packetType.description ?? packetTypeDescription(from: $0) }
            .joined(separator: ", ")
        let decodedPacketType = decodedPacketTypeSummary.isEmpty ? nil : decodedPacketTypeSummary
        recordCapturedPayload(
            data,
            characteristicUUID: characteristic.uuid.uuidString,
            direction: .notify,
            decodedPacketType: decodedPacketType
        )
        updateState {
            $0.payloadProcessing.droppedFragmentCount = reassembler.droppedFragmentCount
            $0.lastNotificationSample = makeSample(
                data: data,
                characteristic: characteristic,
                frames: frames,
                decodeStatus: decodeStatus
            )
        }
        for frame in frames {
            handle(frame: frame, characteristic: characteristic)
        }
    }

    private func autoConnectIfReady() {
        guard central?.state == .poweredOn else { return }
        recordControlPlaneEvent(kind: .appSyncRequested, message: "Auto-connect requested.")
        if connectFirstRestoredPeripheralByIdentifierIfAvailable() {
            return
        }
        if connectFirstRetrievedPeripheralIfAvailable(allowStandardHeartRateFallback: true) {
            return
        }
        scanIfReady(serviceFiltered: true)
    }

    @discardableResult
    private func connectFirstRestoredPeripheralByIdentifierIfAvailable() -> Bool {
        let identifiers = restoredBLECheckpoints.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { UUID(uuidString: $0.deviceID) }
        guard !identifiers.isEmpty,
              let peripheral = central?.retrievePeripherals(withIdentifiers: identifiers).first else {
            return false
        }
        connectRetrievedPeripheral(
            peripheral,
            advertisedServiceUUIDs: [serviceUUID.uuidString],
            matchesExpectedService: true
        )
        recordControlPlaneEvent(kind: .restoredPeripheralConnected, message: "Connecting restored wearable identifier.")
        return true
    }

    @discardableResult
    private func connectFirstRetrievedPeripheralIfAvailable(allowStandardHeartRateFallback: Bool) -> Bool {
        let protocolConnected = central?.retrieveConnectedPeripherals(withServices: [serviceUUID]) ?? []
        if let peripheral = protocolConnected.first {
            connectRetrievedPeripheral(
                peripheral,
                advertisedServiceUUIDs: [serviceUUID.uuidString],
                matchesExpectedService: true
            )
            return true
        }

        guard allowStandardHeartRateFallback else { return false }
        let protocolConnectedIDs = Set(protocolConnected.map(\.identifier))
        let standardHeartRateConnected = (
            central?.retrieveConnectedPeripherals(withServices: [standardHeartRateServiceUUID]) ?? []
        ).filter { !protocolConnectedIDs.contains($0.identifier) }
        let preferredStandardHeartRatePeripheral = standardHeartRateConnected.first {
            isPreferredDeviceName($0.name)
        }
        let fallbackStandardHeartRatePeripheral = standardHeartRateConnected.count == 1
            ? standardHeartRateConnected.first
            : nil
        if let peripheral = preferredStandardHeartRatePeripheral ?? fallbackStandardHeartRatePeripheral {
            connectRetrievedPeripheral(
                peripheral,
                advertisedServiceUUIDs: [standardHeartRateServiceUUID.uuidString],
                matchesExpectedService: false
            )
            return true
        }

        return false
    }

    private func connectRetrievedPeripheral(
        _ peripheral: CBPeripheral,
        advertisedServiceUUIDs: [String],
        matchesExpectedService: Bool
    ) {
        let candidate = WearableDeviceCandidate(
            id: peripheral.identifier.uuidString,
            name: peripheral.name,
            rssi: currentDeviceState.rssi ?? 0,
            advertisedServiceUUIDs: advertisedServiceUUIDs,
            matchesExpectedService: matchesExpectedService,
            isConnectedToPhone: true,
            isPreferredOwnedDevice: isPreferredDeviceName(peripheral.name),
            lastSeen: Date()
        )
        discoveredPeripherals[candidate.id] = peripheral
        upsert(candidate: candidate)
        connect(to: candidate)
    }

    private func upsert(candidate: WearableDeviceCandidate) {
        updateState {
            if let existingIndex = $0.candidates.firstIndex(where: { $0.id == candidate.id }) {
                $0.candidates[existingIndex] = candidate
            } else {
                $0.candidates.append(candidate)
            }
            $0.candidates.sort {
                if $0.isConnectedToPhone != $1.isConnectedToPhone {
                    return $0.isConnectedToPhone && !$1.isConnectedToPhone
                }
                if $0.matchesExpectedService != $1.matchesExpectedService {
                    return $0.matchesExpectedService && !$1.matchesExpectedService
                }
                if $0.isPreferredOwnedDevice != $1.isPreferredOwnedDevice {
                    return $0.isPreferredOwnedDevice && !$1.isPreferredOwnedDevice
                }
                return $0.rssi > $1.rssi
            }
        }
    }

    private func isPreferredDeviceName(_ name: String?) -> Bool {
        guard let preferredDeviceName, let name else { return false }
        return name.caseInsensitiveCompare(preferredDeviceName) == .orderedSame
    }

    private func scanIfReady(serviceFiltered: Bool) {
        guard central?.state == .poweredOn else { return }
        cancelPermissionProbeScan(stopActiveScan: true)
        if !serviceFiltered && connectFirstRetrievedPeripheralIfAvailable(allowStandardHeartRateFallback: false) {
            return
        }
        commandCharacteristic = nil
        notifyCharacteristics.removeAll()
        subscribedNotifyUUIDs.removeAll()
        hasSentInitSequence = false
        reassembler = FrameReassembler()
        scanningForAutoConnect = serviceFiltered
        updateState {
            $0.connection = .scanning
            $0.deviceID = nil
            $0.name = nil
            $0.rssi = nil
            $0.lastError = nil
            $0.discoveredUUIDs = []
            $0.discoveredAttributes = []
            $0.candidates = []
        }
        discoveredPeripherals.removeAll()
        central?.scanForPeripherals(withServices: serviceFiltered ? [serviceUUID] : nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    private func sendInitSequence() {
        guard let peripheral, let commandCharacteristic else { return }
        for command in WearableProtocol.initSequence() {
            peripheral.writeValue(command, for: commandCharacteristic, type: .withResponse)
            recordCapturedPayload(command, characteristicUUID: commandCharacteristic.uuid.uuidString, direction: .write)
        }
        updateState {
            $0.connection = .historicalSync
            $0.syncDiagnostics.catchUpState = .catchingUp
        }
        recordControlPlaneEvent(kind: .initSent, message: "Wearable init sequence sent.")
        recordControlPlaneEvent(kind: .historicalSyncStarted, message: "Historical sync requested.")
    }

    private func handle(frame: Data, characteristic: CBCharacteristic) {
        do {
            let inner = try WearableProtocol.decodeFrame(frame)
            let decoded = WearablePacketDecoder.decode(frame: frame)
            updateState {
                $0.lastPacketAt = Date()
                $0.lastError = nil
                $0.lastNotificationSample?.packetType = decoded?.packetType.description
                    ?? inner.first.flatMap(WearablePacketType.init(rawValue:))?.description
                    ?? "unknown packet"
                $0.lastNotificationSample?.decodeStatus = "valid frame"
            }
            handleDecoded(inner: inner, frame: frame, characteristic: characteristic, decoded: decoded)
        } catch {
            updateState {
                $0.lastPacketAt = Date()
                $0.lastError = "Malformed wearable frame was rejected."
                $0.lastNotificationSample?.decodeStatus = "malformed frame rejected"
                $0.payloadProcessing.malformedFrameCount += 1
            }
        }
    }

    private func handleDecoded(inner: Data, frame: Data, characteristic: CBCharacteristic, decoded: WearableDecodedPacket?) {
        guard let type = inner.first.flatMap(WearablePacketType.init(rawValue:)) else {
            recordUnknownPacketObservation(packetByte: inner.first, byteCount: inner.count, observedAt: Date())
            return
        }
        updatePayloadSummary(decoded)
        switch type {
        case .metadata:
            if let token = WearablePacketDecoder.batchToken(frame: frame) {
                requestBatchAckAfterDurableStorage(token: token)
            } else {
                persistBLECheckpoint(lastBatchToken: nil, historicalSyncComplete: true)
                sendRealtimeEnableCommands()
            }
        case .event:
            break
        case .realtimeData, .rawRealtimeData, .historicalData:
            updateState { state in
                let receivedAt = Date()
                state.lastPacketAt = receivedAt
                if let heartRate = decoded?.heartRateBPM ?? WearablePacketDecoder.r10HeartRate(frame: frame).map(Int.init) {
                    state.liveHeartRateBPM = heartRate
                    state.liveHeartRateSource = decoded?.recordLabel ?? "wearable protocol"
                    state.liveHeartRateAt = receivedAt
                    state.connection = .realtime
                }
                if let temperature = decoded?.dataRecord?.r10?.skinTemperatureC {
                    state.skinTemperatureC = temperature
                    state.skinTemperatureAt = receivedAt
                }
            }
        case .command, .commandResponse, .firmwareLog:
            break
        }
        emitSafeSamples(decoded, characteristic: characteristic)
    }

    private func processStandardAttribute(_ data: Data, characteristic: CBCharacteristic) -> String? {
        let characteristicUUID = characteristic.uuid.uuidString
        let serviceUUID = characteristic.service?.uuid.uuidString
        var status: String?
        updateState {
            updateAttribute(
                serviceUUID: serviceUUID,
                characteristicUUID: characteristicUUID,
                in: &$0.discoveredAttributes
            ) { attribute in
                attribute.lastValueSummary = "read \(data.count) bytes"
            }
        }

        if characteristic.uuid == standardHeartRateMeasurementUUID,
           let measurement = WearableStandardParser.parseHeartRateMeasurement(data) {
            let receivedAt = Date()
            let receivedAtToken = Self.sampleTimestampToken(receivedAt)
            updateState {
                $0.liveHeartRateBPM = measurement.bpm
                $0.liveHeartRateSource = "Bluetooth Heart Rate Measurement"
                $0.liveHeartRateAt = receivedAt
                $0.connection = .realtime
                $0.lastError = nil
                $0.lastPacketAt = receivedAt
                $0.payloadProcessing.processedPayloadCount += 1
                $0.payloadProcessing.lastPacketType = "standardHeartRateMeasurement"
                $0.payloadProcessing.lastRecordType = "GATT 2A37"
                $0.payloadProcessing.lastProcessedAt = receivedAt
                if let contactDetected = measurement.contactDetected {
                    $0.isOnWrist = contactDetected
                }
            }
            var samples = [
                HealthSample(
                    id: "wearable_standard_hr-\(characteristic.uuid.uuidString)-\(receivedAtToken)",
                    type: .heartRate,
                    value: Double(measurement.bpm),
                    unit: "bpm",
                    startDate: receivedAt,
                    endDate: nil,
                    source: .wearableBLE,
                    sourceRecordID: "standard_hr:\(characteristic.uuid.uuidString):\(receivedAtToken)",
                    confidence: measurement.contactDetected == false ? .low : .medium,
                    metadata: [
                        "source_label": "Bluetooth Heart Rate Measurement",
                        "characteristic_uuid": characteristic.uuid.uuidString,
                        "contact_detected": measurement.contactDetected.map { String($0) } ?? "unknown"
                    ]
                )
            ]
            if measurement.rrIntervalsMS.count >= WearableHRVCalculator.minimumProductionRRIntervalCount,
               measurement.contactDetected != false {
                let sdnn = WearableHRVCalculator.sdnnMS(from: measurement.rrIntervalsMS)
                let rmssd = WearableHRVCalculator.rmssdMS(from: measurement.rrIntervalsMS)
                if let rmssd {
                    samples.append(HealthSample(
                        id: "wearable_standard_hrv_rmssd-\(characteristic.uuid.uuidString)-\(receivedAtToken)",
                        type: .heartRateVariabilityRMSSD,
                        value: rmssd,
                        unit: "ms",
                        startDate: receivedAt,
                        endDate: nil,
                        source: .wearableBLE,
                        sourceRecordID: "standard_hrv_rmssd:\(characteristic.uuid.uuidString):\(receivedAtToken)",
                        confidence: .medium,
                        metadata: [
                            "source_label": "Bluetooth Heart Rate RR intervals",
                            "characteristic_uuid": characteristic.uuid.uuidString,
                            "rr_interval_count": "\(measurement.rrIntervalsMS.count)",
                            "metric_policy": "rmssd_from_direct_rr_intervals",
                            "sdnn_ms": sdnn.map { String(format: "%.2f", $0) } ?? ""
                        ]
                    ))
                }
                if let sdnn {
                    samples.append(HealthSample(
                        id: "wearable_standard_hrv_sdnn-\(characteristic.uuid.uuidString)-\(receivedAtToken)",
                        type: .heartRateVariabilitySDNN,
                        value: sdnn,
                        unit: "ms",
                        startDate: receivedAt,
                        endDate: nil,
                        source: .wearableBLE,
                        sourceRecordID: "standard_hrv_sdnn:\(characteristic.uuid.uuidString):\(receivedAtToken)",
                        confidence: .medium,
                        metadata: [
                            "source_label": "Bluetooth Heart Rate RR intervals",
                            "characteristic_uuid": characteristic.uuid.uuidString,
                            "rr_interval_count": "\(measurement.rrIntervalsMS.count)",
                            "metric_policy": "sdnn_from_direct_rr_intervals",
                            "rmssd_ms": rmssd.map { String(format: "%.2f", $0) } ?? ""
                        ]
                    ))
                }
                if let respiratoryRate = WearableRespiratoryRateEstimator.estimateFromRRIntervals(measurement.rrIntervalsMS) {
                    samples.append(HealthSample(
                        id: "wearable_standard_rr_resp-\(characteristic.uuid.uuidString)-\(receivedAtToken)",
                        type: .respiratoryRate,
                        value: respiratoryRate,
                        unit: "br/min",
                        startDate: receivedAt,
                        endDate: nil,
                        source: .whoordanEstimate,
                        sourceRecordID: "standard_rr_resp:\(characteristic.uuid.uuidString):\(receivedAtToken)",
                        confidence: .low,
                        metadata: [
                            "source_label": "BLE-derived respiratory rate from RR intervals",
                            "characteristic_uuid": characteristic.uuid.uuidString,
                            "rr_interval_count": "\(measurement.rrIntervalsMS.count)",
                            "device_only_derivation": "true",
                            "metric_policy": "rr_interval_respiratory_rate_estimate",
                            "formula": "dominant low-frequency RR-interval modulation, 6-30 br/min"
                        ]
                    ))
                }
            }
            updateState {
                $0.payloadProcessing.safeHealthSampleCount += samples.count
                $0.liveAnalytics.directMetricCount += samples.count
                $0.liveAnalytics.lastDirectMetric = samples.contains { $0.type == .heartRateVariabilitySDNN }
                    ? "Heart rate + HRV"
                    : "Heart rate"
                $0.liveAnalytics.lastUpdatedAt = receivedAt
            }
            persistHealthSamples(samples)
            status = "standard heart rate parsed"
        } else if characteristic.uuid == standardBatteryLevelUUID,
                  let battery = WearableStandardParser.parseBatteryLevel(data) {
            updateState {
                $0.applyDisplayedBatteryPercent(battery, source: .standardGattBatteryLevel)
                $0.lastPacketAt = Date()
                $0.payloadProcessing.processedPayloadCount += 1
                $0.payloadProcessing.lastPacketType = "standardBatteryLevel"
                $0.payloadProcessing.lastRecordType = "GATT 2A19"
                $0.payloadProcessing.lastProcessedAt = Date()
            }
            status = "standard battery parsed"
        }

        return status
    }

    private func updatePayloadSummary(_ decoded: WearableDecodedPacket?) {
        let emittedEvent = decoded?.event
        updateState { state in
            guard let decoded else {
                state.payloadProcessing.unsupportedPayloadCount += 1
                state.payloadProcessing.unknownPacketCount += 1
                return
            }
            state.payloadProcessing.processedPayloadCount += 1
            state.payloadProcessing.lastPacketType = decoded.packetType.description
            state.payloadProcessing.lastRecordType = decoded.recordLabel
            state.payloadProcessing.lastEventType = decoded.eventType
            state.payloadProcessing.lastProcessedAt = Date()
            state.payloadProcessing.imuSampleCount += decoded.imuSampleCount
            state.payloadProcessing.ppgSampleCount += decoded.ppgSampleCount
            state.payloadProcessing.ppgChannelCount = max(state.payloadProcessing.ppgChannelCount, decoded.ppgChannelCount)
            state.unavailableSignalReasons = decoded.unavailableSignals.map(\.rawValue)
            let receivedAt = Date()
            if let heartRate = decoded.heartRateBPM {
                state.liveHeartRateBPM = heartRate
                state.liveHeartRateSource = decoded.recordLabel
                state.liveHeartRateAt = receivedAt
            }
            let deviceID = state.deviceID ?? "unknown-device"
            let characteristicUUID = state.lastNotificationSample?.characteristicUUID ?? "unknown-characteristic"
            let safeSampleCount = decoded.safeHealthSamples(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                receivedAt: receivedAt
            ).count
            state.payloadProcessing.safeHealthSampleCount += safeSampleCount
            if safeSampleCount > 0 {
                state.liveAnalytics.directMetricCount += safeSampleCount
                state.liveAnalytics.lastDirectMetric = directMetricLabel(for: decoded)
                state.liveAnalytics.lastUpdatedAt = receivedAt
            }
            if let observation = frameObservation(for: decoded, observedAt: receivedAt) {
                if observation.observationKind == "unknown" {
                    state.payloadProcessing.unknownPacketCount += 1
                    state.liveAnalytics.unknownFrameCount += 1
                }
                if observation.observationKind == "candidate" {
                    state.liveAnalytics.candidateMetricCount += 1
                    state.liveAnalytics.lastCandidateMetric = observation.candidateValue ?? observation.label
                }
                state.liveAnalytics.lastUpdatedAt = receivedAt
                upsert(observation: observation, into: &state.unknownFrameObservations)
                WearableFrameTrendStat.upsert(observation: observation, into: &state.unknownFrameTrends)
            }
            if decoded.imuSampleBatch(
                deviceID: deviceID,
                characteristicUUID: characteristicUUID,
                receivedAt: receivedAt
            ) != nil {
                state.payloadProcessing.imuBatchCount += 1
            }
            if let response = decoded.commandResponse {
                state.lastCommandResponse = response.kind
                if let name = response.advertisingName {
                    state.advertisingName = name
                    state.name = state.name ?? name
                }
                if let fingerprint = response.deviceFingerprint {
                    state.deviceFingerprint = fingerprint
                }
                if let hello = response.hello {
                    if let batteryPercent = hello.batteryPercent {
                        state.applyDisplayedBatteryPercent(
                            Int(batteryPercent.rounded()),
                            source: .proprietaryHelloCandidate
                        )
                    }
                    if let isCharging = hello.isCharging {
                        state.isCharging = isCharging
                    }
                    if let isOnWrist = hello.isOnWrist {
                        state.isOnWrist = isOnWrist
                    }
                }
                if let range = response.dataRange {
                    state.dataRangeSummary = "payload \(range.payloadByteCount) bytes, \(range.dateCandidates.count) date candidates"
                }
                if let alarm = response.alarm {
                    state.alarmSummary = alarm.isConfigured.map { $0 ? "configured" : "not configured" } ?? "payload \(alarm.payloadByteCount) bytes"
                }
                if let historical = response.historicalSync {
                    state.historicalSyncSummary = "status \(historical.statusByte.map(String.init) ?? "unknown"), payload \(historical.payloadByteCount) bytes"
                }
            }
            if let metadata = decoded.metadata {
                state.historicalSyncSummary = metadata.isBatchMarker
                    ? "metadata batch marker"
                    : "metadata end-of-sync candidate"
                if metadata.isEndOfSync {
                    state.payloadProcessing.historicalSyncComplete = true
                }
            }
            if let event = decoded.event {
                state.lastEventDescription = event.kind.rawValue
                apply(event: event, to: &state)
            }
            if let firmwareLog = decoded.firmwareLog {
                state.firmwareLogSummary = firmwareLog.message
            }
        }
        if let emittedEvent {
            onEvent?(emittedEvent)
        }
    }

    private func directMetricLabel(for decoded: WearableDecodedPacket) -> String {
        if decoded.heartRateBPM != nil {
            return "Heart rate"
        }
        if decoded.dataRecord?.r10?.skinTemperatureC != nil {
            return "Raw wrist temperature"
        }
        if decoded.event?.kind == .temperature {
            return "Temperature event"
        }
        return "Source-labeled wearable sample"
    }

    private func frameObservation(for decoded: WearableDecodedPacket, observedAt: Date) -> WearableFrameObservation? {
        if decoded.packetType == .event, decoded.event?.kind == .unknown {
            return WearableFrameObservation(
                id: observationID(prefix: "event", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: nil,
                label: "Unknown event \(decoded.eventType.map(String.init) ?? "--")",
                observationKind: "unknown",
                byteCount: decoded.event?.payloadByteCount ?? 0,
                sampleCount: nil,
                candidateValue: nil,
                caveat: "Event code is observed but not mapped to a safe app metric.",
                observedAt: observedAt
            )
        }
        guard let record = decoded.dataRecord else { return nil }
        switch record.recordType {
        case 7:
            return WearableFrameObservation(
                id: observationID(prefix: "r7", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: record.recordType,
                label: record.label,
                observationKind: "unknown",
                byteCount: record.payloadByteCount,
                sampleCount: nil,
                candidateValue: nil,
                caveat: "R7 frame class is confirmed, but field semantics are still unknown.",
                observedAt: observedAt
            )
        case 11:
            return WearableFrameObservation(
                id: observationID(prefix: "r11", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: record.recordType,
                label: record.label,
                observationKind: "raw_debug",
                byteCount: record.payloadByteCount,
                sampleCount: nil,
                candidateValue: nil,
                caveat: record.r11?.note ?? "R11 is retained as diagnostic/candidate payload only.",
                observedAt: observedAt
            )
        case 20:
            return WearableFrameObservation(
                id: observationID(prefix: "r20", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: record.recordType,
                label: record.label,
                observationKind: "unknown",
                byteCount: record.payloadByteCount,
                sampleCount: nil,
                candidateValue: nil,
                caveat: "R20 optical/raw frame is not decoded into a production metric.",
                observedAt: observedAt
            )
        case 21:
            return WearableFrameObservation(
                id: observationID(prefix: "r21", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: record.recordType,
                label: record.label,
                observationKind: "raw_debug",
                byteCount: record.payloadByteCount,
                sampleCount: record.r21?.sampleCount,
                candidateValue: nil,
                caveat: record.r21?.note ?? "Optical samples are raw diagnostics only.",
                observedAt: observedAt
            )
        case 24:
            return WearableFrameObservation(
                id: observationID(prefix: "r24", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: record.recordType,
                label: record.label,
                observationKind: "candidate",
                byteCount: record.payloadByteCount,
                sampleCount: nil,
                candidateValue: record.r24?.spo2CandidatePercent.map { String(format: "%.2f%% scalar candidate", $0) },
                caveat: record.r24?.note ?? "R24 scalar is unconfirmed and not emitted as a health metric.",
                observedAt: observedAt
            )
        default:
            guard record.recordType != 10 else { return nil }
            return WearableFrameObservation(
                id: observationID(prefix: "record-\(record.recordType)", decoded: decoded),
                packetType: decoded.packetType.description,
                recordType: record.recordType,
                label: record.label,
                observationKind: "unknown",
                byteCount: record.payloadByteCount,
                sampleCount: nil,
                candidateValue: nil,
                caveat: "Record type is valid but has no app-ready metric mapping.",
                observedAt: observedAt
            )
        }
    }

    private func observationID(prefix: String, decoded: WearableDecodedPacket) -> String {
        [
            prefix,
            decoded.packetType.description,
            decoded.recordType.map(String.init) ?? "none",
            decoded.sequence.map(String.init) ?? "none",
            decoded.dataRecord?.rawTimestamp.map { String($0) } ?? "none"
        ].joined(separator: ":")
    }

    private func upsert(observation: WearableFrameObservation, into observations: inout [WearableFrameObservation]) {
        if let index = observations.firstIndex(where: { $0.id == observation.id }) {
            observations[index] = observation
        } else {
            observations.insert(observation, at: 0)
        }
        if observations.count > 40 {
            observations.removeLast(observations.count - 40)
        }
    }

    private func recordUnknownPacketObservation(packetByte: UInt8?, byteCount: Int, observedAt: Date) {
        let observation = WearableFrameObservation.unknownPacket(
            packetByte: packetByte,
            byteCount: byteCount,
            observedAt: observedAt
        )
        updateState { state in
            state.payloadProcessing.unsupportedPayloadCount += 1
            state.payloadProcessing.unknownPacketCount += 1
            state.payloadProcessing.processedPayloadCount += 1
            state.payloadProcessing.lastPacketType = observation.packetType
            state.payloadProcessing.lastRecordType = observation.label
            state.payloadProcessing.lastProcessedAt = observedAt
            state.liveAnalytics.unknownFrameCount += 1
            state.liveAnalytics.lastUpdatedAt = observedAt
            upsert(observation: observation, into: &state.unknownFrameObservations)
            WearableFrameTrendStat.upsert(observation: observation, into: &state.unknownFrameTrends)
        }
    }

    private func apply(event: WearableEventPacket, to state: inout WearableDeviceState) {
        switch event.kind {
        case .batteryLevel:
            if let value = event.numericValue {
                state.applyDisplayedBatteryPercent(
                    Int(value.rounded()),
                    source: .proprietaryEventCandidate
                )
            }
        case .chargingStarted:
            state.isCharging = true
        case .chargingStopped:
            state.isCharging = false
        case .wristOn:
            state.isOnWrist = true
        case .wristOff:
            state.isOnWrist = false
        case .temperature:
            state.skinTemperatureC = event.numericValue
            state.skinTemperatureAt = Date()
        case .realtimeHeartRateStarted:
            state.payloadProcessing.realtimeStreamActive = true
        case .realtimeHeartRateStopped:
            state.payloadProcessing.realtimeStreamActive = false
        case .alarmSet:
            state.alarmSummary = "alarm set event"
        case .alarmFired:
            state.alarmSummary = "alarm fired event"
        case .alarmDisabled:
            state.alarmSummary = "alarm disabled event"
        case .hapticsFired:
            state.payloadProcessing.lastHapticStatus = "fired"
        case .hapticsTerminated:
            state.payloadProcessing.lastHapticStatus = "terminated"
        case .doubleTap, .unknown:
            break
        }
    }

    private func sendRealtimeEnableCommands() {
        guard let peripheral, let commandCharacteristic else { return }
        WearableProtocol.realtimeEnableCommands(startSequence: 0xA8).forEach { command in
            peripheral.writeValue(command, for: commandCharacteristic, type: .withResponse)
            recordCapturedPayload(command, characteristicUUID: commandCharacteristic.uuid.uuidString, direction: .write)
        }
        updateState {
            $0.connection = .realtime
            $0.payloadProcessing.realtimeStreamActive = true
            $0.syncDiagnostics.catchUpState = .realtimeActive
        }
        recordControlPlaneEvent(kind: .realtimeEnabled, message: "Realtime stream enabled after catch-up.")
    }

    private func sendRealtimeDisableCommands() {
        guard let peripheral, let commandCharacteristic else { return }
        WearableProtocol.realtimeDisableCommands(startSequence: realtimeDisableSequence).forEach { command in
            peripheral.writeValue(command, for: commandCharacteristic, type: .withResponse)
            recordCapturedPayload(command, characteristicUUID: commandCharacteristic.uuid.uuidString, direction: .write)
        }
        realtimeDisableSequence = realtimeDisableSequence &+ 4
        updateState { $0.payloadProcessing.realtimeStreamActive = false }
    }

    private func requestBatchAckAfterDurableStorage(token: Data) {
        let tokenFingerprint = WearablePrivacy.fingerprint(token.base64EncodedString())
        updateState {
            $0.historicalSyncSummary = "metadata batch marker received"
            $0.payloadProcessing.historicalSyncComplete = false
            $0.syncDiagnostics.catchUpState = .catchingUp
            $0.syncDiagnostics.lastCheckpointTokenFingerprint = tokenFingerprint
        }
        recordControlPlaneEvent(kind: .batchMarkerReceived, message: "Historical batch marker received.")
        if batchAckGate.shouldDeferBatchAck {
            batchAckGate.markBatchAckDeferred()
            deferredBatchAckTokens.append(token)
            updateBatchGateDiagnostics()
            recordControlPlaneEvent(kind: .batchAckDeferred, message: "Batch ACK deferred until local sample persistence completes.")
            return
        }
        sendBatchAck(token: token)
        persistBLECheckpoint(lastBatchToken: token.base64EncodedString(), historicalSyncComplete: false)
    }

    private func flushDeferredBatchAcksIfReady() {
        guard batchAckGate.canFlushDeferredBatchAck else {
            updateBatchGateDiagnostics()
            return
        }
        while batchAckGate.canFlushDeferredBatchAck, !deferredBatchAckTokens.isEmpty {
            let token = deferredBatchAckTokens.removeFirst()
            batchAckGate.markDeferredBatchAckFlushed()
            sendBatchAck(token: token)
            persistBLECheckpoint(lastBatchToken: token.base64EncodedString(), historicalSyncComplete: false)
        }
        updateBatchGateDiagnostics()
    }

    private func updateBatchGateDiagnostics() {
        updateState {
            $0.syncDiagnostics.pendingDurableSampleStores = batchAckGate.pendingDurableSampleStores
            $0.syncDiagnostics.deferredBatchAckCount = batchAckGate.deferredBatchAckCount
            if batchAckGate.pendingDurableSampleStores > 0 {
                $0.syncDiagnostics.catchUpState = .waitingForDurableStorage
            } else if batchAckGate.durabilityFailed {
                $0.syncDiagnostics.catchUpState = .stalled
            } else if $0.connection == .historicalSync {
                $0.syncDiagnostics.catchUpState = .catchingUp
            }
        }
    }

    private func sendBatchAck(token: Data) {
        guard token.count == 8, let peripheral, let commandCharacteristic else { return }
        let ack = WearableProtocol.buildBatchAck(counter: batchAckCounter, batchToken: token)
        batchAckCounter = batchAckCounter &+ 1
        peripheral.writeValue(ack, for: commandCharacteristic, type: .withResponse)
        recordCapturedPayload(ack, characteristicUUID: commandCharacteristic.uuid.uuidString, direction: .write)
        updateState {
            $0.historicalSyncSummary = "metadata batch ACK sent"
            $0.payloadProcessing.lastBatchAckAt = Date()
            $0.payloadProcessing.lastBatchAckTokenFingerprint = WearablePrivacy.fingerprint(token.base64EncodedString())
            $0.payloadProcessing.historicalSyncComplete = false
            $0.syncDiagnostics.lastAckedBatchTokenFingerprint = WearablePrivacy.fingerprint(token.base64EncodedString())
            $0.syncDiagnostics.deferredBatchAckCount = batchAckGate.deferredBatchAckCount
        }
        recordControlPlaneEvent(kind: .batchAckSent, message: "Historical batch ACK sent after durable storage gate.")
    }

    private func persistBLECheckpoint(lastBatchToken: String?, historicalSyncComplete: Bool) {
        let deviceID = currentDeviceState.deviceID ?? peripheral?.identifier.uuidString ?? "unknown-device"
        let checkpoint = BLECheckpoint(
            deviceID: deviceID,
            lastBatchToken: lastBatchToken,
            historicalSyncComplete: historicalSyncComplete,
            updatedAt: Date()
        )
        restoredBLECheckpoints[deviceID] = checkpoint
        updateState {
            $0.syncDiagnostics.lastCheckpointTokenFingerprint = lastBatchToken.map(WearablePrivacy.fingerprint)
            $0.syncDiagnostics.catchUpState = historicalSyncComplete ? .caughtUp : $0.syncDiagnostics.catchUpState
        }
        onBLECheckpoint?(checkpoint)
    }

    private func emitSafeSamples(_ decoded: WearableDecodedPacket?, characteristic: CBCharacteristic) {
        guard let decoded else { return }
        let receivedAt = Date()
        let deviceID = currentDeviceState.deviceID ?? peripheral?.identifier.uuidString ?? "unknown-device"
        let characteristicUUID = characteristic.uuid.uuidString
        let samples = decoded.safeHealthSamples(
            deviceID: deviceID,
            characteristicUUID: characteristicUUID,
            receivedAt: receivedAt
        )
        persistHealthSamples(samples)
    }

    private func persistHealthSamples(_ samples: [HealthSample]) {
        guard !samples.isEmpty else { return }
        batchAckGate.beginDurableSampleStore()
        updateBatchGateDiagnostics()
        let persistSamples = onHealthSamples
        Task { [weak self, persistSamples] in
            let succeeded: Bool
            if let persistSamples {
                succeeded = await persistSamples(samples)
            } else {
                succeeded = true
            }
            DispatchQueue.main.async {
                self?.finishDurableSampleStore(succeeded: succeeded)
            }
        }
    }

    private func finishDurableSampleStore(succeeded: Bool) {
        batchAckGate.finishDurableSampleStore(succeeded: succeeded)
        updateBatchGateDiagnostics()
        if succeeded {
            recordControlPlaneEvent(kind: .durableSampleStoreCompleted, message: "Wearable samples stored locally.")
            flushDeferredBatchAcksIfReady()
        } else {
            recordControlPlaneEvent(kind: .durableSampleStoreFailed, message: "Wearable sample persistence failed; batch ACK withheld.")
            updateState {
                $0.lastError = "Local wearable sample persistence failed; historical ACK withheld so data can be retried."
                $0.historicalSyncSummary = "batch ACK withheld after local persistence failure"
            }
        }
    }

    private func makeSample(
        data: Data,
        characteristic: CBCharacteristic,
        frames: [Data],
        decodeStatus: String
    ) -> WearableNotificationSample {
        let bytes = [UInt8](data)
        return WearableNotificationSample(
            characteristicUUID: characteristic.uuid.uuidString,
            byteCount: bytes.count,
            frameCount: frames.count,
            packetType: nil,
            decodeStatus: decodeStatus,
            sampledAt: Date()
        )
    }

    private func mergeAttributeSummaries(
        serviceUUID: String,
        characteristics: [CBCharacteristic],
        into summaries: inout [WearableAttributeSummary]
    ) {
        characteristics.forEach { characteristic in
            let summary = WearableAttributeSummary(
                id: "\(serviceUUID):\(characteristic.uuid.uuidString)",
                serviceUUID: serviceUUID,
                characteristicUUID: characteristic.uuid.uuidString,
                properties: propertyLabels(characteristic.properties),
                canRead: characteristic.properties.contains(.read),
                canNotify: characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate),
                isNotifying: characteristic.isNotifying,
                lastValueSummary: nil
            )
            if let index = summaries.firstIndex(where: { $0.id == summary.id }) {
                summaries[index] = summary
            } else {
                summaries.append(summary)
            }
        }
        summaries.sort {
            if $0.serviceUUID != $1.serviceUUID {
                return $0.serviceUUID < $1.serviceUUID
            }
            return $0.characteristicUUID < $1.characteristicUUID
        }
    }

    private func updateAttribute(
        serviceUUID: String?,
        characteristicUUID: String,
        in summaries: inout [WearableAttributeSummary],
        update: (inout WearableAttributeSummary) -> Void
    ) {
        guard let serviceUUID,
              let index = summaries.firstIndex(where: {
                  $0.serviceUUID == serviceUUID && $0.characteristicUUID == characteristicUUID
              }) else {
            return
        }
        update(&summaries[index])
    }

    private func propertyLabels(_ properties: CBCharacteristicProperties) -> [String] {
        var labels: [String] = []
        if properties.contains(.read) { labels.append("read") }
        if properties.contains(.write) { labels.append("write") }
        if properties.contains(.writeWithoutResponse) { labels.append("writeWithoutResponse") }
        if properties.contains(.notify) { labels.append("notify") }
        if properties.contains(.indicate) { labels.append("indicate") }
        return labels
    }
}
#endif

extension WearablePacketType {
    var description: String {
        switch self {
        case .command: return "command"
        case .commandResponse: return "commandResponse"
        case .realtimeData: return "realtimeData"
        case .rawRealtimeData: return "rawRealtimeData"
        case .historicalData: return "historicalData"
        case .event: return "event"
        case .metadata: return "metadata"
        case .firmwareLog: return "firmwareLog"
        }
    }
}
