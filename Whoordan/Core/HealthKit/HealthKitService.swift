import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthKitPermissionStatus: String, Codable, Equatable {
    case approvalRequired
    case unavailable
    case notDetermined
    case requested
    case partial
    case authorized
    case denied
    case failed
}

struct HealthKitAuthorizationResult: Codable, Equatable {
    let status: HealthKitPermissionStatus
    let requestedTypes: [HealthSampleType]
    let message: String
}

struct HealthKitImportResult: Codable, Equatable {
    let samples: [HealthSample]
    let importedAt: Date
    let message: String

    static let unavailable = HealthKitImportResult(samples: [], importedAt: Date(), message: "Apple Health is export-only in Whoordan.")
}

struct HealthKitIncrementalImportResult: Codable, Equatable {
    let samples: [HealthSample]
    let checkpoints: [HealthKitCheckpoint]
    let deletedObjectIDs: [String]
    let importedAt: Date
    let message: String

    static let unavailable = HealthKitIncrementalImportResult(
        samples: [],
        checkpoints: [],
        deletedObjectIDs: [],
        importedAt: Date(),
        message: "Apple Health is export-only in Whoordan."
    )
}

enum AppleHealthWriteResultStatus: String, Codable, Equatable {
    case written
    case nothingToWrite
    case notAuthorized
    case failed
    case unsupported
}

struct AppleHealthWriteResult: Codable, Equatable {
    let status: AppleHealthWriteResultStatus
    let writtenCount: Int
    let unsupportedCount: Int
    let message: String
    var writtenDedupeIDs: [String] = []
    var notAuthorizedDedupeIDs: [String] = []
    var notAuthorizedTypes: [HealthSampleType] = []
}

enum AppleHealthWritePermission: Equatable {
    case authorized
    case notAuthorized
}

struct AppleHealthWriteAuthorizationPlan: Equatable {
    let writableSamples: [HealthSample]
    let notAuthorizedSamples: [HealthSample]
    let notAuthorizedTypes: [HealthSampleType]
}

enum AppleHealthWriteAuthorizationPlanner {
    static func plan(
        samples: [HealthSample],
        permissionForType: (HealthSampleType) -> AppleHealthWritePermission
    ) -> AppleHealthWriteAuthorizationPlan {
        var writableSamples: [HealthSample] = []
        var notAuthorizedSamples: [HealthSample] = []

        for sample in samples {
            switch permissionForType(sample.type) {
            case .authorized:
                writableSamples.append(sample)
            case .notAuthorized:
                notAuthorizedSamples.append(sample)
            }
        }

        let notAuthorizedTypes = Array(Set(notAuthorizedSamples.map(\.type)))
            .sorted { $0.rawValue < $1.rawValue }
        return AppleHealthWriteAuthorizationPlan(
            writableSamples: writableSamples,
            notAuthorizedSamples: notAuthorizedSamples,
            notAuthorizedTypes: notAuthorizedTypes
        )
    }
}

protocol HealthKitServicing {
    func isAvailable() -> Bool
    func requestAuthorization() async -> HealthKitAuthorizationResult
    func requestWriteAuthorization() async -> HealthKitAuthorizationResult
    func supportedReadTypes() -> [HealthSampleType]
    func supportedWriteTypes() -> [HealthSampleType]
    func importSamples(since start: Date, until end: Date) async -> HealthKitImportResult
    func importIncremental(
        checkpoints: [HealthKitCheckpoint],
        fallbackStart: Date,
        fallbackEnd: Date
    ) async -> HealthKitIncrementalImportResult
    func writeSamples(_ samples: [HealthSample]) async -> AppleHealthWriteResult
    func registerBackgroundDelivery(_ handler: @escaping @Sendable () async -> Void) async -> HealthKitAuthorizationResult
}

final class HealthKitService: HealthKitServicing {
    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    #endif

    func isAvailable() -> Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    func supportedReadTypes() -> [HealthSampleType] {
        []
    }

    func requestAuthorization() async -> HealthKitAuthorizationResult {
        await requestWriteAuthorization()
    }

    func requestWriteAuthorization() async -> HealthKitAuthorizationResult {
        guard isAvailable() else {
            return HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "HealthKit is unavailable on this device.")
        }

        #if canImport(HealthKit)
        let writeTypes = Self.hkWriteTypes()
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
            return HealthKitAuthorizationResult(
                status: .requested,
                requestedTypes: supportedWriteTypes(),
                message: "Apple Health write permission request completed. Whoordan writes only supported user-created records."
            )
        } catch {
            return HealthKitAuthorizationResult(status: .failed, requestedTypes: supportedWriteTypes(), message: error.localizedDescription)
        }
        #else
        return HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "HealthKit is unavailable in this build.")
        #endif
    }

    func importSamples(since start: Date, until end: Date) async -> HealthKitImportResult {
        return .unavailable
    }

    func importIncremental(
        checkpoints: [HealthKitCheckpoint],
        fallbackStart: Date,
        fallbackEnd: Date
    ) async -> HealthKitIncrementalImportResult {
        return .unavailable
    }

    func supportedWriteTypes() -> [HealthSampleType] {
        [
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate,
            .sleepAnalysis,
            .steps,
            .activeEnergy,
            .distanceWalkingRunning,
            .oxygenSaturation,
            .bodyTemperature,
            .workout,
            .vo2Max
        ]
    }

    func writeSamples(_ samples: [HealthSample]) async -> AppleHealthWriteResult {
        guard isAvailable() else {
            return AppleHealthWriteResult(status: .failed, writtenCount: 0, unsupportedCount: samples.count, message: "HealthKit is unavailable on this device.")
        }

        #if canImport(HealthKit)
        let supportedSamples = samples.filter(AppleHealthWritePolicy.isSupported)
        let permissionPlan = AppleHealthWriteAuthorizationPlanner.plan(samples: supportedSamples) { type in
            guard let sampleType = Self.hkSampleType(for: type) else { return .notAuthorized }
            return store.authorizationStatus(for: sampleType) == .sharingAuthorized ? .authorized : .notAuthorized
        }
        let hkSamples = permissionPlan.writableSamples.compactMap(Self.healthKitWritableSample)
        let unsupported = samples.count - supportedSamples.count + permissionPlan.writableSamples.count - hkSamples.count
        let notAuthorizedDedupeIDs = permissionPlan.notAuthorizedSamples.map(\.dedupeID)
        guard !hkSamples.isEmpty else {
            if !permissionPlan.notAuthorizedSamples.isEmpty {
                return AppleHealthWriteResult(
                    status: .notAuthorized,
                    writtenCount: 0,
                    unsupportedCount: unsupported + permissionPlan.notAuthorizedSamples.count,
                    message: Self.notAuthorizedMessage(types: permissionPlan.notAuthorizedTypes, writtenCount: 0),
                    notAuthorizedDedupeIDs: notAuthorizedDedupeIDs,
                    notAuthorizedTypes: permissionPlan.notAuthorizedTypes
                )
            }
            return AppleHealthWriteResult(
                status: samples.isEmpty ? .nothingToWrite : .unsupported,
                writtenCount: 0,
                unsupportedCount: unsupported,
                message: "No supported Apple Health write samples were queued."
            )
        }
        do {
            try await store.save(hkSamples)
            let message: String
            if permissionPlan.notAuthorizedSamples.isEmpty {
                message = "Wrote supported user-created samples to Apple Health."
            } else {
                message = Self.notAuthorizedMessage(types: permissionPlan.notAuthorizedTypes, writtenCount: hkSamples.count)
            }
            return AppleHealthWriteResult(
                status: .written,
                writtenCount: hkSamples.count,
                unsupportedCount: unsupported + permissionPlan.notAuthorizedSamples.count,
                message: message,
                writtenDedupeIDs: permissionPlan.writableSamples.map(\.dedupeID),
                notAuthorizedDedupeIDs: notAuthorizedDedupeIDs,
                notAuthorizedTypes: permissionPlan.notAuthorizedTypes
            )
        } catch {
            return AppleHealthWriteResult(
                status: .failed,
                writtenCount: 0,
                unsupportedCount: unsupported + permissionPlan.notAuthorizedSamples.count,
                message: "Apple Health write failed: \(Self.sanitizedErrorMessage(error.localizedDescription))",
                notAuthorizedDedupeIDs: notAuthorizedDedupeIDs,
                notAuthorizedTypes: permissionPlan.notAuthorizedTypes
            )
        }
        #else
        return AppleHealthWriteResult(status: .failed, writtenCount: 0, unsupportedCount: samples.count, message: "HealthKit is unavailable in this build.")
        #endif
    }

    func registerBackgroundDelivery(_ handler: @escaping @Sendable () async -> Void) async -> HealthKitAuthorizationResult {
        guard isAvailable() else {
            return HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "HealthKit is unavailable on this device.")
        }

        return HealthKitAuthorizationResult(
            status: .requested,
            requestedTypes: supportedWriteTypes(),
            message: "Apple Health uses export-only writes in Whoordan."
        )
    }

    #if canImport(HealthKit)
    private static func hkWriteTypes() -> Set<HKSampleType> {
        var types = Set<HKSampleType>()
        [
            HKQuantityTypeIdentifier.heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate,
            .stepCount,
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .oxygenSaturation,
            .bodyTemperature,
            .vo2Max
        ].compactMap { HKObjectType.quantityType(forIdentifier: $0) }.forEach { types.insert($0) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private static func healthKitWritableSample(from sample: HealthSample) -> HKSample? {
        guard AppleHealthWritePolicy.isSupported(sample) else {
            return nil
        }
        switch sample.type {
        case .workout:
            return workoutSample(from: sample)
        case .sleepAnalysis:
            return sleepSample(from: sample)
        default:
            return quantitySample(from: sample)
        }
    }

    private static func hkSampleType(for type: HealthSampleType) -> HKSampleType? {
        switch type {
        case .workout:
            return HKObjectType.workoutType()
        case .sleepAnalysis:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        default:
            guard let identifier = writableQuantityIdentifier(for: type) else { return nil }
            return HKObjectType.quantityType(forIdentifier: identifier)
        }
    }

    private static func workoutSample(from sample: HealthSample) -> HKSample? {
        guard let endDate = sample.endDate ?? Calendar.current.date(byAdding: .minute, value: Int(sample.value.rounded()), to: sample.startDate) else {
            return nil
        }
        let energy = sample.metadata["active_energy_kcal"]
            .flatMap(Double.init)
            .map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) }
        let distance = sample.metadata["distance_m"]
            .flatMap(Double.init)
            .map { HKQuantity(unit: .meter(), doubleValue: $0) }
        return HKWorkout(
            activityType: .other,
            start: sample.startDate,
            end: endDate,
            duration: max(0, sample.value * 60),
            totalEnergyBurned: energy,
            totalDistance: distance,
            metadata: [
                "WhoordanLocalID": sample.id,
                "WhoordanSource": sample.source.rawValue
            ]
        )
    }

    private static func sleepSample(from sample: HealthSample) -> HKSample? {
        guard let sampleType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let endDate = sample.endDate ?? Calendar.current.date(byAdding: .minute, value: Int(sample.value.rounded()), to: sample.startDate) else {
            return nil
        }
        let value = sleepAnalysisValue(from: sample.metadata["sleep_category"])
        return HKCategorySample(
            type: sampleType,
            value: value,
            start: sample.startDate,
            end: endDate,
            metadata: commonMetadata(for: sample)
        )
    }

    private static func quantitySample(from sample: HealthSample) -> HKSample? {
        guard let identifier = writableQuantityIdentifier(for: sample.type),
              let sampleType = HKObjectType.quantityType(forIdentifier: identifier),
              let unit = unit(for: identifier) else {
            return nil
        }
        let boundedValue = healthKitQuantityValue(for: sample, identifier: identifier)
        guard let boundedValue else { return nil }
        let endDate = sample.endDate ?? sample.startDate
        return HKQuantitySample(
            type: sampleType,
            quantity: HKQuantity(unit: unit, doubleValue: boundedValue),
            start: sample.startDate,
            end: endDate,
            metadata: commonMetadata(for: sample)
        )
    }

    private static func writableQuantityIdentifier(for type: HealthSampleType) -> HKQuantityTypeIdentifier? {
        switch type {
        case .heartRate:
            return .heartRate
        case .restingHeartRate:
            return .restingHeartRate
        case .heartRateVariabilityRMSSD:
            return nil
        case .heartRateVariabilitySDNN:
            return .heartRateVariabilitySDNN
        case .respiratoryRate:
            return .respiratoryRate
        case .steps:
            return .stepCount
        case .activeEnergy:
            return .activeEnergyBurned
        case .distanceWalkingRunning:
            return .distanceWalkingRunning
        case .oxygenSaturation:
            return .oxygenSaturation
        case .bodyTemperature:
            return .bodyTemperature
        case .vo2Max:
            return .vo2Max
        default:
            return nil
        }
    }

    private static func healthKitQuantityValue(for sample: HealthSample, identifier: HKQuantityTypeIdentifier) -> Double? {
        switch identifier {
        case .heartRate, .restingHeartRate:
            return (25...240).contains(sample.value) ? sample.value : nil
        case .heartRateVariabilitySDNN:
            return (0...500).contains(sample.value) ? sample.value : nil
        case .respiratoryRate:
            return (4...60).contains(sample.value) ? sample.value : nil
        case .stepCount:
            return sample.value >= 0 ? sample.value.rounded() : nil
        case .activeEnergyBurned:
            return (0...20_000).contains(sample.value) ? sample.value : nil
        case .distanceWalkingRunning:
            return (0...250_000).contains(sample.value) ? sample.value : nil
        case .oxygenSaturation:
            guard sample.value > 0 else { return nil }
            return sample.value > 1 ? sample.value / 100 : sample.value
        case .bodyTemperature:
            return (30...45).contains(sample.value) ? sample.value : nil
        case .vo2Max:
            return (5...100).contains(sample.value) ? sample.value : nil
        default:
            return nil
        }
    }

    private static func sleepAnalysisValue(from category: String?) -> Int {
        switch category {
        case "0":
            return HKCategoryValueSleepAnalysis.inBed.rawValue
        case "2":
            return HKCategoryValueSleepAnalysis.awake.rawValue
        case "3":
            if #available(iOS 16.0, *) {
                return HKCategoryValueSleepAnalysis.asleepCore.rawValue
            }
            return HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        case "4":
            if #available(iOS 16.0, *) {
                return HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            }
            return HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        case "5":
            if #available(iOS 16.0, *) {
                return HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
            return HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        default:
            return HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        }
    }

    private static func commonMetadata(for sample: HealthSample) -> [String: Any] {
        [
            "WhoordanLocalID": sample.id,
            "WhoordanSource": sample.source.rawValue,
            "WhoordanConfidence": sample.confidence.rawValue
        ]
    }

    private static func unit(for identifier: HKQuantityTypeIdentifier) -> HKUnit? {
        switch identifier {
        case .heartRate, .restingHeartRate, .respiratoryRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
        case .stepCount:
            return .count()
        case .activeEnergyBurned:
            return .kilocalorie()
        case .distanceWalkingRunning:
            return .meter()
        case .oxygenSaturation:
            return .percent()
        case .bodyTemperature, .appleSleepingWristTemperature:
            return .degreeCelsius()
        case .vo2Max:
            return HKUnit(from: "mL/kg*min")
        default:
            return nil
        }
    }

    private static func notAuthorizedMessage(types: [HealthSampleType], writtenCount: Int) -> String {
        let typeList = types.map(\.rawValue).joined(separator: ", ")
        if writtenCount > 0 {
            return "Wrote \(writtenCount) Apple Health samples. Skipped types without write permission: \(typeList)."
        }
        return "Apple Health export is enabled, but write permission is off for queued types: \(typeList)."
    }

    private static func sanitizedErrorMessage(_ message: String) -> String {
        let trimmed = message
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(180))
    }
    #endif
}

enum HealthKitMapper {
    static func normalizeQuantity(
        identifier: String,
        value: Double,
        start: Date,
        end: Date?,
        sourceName: String?,
        sourceRecordID: String
    ) -> HealthSample? {
        let mapped: (HealthSampleType, String, Double)?
        switch identifier {
        case "HKQuantityTypeIdentifierHeartRate":
            mapped = (value > 25 && value < 240) ? (.heartRate, "bpm", value) : nil
        case "HKQuantityTypeIdentifierRestingHeartRate":
            mapped = (value > 25 && value < 180) ? (.restingHeartRate, "bpm", value) : nil
        case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
            mapped = (value > 0 && value < 500) ? (.heartRateVariabilitySDNN, "ms", value) : nil
        case "HKQuantityTypeIdentifierRespiratoryRate":
            mapped = (value >= 4 && value <= 60) ? (.respiratoryRate, "br/min", value) : nil
        case "HKQuantityTypeIdentifierStepCount":
            mapped = (value >= 0 && value < 200_000) ? (.steps, "count", value.rounded()) : nil
        case "HKQuantityTypeIdentifierActiveEnergyBurned":
            mapped = (value >= 0 && value < 20_000) ? (.activeEnergy, "kcal", value) : nil
        case "HKQuantityTypeIdentifierDistanceWalkingRunning":
            mapped = (value >= 0 && value < 250_000) ? (.distanceWalkingRunning, "m", value) : nil
        case "HKQuantityTypeIdentifierOxygenSaturation":
            mapped = (value > 0 && value <= 100) ? (.oxygenSaturation, "%", value <= 1 ? value * 100 : value) : nil
        case "HKQuantityTypeIdentifierBodyTemperature":
            mapped = (value >= 30 && value <= 45) ? (.bodyTemperature, "degC", value) : nil
        case "HKQuantityTypeIdentifierAppleSleepingWristTemperature":
            mapped = (value >= 20 && value <= 45) ? (.wristTemperature, "degC", value) : nil
        case "HKQuantityTypeIdentifierVO2Max":
            mapped = (value > 5 && value < 100) ? (.vo2Max, "mL/kg/min", value) : nil
        default:
            mapped = nil
        }
        guard let mapped else { return nil }
        return HealthSample(
            id: "apple_health-\(sourceRecordID)",
            type: mapped.0,
            value: mapped.2,
            unit: mapped.1,
            startDate: start,
            endDate: end,
            source: .appleHealth,
            sourceRecordID: sourceRecordID,
            confidence: .high,
            metadata: ["source_label": sourceName ?? "Apple Health"]
        )
    }

    static func normalizeSleepCategory(
        value: Int,
        start: Date,
        end: Date,
        sourceName: String?,
        sourceRecordID: String
    ) -> HealthSample? {
        let minutes = max(0, end.timeIntervalSince(start) / 60)
        guard minutes > 0 else { return nil }
        return HealthSample(
            id: "apple_health-\(sourceRecordID)",
            type: .sleepAnalysis,
            value: minutes,
            unit: "min",
            startDate: start,
            endDate: end,
            source: .appleHealth,
            sourceRecordID: sourceRecordID,
            confidence: .high,
            metadata: [
                "source_label": sourceName ?? "Apple Health",
                "sleep_category": "\(value)"
            ]
        )
    }

    static func normalizeWorkout(
        durationMinutes: Double,
        activeEnergyKilocalories: Double?,
        distanceMeters: Double?,
        start: Date,
        end: Date,
        sourceName: String?,
        sourceRecordID: String
    ) -> HealthSample {
        var metadata = ["source_label": sourceName ?? "Apple Health"]
        if let activeEnergyKilocalories {
            metadata["active_energy_kcal"] = String(format: "%.1f", activeEnergyKilocalories)
        }
        if let distanceMeters {
            metadata["distance_m"] = String(format: "%.1f", distanceMeters)
        }
        return HealthSample(
            id: "apple_health-\(sourceRecordID)",
            type: .workout,
            value: max(0, durationMinutes),
            unit: "min",
            startDate: start,
            endDate: end,
            source: .appleHealth,
            sourceRecordID: sourceRecordID,
            confidence: .high,
            metadata: metadata
        )
    }
}
