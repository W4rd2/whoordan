import Foundation

enum HealthSampleType: String, Codable, Equatable, Hashable, CaseIterable {
    case heartRate
    case restingHeartRate
    case heartRateVariabilitySDNN
    case heartRateVariabilityRMSSD
    case respiratoryRate
    case sleepAnalysis
    case steps
    case activeEnergy
    case distanceWalkingRunning
    case oxygenSaturation
    case bodyTemperature
    case wristTemperature
    case workout
    case vo2Max
    case wearablePPG
    case wearableIMU
    case temperatureEvent
}

struct HealthSample: Codable, Equatable, Identifiable {
    let id: String
    let type: HealthSampleType
    let value: Double
    let unit: String
    let startDate: Date
    let endDate: Date?
    let source: DataSource
    let sourceRecordID: String
    let confidence: ConfidenceLevel
    let metadata: [String: String]

    var dedupeID: String {
        [source.rawValue, type.rawValue, sourceRecordID].joined(separator: ":")
    }
}

struct DailyHealthSummary: Codable, Equatable {
    var date = Date()
    var recovery: ScoreValue?
    var strain: ScoreValue?
    var movement = MovementSummary.empty()
    var sleepSummary: SleepSummary?
    var sleepMinutes: Double?
    var sleepNeedMinutes: Double?
    var sleepDebtMinutes: Double?
    var restingHeartRate: Double?
    var restingHeartRateSource: DataSource?
    var restingHeartRateConfidence: ConfidenceLevel?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateSampleCount: Int?
    var heartRateCoverageMinutes: Double?
    var hrv: Double?
    var hrvSource: DataSource?
    var hrvConfidence: ConfidenceLevel?
    var respiratoryRate: Double?
    var respiratoryRateSource: DataSource?
    var respiratoryRateConfidence: ConfidenceLevel?
    var oxygenSaturation: Double?
    var oxygenSaturationSource: DataSource?
    var oxygenSaturationConfidence: ConfidenceLevel?
    var vo2Max: Double?
    var vo2MaxSource: DataSource?
    var vo2MaxConfidence: ConfidenceLevel?
    var rawWristTemperatureC: Double?
    var rawWristTemperatureSource: DataSource?
    var rawWristTemperatureConfidence: ConfidenceLevel?
    var bodyTemperatureDelta: Double?
    var source: DataSource?
    var confidence: ConfidenceLevel = .unavailable

    static let empty = DailyHealthSummary()

    var hasSyncableContent: Bool {
        recovery != nil
            || strain != nil
            || sleepMinutes != nil
            || sleepSummary?.hasSleep == true
            || movement.steps != nil
            || movement.activeEnergyKilocalories != nil
            || movement.movementMinutes != nil
            || restingHeartRate != nil
            || averageHeartRate != nil
            || maxHeartRate != nil
            || heartRateCoverageMinutes != nil
            || hrv != nil
            || respiratoryRate != nil
            || oxygenSaturation != nil
            || vo2Max != nil
            || rawWristTemperatureC != nil
            || bodyTemperatureDelta != nil
    }
}

enum BiologicalSex: String, Codable, Equatable, CaseIterable, Identifiable {
    case notSet
    case female
    case male

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notSet: return "Not set"
        case .female: return "Female"
        case .male: return "Male"
        }
    }

    var mifflinStJeorConstant: Double? {
        switch self {
        case .female: return -161
        case .male: return 5
        case .notSet: return nil
        }
    }
}

struct BodyProfile: Codable, Equatable {
    static let validAgeYears = 13...100
    static let validHeightCentimeters = 90.0...250.0
    static let validWeightKilograms = 30.0...250.0
    static let validMaxHeartRate = 80.0...240.0

    var birthDate: Date?
    var ageYears: Int?
    var biologicalSex: BiologicalSex
    var heightCentimeters: Double?
    var weightKilograms: Double?
    var configuredMaxHeartRate: Double?
    var updatedAt: Date?

    init(
        birthDate: Date? = nil,
        ageYears: Int? = nil,
        biologicalSex: BiologicalSex = .notSet,
        heightCentimeters: Double? = nil,
        weightKilograms: Double? = nil,
        configuredMaxHeartRate: Double? = nil,
        updatedAt: Date? = nil
    ) {
        self.birthDate = birthDate
        self.ageYears = ageYears
        self.biologicalSex = biologicalSex
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
        self.configuredMaxHeartRate = configuredMaxHeartRate
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool {
        birthDate == nil
            && ageYears == nil
            && biologicalSex == .notSet
            && heightCentimeters == nil
            && weightKilograms == nil
            && configuredMaxHeartRate == nil
    }

    var isCompleteForRestingEnergy: Bool {
        bmrKilocaloriesPerDay() != nil
    }

    var profileCompletionSummary: String {
        var missing: [String] = []
        if resolvedAgeYears() == nil { missing.append("birth date") }
        if biologicalSex == .notSet { missing.append("sex") }
        if heightCentimeters == nil { missing.append("height") }
        if weightKilograms == nil { missing.append("weight") }
        if missing.isEmpty {
            return configuredMaxHeartRate == nil ? "Energy ready; max HR can improve zones." : "Energy and zones ready."
        }
        return "Missing \(missing.joined(separator: ", "))."
    }

    func normalized(updatedAt: Date) -> BodyProfile {
        BodyProfile(
            birthDate: birthDate,
            ageYears: ageYears,
            biologicalSex: biologicalSex,
            heightCentimeters: heightCentimeters,
            weightKilograms: weightKilograms,
            configuredMaxHeartRate: configuredMaxHeartRate,
            updatedAt: updatedAt
        )
    }

    func validationError(on referenceDate: Date = Date(), calendar: Calendar = .current) -> String? {
        if let birthDate {
            guard birthDate <= referenceDate else {
                return "Birth date cannot be in the future."
            }
            guard let age = resolvedAgeYears(on: referenceDate, calendar: calendar),
                  Self.validAgeYears.contains(age) else {
                return "Birth date must make age between \(Self.validAgeYears.lowerBound) and \(Self.validAgeYears.upperBound)."
            }
        } else if let ageYears, !Self.validAgeYears.contains(ageYears) {
            return "Age must be between \(Self.validAgeYears.lowerBound) and \(Self.validAgeYears.upperBound)."
        }
        if let heightCentimeters, !Self.validHeightCentimeters.contains(heightCentimeters) {
            return "Height must be between 90 and 250 cm."
        }
        if let weightKilograms, !Self.validWeightKilograms.contains(weightKilograms) {
            return "Weight must be between 30 and 250 kg."
        }
        if let configuredMaxHeartRate, !Self.validMaxHeartRate.contains(configuredMaxHeartRate) {
            return "Max heart rate must be between 80 and 240 bpm."
        }
        return nil
    }

    func resolvedAgeYears(on referenceDate: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let birthDate else { return ageYears }
        guard birthDate <= referenceDate else { return nil }
        return calendar.dateComponents(
            [.year],
            from: calendar.startOfDay(for: birthDate),
            to: calendar.startOfDay(for: referenceDate)
        ).year
    }

    func bmrKilocaloriesPerDay(on referenceDate: Date = Date(), calendar: Calendar = .current) -> Double? {
        guard let weightKilograms,
              let heightCentimeters,
              let ageYears = resolvedAgeYears(on: referenceDate, calendar: calendar),
              let sexConstant = biologicalSex.mifflinStJeorConstant else {
            return nil
        }
        return (10 * weightKilograms) + (6.25 * heightCentimeters) - (5 * Double(ageYears)) + sexConstant
    }

    func preferredMaxHeartRate(on referenceDate: Date = Date(), calendar: Calendar = .current) -> (value: Double, estimated: Bool)? {
        if let configuredMaxHeartRate {
            return (configuredMaxHeartRate, false)
        }
        guard let ageYears = resolvedAgeYears(on: referenceDate, calendar: calendar) else { return nil }
        return (208 - (0.7 * Double(ageYears)), true)
    }

    func estimatedDistanceMeters(fromSteps steps: Int) -> Double? {
        guard let heightCentimeters, steps > 0 else { return nil }
        let stepLengthMeters = (heightCentimeters / 100) * 0.414
        return Double(steps) * stepLengthMeters
    }
}

enum SkinTemperatureBaselineSource: String, Codable, Equatable {
    case none
    case temporaryCustom
    case automatic
}

struct SkinTemperatureBaselineProfile: Codable, Equatable {
    static let requiredDayCountDefault = 5
    static let validBaselineRangeC = 20.0...45.0

    var activeBaselineC: Double?
    var source: SkinTemperatureBaselineSource
    var eligibleDayCount: Int
    var requiredDayCount: Int
    var updatedAt: Date?
    var automaticBaselineSetAt: Date?

    init(
        activeBaselineC: Double? = nil,
        source: SkinTemperatureBaselineSource = .none,
        eligibleDayCount: Int = 0,
        requiredDayCount: Int = SkinTemperatureBaselineProfile.requiredDayCountDefault,
        updatedAt: Date? = nil,
        automaticBaselineSetAt: Date? = nil
    ) {
        self.activeBaselineC = activeBaselineC
        self.source = activeBaselineC == nil && source != .automatic ? .none : source
        self.eligibleDayCount = max(0, eligibleDayCount)
        self.requiredDayCount = max(1, requiredDayCount)
        self.updatedAt = updatedAt
        self.automaticBaselineSetAt = automaticBaselineSetAt
    }

    var isAutomatic: Bool {
        source == .automatic && activeBaselineC != nil
    }

    var canEditTemporaryBaseline: Bool {
        !isAutomatic
    }

    var hasTemporaryBaseline: Bool {
        source == .temporaryCustom && activeBaselineC != nil
    }

    var hasActiveBaseline: Bool {
        activeBaselineC != nil && source != .none
    }

    var daysRemaining: Int {
        max(requiredDayCount - eligibleDayCount, 0)
    }

    var isMeaningfulForCloudSync: Bool {
        hasActiveBaseline
            || eligibleDayCount > 0
            || updatedAt != nil
            || automaticBaselineSetAt != nil
    }

    var cloudConflictUpdatedAt: Date {
        [updatedAt, automaticBaselineSetAt].compactMap { $0 }.max() ?? .distantPast
    }

    var sanitizedForCloudSync: SkinTemperatureBaselineProfile {
        let active = activeBaselineC.flatMap { Self.validBaselineRangeC.contains($0) ? $0 : nil }
        let resolvedSource: SkinTemperatureBaselineSource
        if active == nil {
            resolvedSource = .none
        } else if source == .none {
            resolvedSource = .temporaryCustom
        } else {
            resolvedSource = source
        }
        return SkinTemperatureBaselineProfile(
            activeBaselineC: active,
            source: resolvedSource,
            eligibleDayCount: eligibleDayCount,
            requiredDayCount: requiredDayCount,
            updatedAt: updatedAt,
            automaticBaselineSetAt: automaticBaselineSetAt
        )
    }
}

struct MovementSummary: Codable, Equatable {
    var steps: Int?
    var goal: Int
    var activeEnergyKilocalories: Double?
    var walkingRunningDistanceMeters: Double?
    var movementMinutes: Double?
    var source: DataSource?
    var confidence: ConfidenceLevel
    var lastUpdated: Date?
    var trendDescription: String?

    var goalProgress: Double? {
        guard let steps, goal > 0 else { return nil }
        return min(Double(steps) / Double(goal), 1)
    }

    static func empty(goal: Int = 10_000) -> MovementSummary {
        MovementSummary(
            steps: nil,
            goal: goal,
            activeEnergyKilocalories: nil,
            walkingRunningDistanceMeters: nil,
            movementMinutes: nil,
            source: nil,
            confidence: .unavailable,
            lastUpdated: nil,
            trendDescription: nil
        )
    }
}

struct ScoreValue: Codable, Equatable {
    let value: Double
    let scale: ClosedRange<Double>
    let confidence: ConfidenceLevel
    let explanation: String
}

struct SleepSession: Codable, Equatable, Identifiable {
    let id: String
    let start: Date
    let end: Date
    let asleepMinutes: Double
    let inBedMinutes: Double
    let efficiencyPercent: Double?
    let source: DataSource
    let confidence: ConfidenceLevel
    let stageSegments: [SleepStageSegment]

    init(
        id: String,
        start: Date,
        end: Date,
        asleepMinutes: Double,
        inBedMinutes: Double,
        efficiencyPercent: Double?,
        source: DataSource,
        confidence: ConfidenceLevel,
        stageSegments: [SleepStageSegment] = []
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.asleepMinutes = asleepMinutes
        self.inBedMinutes = inBedMinutes
        self.efficiencyPercent = efficiencyPercent
        self.source = source
        self.confidence = confidence
        self.stageSegments = stageSegments
    }

    var isNap: Bool {
        asleepMinutes < SleepSummary.napMaximumMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case start
        case end
        case asleepMinutes
        case inBedMinutes
        case efficiencyPercent
        case source
        case confidence
        case stageSegments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        asleepMinutes = try container.decode(Double.self, forKey: .asleepMinutes)
        inBedMinutes = try container.decode(Double.self, forKey: .inBedMinutes)
        efficiencyPercent = try container.decodeIfPresent(Double.self, forKey: .efficiencyPercent)
        source = try container.decode(DataSource.self, forKey: .source)
        confidence = try container.decode(ConfidenceLevel.self, forKey: .confidence)
        stageSegments = try container.decodeIfPresent([SleepStageSegment].self, forKey: .stageSegments) ?? []
    }
}

enum SleepStage: String, Codable, Equatable, CaseIterable {
    case inBed = "in_bed"
    case asleep = "asleep"
    case awake
    case rem
    case core
    case deep
    case unknown

    var label: String {
        switch self {
        case .inBed: return "In bed"
        case .asleep: return "Asleep"
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        case .unknown: return "Unclassified"
        }
    }
}

struct SleepStageSegment: Codable, Equatable, Identifiable {
    let id: String
    let stage: SleepStage
    let start: Date
    let end: Date
    let minutes: Double
    let source: DataSource
    let confidence: ConfidenceLevel
}

struct SleepSummary: Codable, Equatable {
    static let napMaximumMinutes = 180.0

    var mainSleep: SleepSession?
    var naps: [SleepSession]
    var sessions: [SleepSession]
    var source: DataSource?
    var confidence: ConfidenceLevel
    var lastUpdated: Date?

    var totalAsleepMinutes: Double? {
        guard !sessions.isEmpty else { return nil }
        return sessions.reduce(0) { $0 + $1.asleepMinutes }
    }

    var napMinutes: Double? {
        guard !naps.isEmpty else { return nil }
        return naps.reduce(0) { $0 + $1.asleepMinutes }
    }

    var awakeMinutes: Double? {
        let awake = sessions.flatMap(\.stageSegments).filter { $0.stage == .awake }.reduce(0) { $0 + $1.minutes }
        guard awake > 0 else { return nil }
        return awake
    }

    var stageTotals: [SleepStage: Double] {
        sessions
            .flatMap(\.stageSegments)
            .reduce(into: [:]) { totals, segment in
                totals[segment.stage, default: 0] += segment.minutes
            }
    }

    var restorativeMinutes: Double? {
        let total = (stageTotals[.deep] ?? 0) + (stageTotals[.rem] ?? 0)
        return total > 0 ? total : nil
    }

    var restorativePercent: Double? {
        guard let restorativeMinutes,
              let asleep = totalAsleepMinutes,
              asleep > 0 else {
            return nil
        }
        return min(max(restorativeMinutes / asleep * 100, 0), 100)
    }

    var hasSleep: Bool {
        !sessions.isEmpty
    }

    static func empty() -> SleepSummary {
        SleepSummary(
            mainSleep: nil,
            naps: [],
            sessions: [],
            source: nil,
            confidence: .unavailable,
            lastUpdated: nil
        )
    }
}

struct Workout: Codable, Equatable, Identifiable {
    let id: String
    let start: Date
    let end: Date
    let activityName: String
    let durationMinutes: Double
    let sourceEnergy: Double?
    let maxHeartRate: Double?
    let averageHeartRate: Double?
    let zonePercentages: [Int: Double]
    let source: DataSource
}

struct JournalEntry: Codable, Equatable, Identifiable {
    let id: String
    let prompt: String
    let answeredYes: Bool
    let day: Date
    let source: DataSource
}

enum WhoordanMetricID: String, Codable, Equatable, CaseIterable, Identifiable {
    case heartRate
    case averageHeartRate
    case heartRateZones
    case restingHeartRate
    case hrv
    case rawWristTemperature
    case skinTemperatureDelta
    case sleepPerformance
    case sleepDuration
    case sleepNeed
    case sleepDebt
    case sleepConsistency
    case sleepStages
    case restorativeSleepPercent
    case restorativeSleepHours
    case recovery
    case dayStrain
    case activityStrain
    case workoutCalories
    case dailyCalories
    case steps
    case stress
    case respiratoryRate
    case spo2
    case vo2Max

    var id: String { rawValue }
}

enum MetricVisibilityStatus: String, Codable, Equatable, CaseIterable {
    case visibleNow = "visible_now"
    case visibleWhenEnoughData = "visible_when_enough_data"
    case gatedByPermission = "gated_by_permission"
    case gatedByConsent = "gated_by_consent"
    case gatedByApproval = "gated_by_approval"
    case intentionallyHidden = "intentionally_hidden"
    case developerDiagnosticOnly = "developer_diagnostic_only"
    case blockedByPlatformOrHardware = "blocked_by_platform_or_hardware"
    case unimplementedReleaseBlocker = "unimplemented_release_blocker"
}

enum MetricProductionVerdict: String, Codable, Equatable, CaseIterable {
    case ship
    case shipAsEstimate = "ship as estimate"
    case gate
    case remove
    case blocked
}

struct MetricVisibilityRegistryEntry: Codable, Equatable, Identifiable {
    let id: String
    let metricID: WhoordanMetricID?
    let sampleTypes: [HealthSampleType]
    let status: MetricVisibilityStatus
    let sourceFields: [String]
    let codeLocations: [String]
    let sourceKind: String
    let formulaOrDerivation: String
    let minimumDataRequired: String
    let baselineWindowRequired: String
    let freshnessWindow: String
    let confidenceThreshold: ConfidenceLevel
    let permissionGate: String
    let approvalGate: String
    let consentGate: String
    let uiDestination: String
    let emptyStateCopy: String
    let insufficientDataCopy: String
    let staleDataBehavior: String
    let errorBehavior: String
    let userUnlockAction: String
    let automatedTests: [String]
    let manualValidationRequired: String
    let productionVerdict: MetricProductionVerdict
}

enum MetricVisibilityRegistry {
    static let entries: [MetricVisibilityRegistryEntry] = [
        entry(
            metricID: .heartRate,
            sampleTypes: [.heartRate],
            sourceFields: ["DailyHealthSummary.latestHeartRate", "WearableDeviceState.liveHeartRateBPM"],
            codeLocations: ["Whoordan/Core/Models/HealthModels.swift", "Whoordan/Core/BLE/WearableProtocol.swift"],
            sourceKind: "Direct BLE heart-rate reading or trusted source-labeled import",
            formulaOrDerivation: "Direct bpm value after range validation",
            minimumDataRequired: "One valid heart-rate sample or fresh live packet",
            freshnessWindow: "Live packet under 10 minutes; summary value for the selected day",
            confidenceThreshold: .medium,
            uiDestination: "Today live card, Heart detail, Device live state",
            emptyStateCopy: "Connect a supported wearable to show live heart rate.",
            insufficientDataCopy: "Waiting for a valid heart-rate packet.",
            manualValidationRequired: "Physical wearable long-session validation"
        ),
        entry(
            metricID: .averageHeartRate,
            sampleTypes: [.heartRate],
            sourceFields: ["DailyHealthSummary.averageHeartRate", "DailyHealthSummary.heartRateSampleCount"],
            sourceKind: "Derived from valid heart-rate samples",
            formulaOrDerivation: "Arithmetic average over accepted samples",
            minimumDataRequired: "At least six valid HR samples",
            freshnessWindow: "Selected day",
            confidenceThreshold: .medium,
            uiDestination: "Today metric dashboard and Heart detail",
            emptyStateCopy: "Average HR appears after enough valid heart-rate samples.",
            insufficientDataCopy: "Needs at least six valid heart-rate samples."
        ),
        entry(
            metricID: .heartRateZones,
            sampleTypes: [.heartRate],
            sourceFields: ["BodyProfile.maxHeartRate", "DailyHealthSummary.heartRateZoneMinutes"],
            sourceKind: "Calculated from validated HR and user-specific max HR",
            formulaOrDerivation: "Zone buckets derived from max-HR percentage thresholds",
            minimumDataRequired: "Configured max HR or age plus validated HR windows",
            confidenceThreshold: .medium,
            uiDestination: "Heart detail and metric dashboard",
            emptyStateCopy: "Zones appear after HR and a max-HR threshold are available.",
            insufficientDataCopy: "Needs HR samples and a max-HR basis."
        ),
        entry(
            metricID: .restingHeartRate,
            sampleTypes: [.restingHeartRate, .heartRate],
            sourceFields: ["DailyHealthSummary.restingHeartRate", "Sleep-window HR samples"],
            sourceKind: "Direct RHR source or sleep-window derived estimate",
            formulaOrDerivation: "Trusted direct RHR, otherwise low percentile sleep-window HR",
            minimumDataRequired: "Direct RHR or enough sleep-window HR samples",
            baselineWindowRequired: "Five prior eligible days for baseline-relative recovery use",
            confidenceThreshold: .medium,
            uiDestination: "Recovery, Heart detail, Today metric dashboard",
            emptyStateCopy: "Resting HR appears after a sleep-window or direct source exists.",
            insufficientDataCopy: "Needs a direct RHR or enough overnight HR samples."
        ),
        entry(
            metricID: .hrv,
            sampleTypes: [.heartRateVariabilityRMSSD, .heartRateVariabilitySDNN],
            sourceFields: ["DailyHealthSummary.hrv", "RR intervals"],
            sourceKind: "Direct HRV source or RR/IBI-derived HRV",
            formulaOrDerivation: "RMSSD preferred; SDNN fallback. Never estimated from BPM.",
            minimumDataRequired: "Enough clean RR/IBI intervals from a validated source",
            baselineWindowRequired: "Five prior eligible days for baseline-relative recovery use",
            confidenceThreshold: .medium,
            uiDestination: "Recovery, Heart detail, Today metric dashboard",
            emptyStateCopy: "HRV appears after clean RR/IBI intervals are available.",
            insufficientDataCopy: "Needs enough clean RR intervals."
        ),
        entry(
            metricID: .rawWristTemperature,
            sampleTypes: [.wristTemperature, .temperatureEvent],
            sourceFields: ["DailyHealthSummary.rawWristTemperatureC", "WearableDeviceState.skinTemperatureC"],
            sourceKind: "Direct raw wrist/contact temperature",
            formulaOrDerivation: "R10 raw temperature field decoded as Celsius",
            minimumDataRequired: "One valid raw wrist/contact temperature frame",
            freshnessWindow: "Live packet under 10 minutes; summary value for the selected day",
            confidenceThreshold: .medium,
            uiDestination: "Today body signals, Recovery context, Device diagnostics",
            emptyStateCopy: "Raw wrist temperature appears after a valid temperature frame.",
            insufficientDataCopy: "Waiting for raw wrist/contact temperature.",
            manualValidationRequired: "Physical wearable warm/cool and non-wear validation",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .skinTemperatureDelta,
            sampleTypes: [.wristTemperature, .bodyTemperature, .temperatureEvent],
            sourceFields: ["DailyHealthSummary.bodyTemperatureDelta", "SkinTemperatureBaselineProfile"],
            sourceKind: "Derived from raw wrist/contact temperature and personal baseline",
            formulaOrDerivation: "Current raw temperature minus active personal baseline",
            minimumDataRequired: "Raw temperature plus active baseline",
            baselineWindowRequired: "Five eligible nights",
            confidenceThreshold: .low,
            uiDestination: "Recovery and Today body signals",
            emptyStateCopy: "Skin-temperature delta appears after a personal baseline is built.",
            insufficientDataCopy: "Needs five eligible nights and current raw temperature.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .sleepPerformance,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["DailyHealthSummary.sleepMinutes", "sleepNeedEstimate"],
            sourceKind: "Original wellness formula from sleep duration and estimated need",
            formulaOrDerivation: "Clamp((sleep minutes / sleep-need minutes) * 100, 0, 100)",
            minimumDataRequired: "Main sleep plus sleep-need estimate",
            baselineWindowRequired: "Two to three recent nights; five baseline days improve confidence",
            confidenceThreshold: .low,
            uiDestination: "Sleep, Today metric dashboard, Recovery context",
            emptyStateCopy: "Sleep performance appears after sleep and sleep-need data exist.",
            insufficientDataCopy: "Needs sleep duration and sleep-need estimate.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .sleepDuration,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["DailyHealthSummary.sleepMinutes", "SleepSummary.mainSleep"],
            sourceKind: "Source-labeled sleep session or low-confidence BLE estimate",
            formulaOrDerivation: "Main sleep asleep minutes",
            minimumDataRequired: "One valid main sleep session",
            freshnessWindow: "Selected sleep day",
            confidenceThreshold: .low,
            uiDestination: "Sleep tab and Today summary grid",
            emptyStateCopy: "Sleep appears after a wearable sleep session is stored.",
            insufficientDataCopy: "Needs a main sleep session.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .sleepNeed,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["DailyHealthSummary.sleepNeedMinutes", "recentSummaries"],
            sourceKind: "Original wellness estimate",
            formulaOrDerivation: "Personal recent sleep target adjusted by prior debt and strain",
            minimumDataRequired: "At least one main sleep; more nights improve stability",
            baselineWindowRequired: "Two to three recent nights preferred",
            confidenceThreshold: .low,
            uiDestination: "Sleep planner and Today metric dashboard",
            emptyStateCopy: "Sleep need appears after sleep history exists.",
            insufficientDataCopy: "Needs recent sleep sessions.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .sleepDebt,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["DailyHealthSummary.sleepDebtMinutes"],
            sourceKind: "Original wellness estimate",
            formulaOrDerivation: "Sleep need minus sleep duration, clamped at zero",
            minimumDataRequired: "Sleep duration plus sleep need",
            confidenceThreshold: .low,
            uiDestination: "Sleep planner and Today metric dashboard",
            emptyStateCopy: "Sleep debt appears after sleep duration and need exist.",
            insufficientDataCopy: "Needs sleep duration and sleep need.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .sleepConsistency,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["SleepSummary.sessions", "recentSummaries"],
            sourceKind: "Derived from sleep timing",
            formulaOrDerivation: "Recent bedtime/wake timing stability estimate",
            minimumDataRequired: "Multiple sleep sessions",
            baselineWindowRequired: "Two or more recent nights",
            confidenceThreshold: .low,
            uiDestination: "Sleep tab and Today metric dashboard",
            emptyStateCopy: "Consistency appears after multiple sleep sessions.",
            insufficientDataCopy: "Needs more than one sleep session.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .sleepStages,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["SleepSession.stageDurations"],
            sourceKind: "Source-labeled stages or low-confidence BLE-derived segments",
            formulaOrDerivation: "Stage minute totals from accepted sleep sessions",
            minimumDataRequired: "Sleep session with stage labels",
            confidenceThreshold: .low,
            uiDestination: "Sleep stages chart and metric dashboard",
            emptyStateCopy: "Stages appear after source-labeled stage data exists.",
            insufficientDataCopy: "Needs stage-labeled sleep segments.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .restorativeSleepPercent,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["SleepSession.restorativeMinutes"],
            sourceKind: "Derived from stage-labeled sleep",
            formulaOrDerivation: "Restorative minutes divided by total sleep minutes",
            minimumDataRequired: "Sleep stage data with restorative categories",
            confidenceThreshold: .low,
            uiDestination: "Sleep detail and metric dashboard",
            emptyStateCopy: "Restorative sleep appears after stage-labeled sleep exists.",
            insufficientDataCopy: "Needs deep/REM or restorative stage labels.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .restorativeSleepHours,
            sampleTypes: [.sleepAnalysis],
            sourceFields: ["SleepSession.restorativeMinutes"],
            sourceKind: "Derived from stage-labeled sleep",
            formulaOrDerivation: "Restorative minutes formatted as hours",
            minimumDataRequired: "Sleep stage data with restorative categories",
            confidenceThreshold: .low,
            uiDestination: "Sleep detail and metric dashboard",
            emptyStateCopy: "Restorative hours appear after stage-labeled sleep exists.",
            insufficientDataCopy: "Needs restorative stage labels.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .recovery,
            sampleTypes: [.heartRateVariabilityRMSSD, .heartRateVariabilitySDNN, .restingHeartRate, .respiratoryRate, .oxygenSaturation, .wristTemperature, .sleepAnalysis],
            sourceFields: ["RecoveryExplainer", "DailyHealthSummary"],
            sourceKind: "Original wellness score",
            formulaOrDerivation: "Weighted contributor fit from HRV, RHR, sleep, respiration, temperature, and SpO2 context",
            minimumDataRequired: "At least one valid current contributor",
            baselineWindowRequired: "Five prior eligible days for baseline-relative contributors",
            confidenceThreshold: .low,
            uiDestination: "Recovery tab and Today summary",
            emptyStateCopy: "Recovery appears after enough recovery signals exist.",
            insufficientDataCopy: "Needs current recovery contributors and baseline progress.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .dayStrain,
            sampleTypes: [.heartRate, .steps, .activeEnergy, .workout],
            sourceFields: ["DailyHealthSummary.strain", "WhoordanScoringService"],
            sourceKind: "Original activity load estimate",
            formulaOrDerivation: "Cardio reserve and movement load mapped to a 0-21 scale",
            minimumDataRequired: "HR, movement, workout, or active-energy input",
            confidenceThreshold: .low,
            uiDestination: "Today and Activity/strain detail",
            emptyStateCopy: "Strain appears after activity signals are stored.",
            insufficientDataCopy: "Needs HR or movement input.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .activityStrain,
            sampleTypes: [.workout, .heartRate, .activeEnergy],
            sourceFields: ["Workout", "DailyHealthSummary.workouts"],
            sourceKind: "Workout-level activity load estimate",
            formulaOrDerivation: "Workout duration, HR, and energy mapped to activity strain",
            minimumDataRequired: "One workout or activity segment",
            confidenceThreshold: .low,
            uiDestination: "Activity/strain detail and metric dashboard",
            emptyStateCopy: "Activity strain appears after a workout or activity segment.",
            insufficientDataCopy: "Needs workout, HR, or energy data.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .workoutCalories,
            sampleTypes: [.workout, .activeEnergy],
            sourceFields: ["Workout.activeEnergyKilocalories", "DailyHealthSummary.movement"],
            sourceKind: "Direct workout energy or low-confidence estimate",
            formulaOrDerivation: "Source-labeled workout energy preferred; fallback from HR reserve/duration",
            minimumDataRequired: "Workout energy or HR/duration inputs",
            confidenceThreshold: .low,
            uiDestination: "Activity detail and metric dashboard",
            emptyStateCopy: "Workout calories appear after workout energy is available.",
            insufficientDataCopy: "Needs workout energy or enough HR/duration data.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .dailyCalories,
            sampleTypes: [.activeEnergy, .heartRate],
            sourceFields: ["MovementSummary.activeEnergyKilocalories", "BodyProfile"],
            sourceKind: "Direct active energy or estimated daily energy",
            formulaOrDerivation: "Direct active energy preferred; BMR plus activity estimate fallback",
            minimumDataRequired: "Active energy, movement minutes, steps, or HR/profile inputs",
            confidenceThreshold: .low,
            uiDestination: "Today and Activity detail",
            emptyStateCopy: "Calories appear after active-energy or enough movement data exists.",
            insufficientDataCopy: "Needs active energy or movement/profile inputs.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .steps,
            sampleTypes: [.steps, .wearableIMU],
            sourceFields: ["MovementSummary.steps", "R10 accelerometer VM peaks"],
            sourceKind: "Direct step count or low-confidence IMU estimate",
            formulaOrDerivation: "Direct count preferred; R10 median-normalized recurrent peak estimate is labeled low confidence",
            minimumDataRequired: "Direct step source or complete R10 IMU chunk",
            confidenceThreshold: .low,
            uiDestination: "Today summary and metric dashboard",
            emptyStateCopy: "Steps appear after a direct step source or low-confidence IMU estimate exists.",
            insufficientDataCopy: "Needs direct steps or enough validated motion packets.",
            manualValidationRequired: "Labeled walking/running/stairs/driving/non-wear ground truth",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .stress,
            sampleTypes: [.heartRate, .heartRateVariabilityRMSSD, .heartRateVariabilitySDNN, .respiratoryRate],
            sourceFields: ["stressEstimate", "DailyHealthSummary"],
            sourceKind: "Original wellness load estimate",
            formulaOrDerivation: "Baseline-relative HRV/RHR/respiratory context mapped to 0-3",
            minimumDataRequired: "Current HRV, RHR, or respiratory context",
            baselineWindowRequired: "Five prior eligible days preferred",
            confidenceThreshold: .low,
            uiDestination: "Today metric dashboard",
            emptyStateCopy: "Stress/body load appears after baseline-linked signals exist.",
            insufficientDataCopy: "Needs HRV, RHR, or respiratory context.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .respiratoryRate,
            sampleTypes: [.respiratoryRate],
            sourceFields: ["DailyHealthSummary.respiratoryRate"],
            sourceKind: "Measured respiratory rate or RR-derived estimate",
            formulaOrDerivation: "Measured breaths/min preferred; RR sinusoid estimate remains labeled",
            minimumDataRequired: "One valid respiratory-rate sample or enough RR intervals",
            confidenceThreshold: .low,
            uiDestination: "Recovery context and metric dashboard",
            emptyStateCopy: "Respiratory rate appears after a measured source exists.",
            insufficientDataCopy: "Needs respiratory-rate data.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .spo2,
            sampleTypes: [.oxygenSaturation, .wearablePPG],
            sourceFields: ["DailyHealthSummary.oxygenSaturation", "R24 candidate"],
            sourceKind: "Measured SpO2 or low-confidence BLE-derived candidate",
            formulaOrDerivation: "Measured percent preferred; R24 candidate shown only as low-confidence wellness estimate",
            minimumDataRequired: "Measured oxygen saturation or explicit R24 candidate",
            confidenceThreshold: .low,
            uiDestination: "Heart/body signals, Recovery context, metric dashboard",
            emptyStateCopy: "SpO2 appears after a measured source or low-confidence candidate exists.",
            insufficientDataCopy: "Needs calibrated source or explicitly marked low-confidence candidate.",
            manualValidationRequired: "Validated wearable/HealthKit source comparison",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            metricID: .vo2Max,
            sampleTypes: [.vo2Max],
            sourceFields: ["DailyHealthSummary.vo2Max", "BodyProfile.maxHeartRate"],
            sourceKind: "Direct source or low-confidence formula estimate",
            formulaOrDerivation: "Direct VO2 max preferred; fallback 15.3 * maxHR / restingHR",
            minimumDataRequired: "Direct VO2 max or max HR plus resting HR",
            confidenceThreshold: .low,
            uiDestination: "Activity/Heart metric dashboard",
            emptyStateCopy: "VO2 max appears after a direct source or enough HR/profile context exists.",
            insufficientDataCopy: "Needs direct VO2 max or resting HR plus max HR.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            sampleTypes: [.distanceWalkingRunning],
            status: .visibleWhenEnoughData,
            sourceFields: ["MovementSummary.walkingRunningDistanceMeters"],
            sourceKind: "Direct distance or step-length estimate",
            formulaOrDerivation: "Direct distance preferred; fallback steps * height * 0.414",
            minimumDataRequired: "Distance source or steps plus height profile",
            confidenceThreshold: .low,
            uiDestination: "Activity detail and movement trend",
            emptyStateCopy: "Distance appears after distance or step-length data exists.",
            insufficientDataCopy: "Needs distance or steps with height.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            sampleTypes: [.bodyTemperature],
            status: .visibleWhenEnoughData,
            sourceFields: ["DailyHealthSummary.bodyTemperatureDelta"],
            sourceKind: "Direct body/wrist temperature source",
            formulaOrDerivation: "Direct Celsius value used only for temperature context",
            minimumDataRequired: "One valid temperature sample",
            confidenceThreshold: .low,
            uiDestination: "Recovery temperature context",
            emptyStateCopy: "Temperature context appears after a valid temperature source exists.",
            insufficientDataCopy: "Needs a valid temperature sample.",
            productionVerdict: .shipAsEstimate
        ),
        entry(
            sampleTypes: [.wearablePPG],
            status: .developerDiagnosticOnly,
            sourceFields: ["WearablePPGSample"],
            sourceKind: "Raw optical waveform diagnostic",
            formulaOrDerivation: "No user-facing health metric transform shipped",
            minimumDataRequired: "Debug capture only",
            confidenceThreshold: .blocked,
            permissionGate: "Developer diagnostics only after approval and Bluetooth access",
            uiDestination: "Device developer diagnostics",
            emptyStateCopy: "Raw PPG is not shown as a user metric.",
            insufficientDataCopy: "Diagnostic capture requires an approved session and explicit developer action.",
            productionVerdict: .gate
        ),
        entry(
            sampleTypes: [.wearableIMU],
            status: .developerDiagnosticOnly,
            sourceFields: ["WearableIMUSampleBatch"],
            sourceKind: "Raw accelerometer/gyroscope diagnostic",
            formulaOrDerivation: "Raw IMU is diagnostic; only explicitly labeled low-confidence derived outputs are user-facing",
            minimumDataRequired: "Debug capture only",
            confidenceThreshold: .blocked,
            permissionGate: "Developer diagnostics only after approval and Bluetooth access",
            uiDestination: "Device developer diagnostics",
            emptyStateCopy: "Raw IMU is not shown as a user metric.",
            insufficientDataCopy: "Diagnostic capture requires an approved session and explicit developer action.",
            productionVerdict: .gate
        )
    ]

    static var metricEntries: [MetricVisibilityRegistryEntry] {
        entries.filter { $0.metricID != nil }
    }

    static var diagnosticEntries: [MetricVisibilityRegistryEntry] {
        entries.filter { $0.status == .developerDiagnosticOnly }
    }

    static func entry(for metricID: WhoordanMetricID) -> MetricVisibilityRegistryEntry? {
        entries.first { $0.metricID == metricID }
    }

    private static func entry(
        metricID: WhoordanMetricID? = nil,
        sampleTypes: [HealthSampleType],
        status: MetricVisibilityStatus = .visibleWhenEnoughData,
        sourceFields: [String],
        codeLocations: [String] = ["Whoordan/Core/Models/HealthModels.swift"],
        sourceKind: String,
        formulaOrDerivation: String,
        minimumDataRequired: String,
        baselineWindowRequired: String = "None",
        freshnessWindow: String = "Selected day unless the metric is marked live",
        confidenceThreshold: ConfidenceLevel,
        permissionGate: String = "HealthKit/Bluetooth permission only when the source requires it",
        approvalGate: String = "Approved account required before protected health processing",
        consentGate: String = "Cloud sync and health-data upload require explicit health cloud consent",
        uiDestination: String,
        emptyStateCopy: String,
        insufficientDataCopy: String,
        staleDataBehavior: String = "Show stale/blocked state rather than fabricating a value",
        errorBehavior: String = "Keep last safe local state and show blocked/waiting copy",
        userUnlockAction: String = "Approve account, connect source, grant needed permission, or add more data",
        automatedTests: [String] = ["Metric visibility registry contract tests"],
        manualValidationRequired: String = "None beyond source-specific physical validation",
        productionVerdict: MetricProductionVerdict = .ship
    ) -> MetricVisibilityRegistryEntry {
        MetricVisibilityRegistryEntry(
            id: metricID?.rawValue ?? sampleTypes.map(\.rawValue).joined(separator: "+"),
            metricID: metricID,
            sampleTypes: sampleTypes,
            status: status,
            sourceFields: sourceFields,
            codeLocations: codeLocations,
            sourceKind: sourceKind,
            formulaOrDerivation: formulaOrDerivation,
            minimumDataRequired: minimumDataRequired,
            baselineWindowRequired: baselineWindowRequired,
            freshnessWindow: freshnessWindow,
            confidenceThreshold: confidenceThreshold,
            permissionGate: permissionGate,
            approvalGate: approvalGate,
            consentGate: consentGate,
            uiDestination: uiDestination,
            emptyStateCopy: emptyStateCopy,
            insufficientDataCopy: insufficientDataCopy,
            staleDataBehavior: staleDataBehavior,
            errorBehavior: errorBehavior,
            userUnlockAction: userUnlockAction,
            automatedTests: automatedTests,
            manualValidationRequired: manualValidationRequired,
            productionVerdict: productionVerdict
        )
    }
}

enum WhoordanMetricSource: String, Codable, Equatable {
    case direct
    case legacyWearable = "legacy_wearable"
    case calculated
    case mlEstimated = "ml_estimated"
    case imported
    case unavailable

    var label: String {
        switch self {
        case .direct: return "Direct"
        case .legacyWearable: return "Legacy wearable export"
        case .calculated: return "Calculated"
        case .mlEstimated: return "ML estimated"
        case .imported: return "Source-labeled"
        case .unavailable: return "Unavailable"
        }
    }
}

enum WhoordanMetricReadiness: String, Codable, Equatable, CaseIterable {
    case showNow
    case betaEstimated
    case laterBlocked

    var label: String {
        switch self {
        case .showNow: return "Show now"
        case .betaEstimated: return "Beta / estimated"
        case .laterBlocked: return "Later / blocked"
        }
    }
}

struct WhoordanMetricSnapshot: Codable, Equatable, Identifiable {
    let id: WhoordanMetricID
    let title: String
    let value: String?
    let unit: String?
    let source: WhoordanMetricSource
    let confidence: ConfidenceLevel
    let readiness: WhoordanMetricReadiness
    let accuracySummary: String?
    let accuracyDetail: String?
    let requirements: [String]
    let calibrationSummary: String?
    let lastUpdated: Date?
    let unavailableReason: String?
    let context: String
    let symbol: String

    var accessibilitySummary: String {
        var parts = [title]
        if let value {
            parts.append([value, unit].compactMap { $0 }.joined(separator: " "))
        } else if let unavailableReason {
            parts.append(unavailableReason)
        } else {
            parts.append("Unavailable")
        }
        parts.append("Source \(source.label)")
        parts.append("Confidence \(confidence.label)")
        if let accuracySummary {
            parts.append("Accuracy \(accuracySummary)")
        }
        parts.append(readiness.label)
        return parts.joined(separator: ", ")
    }
}

extension WhoordanMetricSnapshot {
    var displayValue: String {
        if let value {
            return value
        }
        switch confidence {
        case .blocked:
            return "Needs source"
        case .unavailable:
            return "Waiting"
        default:
            return "Not ready"
        }
    }

    var displayValueWithUnit: String {
        guard let value else {
            return displayValue
        }
        guard let unit else { return value }
        if unit == "%" || unit.hasPrefix("/") {
            return "\(value)\(unit)"
        }
        return "\(value) \(unit)"
    }

    var signalDetail: String {
        if let unavailableReason {
            return unavailableReason
        }
        if let accuracySummary {
            return "\(source.label), \(confidence.label). \(accuracySummary)."
        }
        return "\(source.label), \(confidence.label). \(context)"
    }
}

struct MetricDetailTimelinePoint: Equatable, Identifiable {
    let date: Date
    let value: Double
    let label: String

    var id: String {
        "\(date.timeIntervalSince1970)-\(value)-\(label)"
    }
}

struct MetricDetailTimeline: Equatable {
    let metricID: WhoordanMetricID
    let points: [MetricDetailTimelinePoint]
    let sampleTypesLoaded: [HealthSampleType]
    let rangeStart: Date
    let rangeEnd: Date
    let wasLimited: Bool

    static func empty(metricID: WhoordanMetricID, rangeStart: Date, rangeEnd: Date) -> MetricDetailTimeline {
        MetricDetailTimeline(
            metricID: metricID,
            points: [],
            sampleTypesLoaded: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            wasLimited: false
        )
    }
}

enum WhoordanMetricCatalog {
    private static let liveSignalFreshness: TimeInterval = 10 * 60

    static func metrics(
        summary: DailyHealthSummary,
        deviceState: WearableDeviceState,
        baselineProfile: SkinTemperatureBaselineProfile,
        bodyProfile: BodyProfile = BodyProfile(),
        recentSummaries: [DailyHealthSummary] = [],
        now: Date = Date()
    ) -> [WhoordanMetricSnapshot] {
        [
            heartRate(summary: summary, deviceState: deviceState, now: now),
            restingHeartRate(summary: summary),
            averageHeartRate(summary: summary, deviceState: deviceState),
            heartRateZones(summary: summary, bodyProfile: bodyProfile),
            hrv(summary: summary),
            rawWristTemperature(summary: summary, deviceState: deviceState, now: now),
            skinTemperatureDelta(summary: summary, deviceState: deviceState, baselineProfile: baselineProfile, now: now),
            sleepDuration(summary: summary),
            sleepPerformance(summary: summary, recentSummaries: recentSummaries),
            sleepNeed(summary: summary, recentSummaries: recentSummaries),
            sleepDebt(summary: summary, recentSummaries: recentSummaries),
            sleepConsistency(summary: summary, recentSummaries: recentSummaries),
            sleepStages(summary: summary),
            restorativeSleepPercent(summary: summary),
            restorativeSleepHours(summary: summary),
            recovery(summary: summary, recentSummaries: recentSummaries),
            dayStrain(summary: summary, bodyProfile: bodyProfile),
            activityStrain(summary: summary, bodyProfile: bodyProfile),
            workoutCalories(summary: summary, bodyProfile: bodyProfile),
            dailyCalories(summary: summary, bodyProfile: bodyProfile),
            steps(summary: summary),
            stress(summary: summary, recentSummaries: recentSummaries),
            respiratoryRate(summary: summary),
            spo2(summary: summary),
            vo2Max(summary: summary, bodyProfile: bodyProfile, recentSummaries: recentSummaries)
        ]
    }

    static func grouped(
        summary: DailyHealthSummary,
        deviceState: WearableDeviceState,
        baselineProfile: SkinTemperatureBaselineProfile,
        bodyProfile: BodyProfile = BodyProfile(),
        recentSummaries: [DailyHealthSummary] = [],
        now: Date = Date()
    ) -> [WhoordanMetricReadiness: [WhoordanMetricSnapshot]] {
        Dictionary(
            grouping: metrics(
                summary: summary,
                deviceState: deviceState,
                baselineProfile: baselineProfile,
                bodyProfile: bodyProfile,
                recentSummaries: recentSummaries,
                now: now
            ),
            by: \.readiness
        )
    }

    private static func heartRate(summary: DailyHealthSummary, deviceState: WearableDeviceState, now: Date) -> WhoordanMetricSnapshot {
        let liveTimestamp = deviceState.liveHeartRateAt ?? deviceState.lastPacketAt
        let liveIsFresh = isFresh(liveTimestamp, now: now)
        if let live = deviceState.liveHeartRateBPM, liveIsFresh {
            return snapshot(
                id: .heartRate,
                title: "Heart rate",
                value: "\(live)",
                unit: "bpm",
                source: .direct,
                confidence: .high,
                readiness: .showNow,
                accuracySummary: "100% within 3 bpm in targeted validation",
                accuracyDetail: "Final targeted R10 validation compared 755 controlled rows across 16 files: MAE 0.11 bpm, max error 2 bpm, and 100% within 3 bpm.",
                requirements: ["Live R10/GATT heart-rate packet"],
                lastUpdated: liveTimestamp ?? now,
                context: "Direct R10/GATT heart-rate readings. All-recorded controlled validation also covered 1,187 rows with 99.9% within 3 bpm.",
                symbol: "heart"
            )
        }
        let fallbackSource = summary.restingHeartRateSource ?? summary.source
        let staleLiveReason = deviceState.liveHeartRateBPM != nil && !liveIsFresh
            ? "Latest live heart-rate packet is stale; waiting for a fresh R10/GATT heart-rate packet."
            : nil
        return snapshot(
            id: .heartRate,
            title: "Heart rate",
            value: summary.restingHeartRate.map { format($0, digits: 0) },
            unit: "bpm",
            source: summary.restingHeartRate == nil ? .unavailable : sourceKind(for: fallbackSource),
            confidence: summary.restingHeartRate == nil ? .blocked : .medium,
            readiness: summary.restingHeartRate == nil ? .laterBlocked : .showNow,
            accuracySummary: summary.restingHeartRate == nil ? "Blocked until measured" : "Source-labeled",
            requirements: ["Live R10/GATT heart-rate packet or source-labeled resting HR"],
            lastUpdated: summary.restingHeartRate == nil ? nil : summary.date,
            unavailableReason: summary.restingHeartRate == nil ? (staleLiveReason ?? "Connect R10/GATT heart rate or another measured heart source.") : nil,
            context: "Live heart rate is direct when the wearable stream is connected.",
            symbol: "heart"
        )
    }

    private static func restingHeartRate(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        let source = summary.restingHeartRateSource ?? summary.source
        let confidence = summary.restingHeartRateConfidence ?? (summary.restingHeartRate == nil ? .blocked : .medium)
        return snapshot(
            id: .restingHeartRate,
            title: "Resting HR",
            value: summary.restingHeartRate.map { format($0, digits: 0) },
            unit: "bpm",
            source: summary.restingHeartRate == nil ? .unavailable : sourceKind(for: source),
            confidence: confidence,
            readiness: summary.restingHeartRate == nil ? .laterBlocked : (summary.restingHeartRateSource == .whoordanEstimate ? .betaEstimated : .showNow),
            accuracySummary: summary.restingHeartRateSource == .whoordanEstimate ? "Directional sleep-window estimate" : "Source-labeled when measured",
            requirements: ["Source-labeled RHR, or enough HR samples inside a source-labeled sleep window"],
            lastUpdated: summary.restingHeartRate == nil ? nil : summary.date,
            unavailableReason: summary.restingHeartRate == nil ? "Needs measured resting heart-rate data." : nil,
            context: summary.restingHeartRateSource == .whoordanEstimate
                ? "Beta sleep-window resting HR from enough source-labeled sleep and HR samples; never derived from casual daytime BPM."
                : "Shown from source-labeled resting HR when available; not inferred from casual daytime BPM.",
            symbol: "heart.text.square"
        )
    }

    private static func averageHeartRate(summary: DailyHealthSummary, deviceState: WearableDeviceState) -> WhoordanMetricSnapshot {
        if let average = summary.averageHeartRate,
           let count = summary.heartRateSampleCount,
           count >= 6 {
            return snapshot(
                id: .averageHeartRate,
                title: "Average HR",
                value: format(average, digits: 0),
                unit: "bpm",
                source: .calculated,
                confidence: count >= 24 ? .medium : .directional,
                readiness: .betaEstimated,
                accuracySummary: "Calculated from direct HR",
                accuracyDetail: "The arithmetic mean is exact for the stored valid samples; daily representativeness depends on coverage.",
                requirements: ["At least six valid HR samples", "More samples across the day for daily-average confidence"],
                calibrationSummary: "\(count) valid HR samples in this window.",
                lastUpdated: summary.date,
                context: "Sample-window average from \(count) valid HR points stored for the day. Confidence rises with coverage.",
                symbol: "chart.xyaxis.line"
            )
        }
        return snapshot(
            id: .averageHeartRate,
            title: "Average HR",
            value: nil,
            unit: "bpm",
            source: .calculated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until HR coverage exists",
            requirements: ["At least six valid HR samples"],
            lastUpdated: deviceState.lastPacketAt ?? summary.date,
            unavailableReason: "Needs defined windows and enough direct heart-rate samples.",
            context: "Can be derived from the HR stream after the app stores validated windows.",
            symbol: "chart.xyaxis.line"
        )
    }

    private static func heartRateZones(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> WhoordanMetricSnapshot {
        if let maxHR = bodyProfile.preferredMaxHeartRate() {
            let sourceText = maxHR.estimated ? "age-estimated" : "configured"
            let sampleText = summary.heartRateSampleCount.map { " HR sample count \($0)." } ?? " Add HR samples to calculate zone minutes."
            return snapshot(
                id: .heartRateZones,
                title: "HR zones",
                value: "\(Int(maxHR.value.rounded()))",
                unit: "max bpm",
                source: .calculated,
                confidence: maxHR.estimated ? .low : .medium,
                readiness: .betaEstimated,
                accuracySummary: maxHR.estimated ? "Age-estimated threshold" : "User-configured threshold",
                requirements: ["User max HR or age for estimated max HR", "Validated HR samples for zone minutes"],
                calibrationSummary: maxHR.estimated ? "Using age-estimated max HR; configure max HR to improve confidence." : "Using configured max HR.",
                lastUpdated: bodyProfile.updatedAt ?? summary.date,
                context: "Zone bands use 50-60, 60-70, 70-80, 80-90, and 90-100% of \(sourceText) max HR.\(sampleText)",
                symbol: "slider.horizontal.3"
            )
        }
        return snapshot(
            id: .heartRateZones,
            title: "HR zones",
            value: nil,
            unit: nil,
            source: .calculated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until profile threshold exists",
            requirements: ["Configured max HR or age", "Validated HR samples"],
            unavailableReason: "Needs max HR or an explicitly labeled zone setup before zone minutes are useful.",
            context: "Zone math is straightforward once validated HR windows and a user-specific zone model exist.",
            symbol: "slider.horizontal.3"
        )
    }

    private static func hrv(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        let source = sourceKind(for: summary.hrvSource ?? summary.source)
        return snapshot(
            id: .hrv,
            title: "HRV",
            value: summary.hrv.map { format($0, digits: 0) },
            unit: "ms",
            source: summary.hrv == nil ? .unavailable : source,
            confidence: summary.hrv == nil ? .blocked : (summary.hrvConfidence ?? .high),
            readiness: summary.hrv == nil ? .laterBlocked : .showNow,
            accuracySummary: summary.hrv == nil ? "Blocked until RR/HRV source exists" : "Calculated from clean RR intervals",
            requirements: ["Enough clean RR intervals from a validated source", "RMSSD preferred; SDNN fallback"],
            lastUpdated: summary.hrv == nil ? nil : summary.date,
            unavailableReason: summary.hrv == nil ? "Needs enough clean RR intervals from a validated source." : nil,
            context: "Calculated from valid RR intervals only when enough clean intervals exist. RMSSD is preferred for short-window recovery context; not estimated from BPM.",
            symbol: "waveform.path.ecg"
        )
    }

    private static func rawWristTemperature(summary: DailyHealthSummary, deviceState: WearableDeviceState, now: Date) -> WhoordanMetricSnapshot {
        let temperature = freshRawTemperature(summary: summary, deviceState: deviceState, now: now)
        let value = temperature.value
        return snapshot(
            id: .rawWristTemperature,
            title: "Raw wrist temp",
            value: value.map { format($0, digits: 1) },
            unit: "C",
            source: value == nil ? .unavailable : .direct,
            confidence: value == nil ? .blocked : .high,
            readiness: value == nil ? .laterBlocked : .showNow,
            accuracySummary: value == nil ? "Blocked until R10 temp exists" : "Direct raw R10 temperature",
            accuracyDetail: "Raw temperature field responded to warm/cool controlled tests. Baseline delta is a separate derived metric.",
            requirements: ["R10 raw wrist/contact temperature"],
            lastUpdated: value == nil ? nil : (temperature.timestamp ?? summary.date),
            unavailableReason: value == nil ? (temperature.stale ? "Latest raw wrist/contact temperature packet is stale; waiting for a fresh R10 temperature frame." : "Waiting for an R10 temperature frame or temperature event.") : nil,
            context: "Direct raw wrist/contact temperature from R10. This is not a body-core temperature or baseline skin-temp delta.",
            symbol: "thermometer.medium"
        )
    }

    private static func skinTemperatureDelta(
        summary: DailyHealthSummary,
        deviceState: WearableDeviceState,
        baselineProfile: SkinTemperatureBaselineProfile,
        now: Date
    ) -> WhoordanMetricSnapshot {
        let temperature = freshRawTemperature(summary: summary, deviceState: deviceState, now: now)
        let raw = temperature.value
        if let storedDelta = summary.bodyTemperatureDelta,
           !baselineProfile.hasActiveBaseline {
            return snapshot(
                id: .skinTemperatureDelta,
                title: "Skin temp delta",
                value: signed(storedDelta),
                unit: "C",
                source: .calculated,
                confidence: .low,
                readiness: .betaEstimated,
                accuracySummary: "Stored wearable delta",
                accuracyDetail: "Displayed from an existing local/device-derived baseline delta. New deltas still need raw temperature plus a personal baseline.",
                requirements: ["Stored wearable baseline delta, or direct raw wrist/contact temperature plus active personal baseline"],
                calibrationSummary: "Stored delta shown; active local baseline progress \(min(baselineProfile.eligibleDayCount, baselineProfile.requiredDayCount))/\(baselineProfile.requiredDayCount) eligible nights.",
                lastUpdated: summary.date,
                context: "Existing device-derived skin-temperature delta is visible as low confidence when the local baseline object is not active yet.",
                symbol: "thermometer.variable"
            )
        }
        if let raw,
           let baseline = baselineProfile.activeBaselineC,
           baselineProfile.hasActiveBaseline {
            let delta = summary.bodyTemperatureDelta ?? raw - baseline
            let progress = "\(min(baselineProfile.eligibleDayCount, baselineProfile.requiredDayCount))/\(baselineProfile.requiredDayCount)"
            let baselineKind = baselineProfile.isAutomatic ? "automatic private baseline" : "temporary personal baseline"
            return snapshot(
                id: .skinTemperatureDelta,
                title: "Skin temp delta",
                value: signed(delta),
                unit: "C",
                source: .calculated,
                confidence: .medium,
                readiness: .betaEstimated,
                accuracySummary: "Raw temp direct; baseline delta unmeasured",
                accuracyDetail: "The raw R10 temperature is confirmed, but the app-facing baseline delta still needs personal calibration.",
                requirements: ["Direct raw wrist/contact temperature", "Active personal skin-temperature baseline"],
                calibrationSummary: "Skin-temperature baseline progress \(progress) eligible nights.",
                lastUpdated: baselineProfile.updatedAt ?? temperature.timestamp ?? summary.date,
                context: "Calculated from raw wrist/contact temperature minus \(baselineKind). Baseline progress \(progress) eligible nights; confidence stays visible because this is not a diagnosis.",
                symbol: "thermometer.variable"
            )
        }
        return snapshot(
            id: .skinTemperatureDelta,
            title: "Skin temp delta",
            value: nil,
            unit: "C",
            source: .calculated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until baseline exists",
            requirements: ["Direct raw wrist/contact temperature", "Enough eligible baseline nights or a clearly marked temporary baseline"],
            calibrationSummary: "Skin-temperature baseline progress \(min(baselineProfile.eligibleDayCount, baselineProfile.requiredDayCount))/\(baselineProfile.requiredDayCount) eligible nights.",
            lastUpdated: raw == nil ? nil : (temperature.timestamp ?? summary.date),
            unavailableReason: raw == nil
                ? (temperature.stale ? "Latest raw wrist/contact temperature packet is stale; waiting for a fresh R10 temperature frame." : "Needs direct raw wrist/contact temperature and a personal baseline.")
                : "Needs enough personal baseline nights before showing a baseline delta.",
            context: "Whoordan shows raw wrist/contact temperature until a personal baseline exists.",
            symbol: "thermometer.variable"
        )
    }

    private static func sleepDuration(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        return snapshot(
            id: .sleepDuration,
            title: "Sleep",
            value: summary.sleepMinutes.map(duration),
            unit: nil,
            source: summary.sleepMinutes == nil ? .unavailable : sourceKind(for: summary.sleepSummary?.source ?? summary.source),
            confidence: summary.sleepMinutes == nil ? .blocked : (summary.sleepSummary?.confidence ?? .medium),
            readiness: summary.sleepMinutes == nil ? .laterBlocked : .showNow,
            accuracySummary: summary.sleepMinutes == nil ? "Blocked until sleep source exists" : "BLE-derived or source-labeled sleep duration",
            requirements: ["Measured, source-labeled, or BLE-derived sleep session"],
            lastUpdated: summary.sleepMinutes == nil ? nil : (summary.sleepSummary?.lastUpdated ?? summary.date),
            unavailableReason: summary.sleepMinutes == nil ? "Needs measured, source-labeled, or BLE-derived sleep." : nil,
            context: "Sleep duration can be shown from source-labeled sessions or low-confidence BLE-derived sleep windows.",
            symbol: "moon"
        )
    }

    private static func sleepPerformance(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        if let estimate = sleepPerformanceEstimate(summary: summary, recentSummaries: recentSummaries) {
            return snapshot(
                id: .sleepPerformance,
                title: "Sleep performance",
                value: "\(Int(estimate.value.rounded()))",
                unit: "%",
                source: .mlEstimated,
                confidence: estimate.confidence,
                readiness: .betaEstimated,
                accuracySummary: estimate.confidence == .high ? "Formula-only MAE ~11.1 pp" : "Low-confidence minimum-data estimate",
                accuracyDetail: estimate.confidence == .high
                    ? "Current shipped formula-only validation for the sleep/need ratio: 1,197 sleep rows, MAE 11.14 percentage points, R2 0.638. Residual-model experiments are not shipped in Swift."
                    : "Shows when sleep duration and sleep-need inputs exist; optional efficiency, consistency, and HRV/RHR stress context are reported separately instead of inflating the primary performance ratio.",
                requirements: [
                    "Source-labeled main sleep",
                    "Sleep-need value or estimate",
                    "Optional sleep efficiency",
                    "Optional rolling sleep consistency",
                    "Optional HRV/RHR personal baseline for sleep-stress component"
                ],
                calibrationSummary: "Sleep-need data days \(estimate.sleepNeedNightCount); HRV/RHR baseline days \(estimate.baselineDayCount); formula weight \(Int((estimate.componentWeight * 100).rounded()))%.",
                lastUpdated: summary.sleepSummary?.lastUpdated ?? summary.date,
                context: "Beta estimate from measured sleep divided by sleep need. Missing optional components lower confidence instead of hiding the metric.",
                symbol: "bed.double"
            )
        }
        return snapshot(
            id: .sleepPerformance,
            title: "Sleep performance",
            value: nil,
            unit: "%",
            source: .mlEstimated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until sleep and need exist",
            accuracyDetail: "Formula-only validation applies only when component inputs are present; residual-model experiments are not shipped in Swift.",
            requirements: [
                "Measured, source-labeled, or BLE-derived sleep duration",
                "Sleep-need value or enough source-labeled sleep to estimate need"
            ],
            lastUpdated: summary.sleepSummary?.lastUpdated,
            unavailableReason: "Needs sleep duration and sleep-need data before showing a sleep-performance score.",
            context: "Whoordan shows low-confidence sleep performance once minimum sleep inputs exist; it does not fill missing optional components with neutral placeholders.",
            symbol: "bed.double"
        )
    }

    private static func sleepNeed(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        if let estimate = sleepNeedEstimate(summary: summary, recentSummaries: recentSummaries) {
            return snapshot(
                id: .sleepNeed,
                title: "Sleep need",
                value: duration(estimate.minutes),
                unit: nil,
                source: .calculated,
                confidence: estimate.confidence,
                readiness: .betaEstimated,
                accuracySummary: "Low confidence; formula MAE ~60 min",
                accuracyDetail: "Current shipped formula-only validation: 1,197 sleep rows, MAE 60.08 minutes, R2 -0.944. Planning context only.",
                requirements: ["Stored sleep need or at least one source-labeled main sleep", "Prior sleep debt when available", "Prior day strain when available"],
                calibrationSummary: "Sleep-need data days \(estimate.nightCount).",
                lastUpdated: summary.sleepSummary?.lastUpdated ?? summary.date,
                context: "Beta sleep target from stored sleep-need data or source-labeled main sleep history. Prior debt and prior-day strain can adjust the target when available. Planning context only.",
                symbol: "clock.badge.questionmark"
            )
        }
        return snapshot(
            id: .sleepNeed,
            title: "Sleep need",
            value: nil,
            unit: nil,
            source: .calculated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until baseline exists",
            requirements: ["Stored sleep need or at least one source-labeled main sleep session"],
            lastUpdated: summary.sleepSummary?.lastUpdated,
            unavailableReason: "Needs a main sleep from the wearable or a source-labeled import before showing sleep need.",
            context: "Whoordan waits for real sleep context before promoting sleep need.",
            symbol: "clock.badge.questionmark"
        )
    }

    private static func sleepDebt(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        if let storedDebt = summary.sleepDebtMinutes {
            let estimate = sleepNeedEstimate(summary: summary, recentSummaries: recentSummaries)
            return snapshot(
                id: .sleepDebt,
                title: "Sleep debt",
                value: duration(storedDebt),
                unit: nil,
                source: .calculated,
                confidence: estimate?.confidence ?? .low,
                readiness: .betaEstimated,
                accuracySummary: "Stored wearable or local estimate",
                accuracyDetail: "Shown from existing local/device-derived sleep-debt data. New estimates use measured sleep minus sleep need.",
                requirements: ["Stored sleep-debt value, or measured main sleep plus sleep-need estimate"],
                calibrationSummary: "Sleep-need data days \(estimate?.nightCount ?? 0).",
                lastUpdated: summary.sleepSummary?.lastUpdated ?? summary.date,
                context: "Today-only beta debt from stored value or estimated sleep need minus measured main sleep; carryover debt is not claimed yet.",
                symbol: "hourglass"
            )
        }
        if let estimate = sleepNeedEstimate(summary: summary, recentSummaries: recentSummaries),
           let sleep = summary.sleepMinutes {
            let napCredit = min(summary.sleepSummary?.naps.reduce(0) { $0 + $1.asleepMinutes } ?? 0, 180)
            let debt = max(0, estimate.minutes - sleep - napCredit)
            return snapshot(
                id: .sleepDebt,
                title: "Sleep debt",
                value: duration(debt),
                unit: nil,
                source: .calculated,
                confidence: estimate.confidence,
                readiness: .betaEstimated,
                accuracySummary: "Low confidence; formula MAE ~102 min",
                accuracyDetail: "Current shipped formula-only validation: 1,197 sleep rows, MAE 102.22 minutes, R2 -15.919. Residual-model experiments improved MAE but are not shipped in Swift.",
                requirements: ["Measured main sleep", "Sleep-need estimate", "Nap credit when available"],
                calibrationSummary: "Sleep-need data days \(estimate.nightCount).",
                lastUpdated: summary.sleepSummary?.lastUpdated ?? summary.date,
                context: "Today-only beta debt from estimated sleep need minus measured main sleep and same-day nap credit; carryover debt is used only when available from prior local summaries.",
                symbol: "hourglass"
            )
        }
        return snapshot(
            id: .sleepDebt,
            title: "Sleep debt",
            value: nil,
            unit: nil,
            source: .calculated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until sleep need exists",
            requirements: ["Measured main sleep", "Stored sleep need or at least one source-labeled main sleep session"],
            lastUpdated: summary.sleepSummary?.lastUpdated,
            unavailableReason: "Needs measured sleep plus stored sleep-need data or enough sleep history to estimate need.",
            context: "Carryover sleep debt remains a low-confidence estimate until the app has validated multi-day history.",
            symbol: "hourglass"
        )
    }

    private static func sleepConsistency(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        let estimate = sleepConsistencyEstimate(summary: summary, recentSummaries: recentSummaries)
        return snapshot(
            id: .sleepConsistency,
            title: "Sleep consistency",
            value: estimate.map { "\(Int($0.value.rounded()))" },
            unit: nil,
            source: .calculated,
            confidence: estimate?.confidence ?? .blocked,
            readiness: estimate == nil ? .laterBlocked : .betaEstimated,
            accuracySummary: estimate == nil ? "Blocked until rolling window exists" : "Formula-only MAE ~16.8 pp",
            accuracyDetail: "Current shipped formula-only validation: 990 sleep rows, MAE 16.78 points, R2 -0.336. Residual-model experiments are not shipped in Swift.",
            requirements: ["At least two source-labeled or BLE-derived main sleeps in the rolling 7-day window"],
            lastUpdated: estimate == nil ? nil : summary.date,
            unavailableReason: estimate == nil ? "Needs at least two source-labeled or BLE-derived main sleep sessions in a rolling 7-day window." : nil,
            context: "Directional rolling 7-day bed/wake timing score from source-labeled sleep sessions; wellness context only.",
            symbol: "calendar"
        )
    }

    private static func sleepStages(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        let hasStages = !(summary.sleepSummary?.stageTotals.isEmpty ?? true)
        let source = sourceKind(for: summary.sleepSummary?.source ?? summary.source)
        let isEstimated = source == .mlEstimated
        return snapshot(
            id: .sleepStages,
            title: "Sleep stages",
            value: hasStages ? (isEstimated ? "Estimated" : "Labeled") : nil,
            unit: nil,
            source: hasStages ? source : .unavailable,
            confidence: hasStages ? (summary.sleepSummary?.confidence ?? .medium) : .blocked,
            readiness: hasStages ? (isEstimated ? .betaEstimated : .showNow) : .laterBlocked,
            accuracySummary: hasStages
                ? (isEstimated ? "Low-confidence BLE-derived stages" : "Source-labeled stages")
                : "Blocked until stages exist",
            requirements: ["Source-labeled or BLE-derived sleep-stage segments"],
            lastUpdated: hasStages ? summary.sleepSummary?.lastUpdated : nil,
            unavailableReason: hasStages ? nil : "Blocked unless stages are source-labeled or BLE-derived.",
            context: "BLE-derived stages are marked estimated and low confidence; they are not medical sleep staging.",
            symbol: "rectangle.stack"
        )
    }

    private static func restorativeSleepPercent(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        if let value = summary.sleepSummary?.restorativePercent {
            let isEstimated = sourceKind(for: summary.sleepSummary?.source ?? summary.source) == .mlEstimated
            return snapshot(
                id: .restorativeSleepPercent,
                title: "Restorative sleep",
                value: "\(Int(value.rounded()))",
                unit: "%",
                source: .calculated,
                confidence: summary.sleepSummary?.confidence ?? .medium,
                readiness: isEstimated ? .betaEstimated : .showNow,
                accuracySummary: isEstimated ? "Low-confidence BLE-derived stage estimate" : "Deterministic from available stage segments",
                requirements: ["Source-labeled or BLE-derived REM/deep sleep segments"],
                lastUpdated: summary.sleepSummary?.lastUpdated ?? summary.date,
                context: "Calculated from available REM/deep stage segments; BLE-derived segments stay low confidence.",
                symbol: "sparkles"
            )
        }
        return blockedMetric(
            id: .restorativeSleepPercent,
            title: "Restorative sleep",
            unit: "%",
            reason: "Blocked unless sleep stages are source-labeled or BLE-derived.",
            context: "Calculated only from available REM/deep stage segments; BLE-derived segments stay low confidence.",
            symbol: "sparkles"
        )
    }

    private static func restorativeSleepHours(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        if let minutes = summary.sleepSummary?.restorativeMinutes {
            let isEstimated = sourceKind(for: summary.sleepSummary?.source ?? summary.source) == .mlEstimated
            return snapshot(
                id: .restorativeSleepHours,
                title: "Restorative hours",
                value: duration(minutes),
                unit: nil,
                source: .calculated,
                confidence: summary.sleepSummary?.confidence ?? .medium,
                readiness: isEstimated ? .betaEstimated : .showNow,
                accuracySummary: isEstimated ? "Low-confidence BLE-derived stage estimate" : "Deterministic from available stage segments",
                requirements: ["Source-labeled or BLE-derived REM/deep sleep segments"],
                lastUpdated: summary.sleepSummary?.lastUpdated ?? summary.date,
                context: "REM plus deep sleep from available stage segments; BLE-derived segments stay low confidence.",
                symbol: "moon.zzz"
            )
        }
        return blockedMetric(
            id: .restorativeSleepHours,
            title: "Restorative hours",
            unit: nil,
            reason: "Blocked unless sleep stages are source-labeled or BLE-derived.",
            context: "Requires available deep/REM/restorative stage inputs; BLE-derived segments stay low confidence.",
            symbol: "moon.zzz"
        )
    }

    private static func recovery(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        if let estimate = recoveryEstimate(summary: summary, recentSummaries: recentSummaries) {
            return snapshot(
                id: .recovery,
                title: "Recovery",
                value: format(estimate.value, digits: 0),
                unit: nil,
                source: .mlEstimated,
                confidence: estimate.confidence,
                readiness: .betaEstimated,
                accuracySummary: "Formula-only MAE ~21 pp",
                accuracyDetail: estimate.confidence == .low
                    ? "Minimum-data recovery estimate. Current shipped formula-only validation: 1,012 cycle rows, MAE 21.17 points, R2 0.039."
                    : "Current shipped formula-only validation: 1,012 cycle rows, MAE 21.17 points, R2 0.039. Directional only.",
                requirements: [
                    "At least one current recovery contributor",
                    "Personal baseline when using baseline-relative HRV, resting HR, or respiratory rate",
                    "Sleep duration plus sleep need when using sleep sufficiency"
                ],
                calibrationSummary: "Personal baseline days \(estimate.baselineDayCount).",
                lastUpdated: summary.date,
                context: "Directional readiness estimate from available source-labeled sleep, HRV/RHR, respiratory, SpO2, and temperature context. Missing contributors lower confidence instead of hiding the score.",
                symbol: "arrow.clockwise"
            )
        }
        return snapshot(
            id: .recovery,
            title: "Recovery",
            value: nil,
            unit: nil,
            source: .mlEstimated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until recovery input exists",
            accuracyDetail: "Formula-only validation applies only after baseline and current physiological inputs are present; residual-model experiments are not shipped in Swift.",
            requirements: [
                "Current sleep sufficiency, baseline-relative HRV/RHR, respiratory fit, SpO2, or skin-temp delta"
            ],
            calibrationSummary: "Not enough recovery contributors yet.",
            lastUpdated: nil,
            unavailableReason: "Needs at least one usable recovery contributor before showing recovery.",
            context: "Whoordan shows low-confidence recovery once minimum local inputs exist and never treats SpO2 alone as a recovery score.",
            symbol: "arrow.clockwise"
        )
    }

    private static func dayStrain(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> WhoordanMetricSnapshot {
        let fallback = fallbackDayStrain(summary: summary, bodyProfile: bodyProfile)
        let value = summary.strain?.value ?? fallback?.value
        let confidence = summary.strain?.confidence ?? fallback?.confidence ?? .blocked
        return snapshot(
            id: .dayStrain,
            title: "Day strain",
            value: value.map { format($0, digits: 1) },
            unit: "/21",
            source: .mlEstimated,
            confidence: confidence,
            readiness: value == nil ? .laterBlocked : .betaEstimated,
            accuracySummary: value == nil ? "Blocked until HR/activity exists" : "Formula-only MAE ~5.1 points",
            accuracyDetail: "Current shipped formula-only validation: 1,080 cycle rows, MAE 5.08 points, R2 -2.160. Residual-model experiments are not shipped in Swift.",
            requirements: ["Validated HR/activity windows, or source-labeled/BLE-derived movement inputs"],
            lastUpdated: value == nil ? nil : (summary.movement.lastUpdated ?? summary.date),
            unavailableReason: value == nil ? "Needs HR/activity windows or source-labeled/BLE-derived movement inputs." : nil,
            context: "Directional estimate from available strain score or movement-derived load. Low-confidence movement-only values stay labeled.",
            symbol: "figure.run"
        )
    }

    private static func activityStrain(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> WhoordanMetricSnapshot {
        let estimate = activityStrainEstimate(summary: summary, bodyProfile: bodyProfile)
        return snapshot(
            id: .activityStrain,
            title: "Activity strain",
            value: estimate.map { format($0.value, digits: 1) },
            unit: "/21",
            source: .mlEstimated,
            confidence: estimate?.confidence ?? .blocked,
            readiness: estimate == nil ? .laterBlocked : .betaEstimated,
            accuracySummary: estimate == nil ? "Blocked until activity exists" : "Formula-only MAE ~2.4 points",
            accuracyDetail: "Current shipped formula-only validation: 488 workout rows, MAE 2.44 points, R2 -0.511. Residual-model experiments are not shipped in Swift.",
            requirements: ["Source-labeled/BLE-derived workout duration, steps, active energy, or movement signal", "Heart-rate or zone context for stronger confidence"],
            lastUpdated: summary.movement.lastUpdated,
            unavailableReason: estimate == nil ? "Needs source-labeled/BLE-derived workout/activity duration, steps, or active energy." : nil,
            context: "Directional estimate. Step/energy-only activity strain stays low confidence instead of being hidden.",
            symbol: "figure.highintensity.intervaltraining"
        )
    }

    private static func workoutCalories(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> WhoordanMetricSnapshot {
        let estimate = activeEnergyEstimate(summary: summary, bodyProfile: bodyProfile)
        return snapshot(
            id: .workoutCalories,
            title: "Workout calories",
            value: estimate.map { format($0.value, digits: 0) },
            unit: "kcal",
            source: estimate?.source ?? sourceKind(for: summary.movement.source),
            confidence: estimate?.confidence ?? .blocked,
            readiness: estimate == nil ? .laterBlocked : .betaEstimated,
            accuracySummary: estimate == nil ? "Blocked until workout energy exists" : "Formula-only MAE ~200 kcal",
            accuracyDetail: "Current shipped formula-only validation: 489 workout rows, MAE 200.21 kcal, R2 -1.014. Residual-model experiments are not shipped in Swift.",
            requirements: ["Workout-scoped/source-labeled energy, or profile plus source-labeled/BLE-derived movement distance or steps"],
            lastUpdated: summary.movement.lastUpdated,
            unavailableReason: estimate == nil ? "Needs source-labeled workout energy, movement minutes, or profile plus movement-derived distance/steps." : nil,
            context: estimate?.context ?? "Directional workout-calorie estimate. Step/distance-derived values stay low confidence and are not medical energy-expenditure claims.",
            symbol: "flame"
        )
    }

    private static func dailyCalories(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> WhoordanMetricSnapshot {
        if let estimate = dailyEnergyEstimate(summary: summary, bodyProfile: bodyProfile) {
            return snapshot(
                id: .dailyCalories,
                title: "Daily calories",
                value: format(estimate.total, digits: 0),
                unit: "kcal",
                source: .calculated,
                confidence: estimate.confidence,
                readiness: .betaEstimated,
                accuracySummary: "Low confidence; formula MAE ~414 kcal",
                accuracyDetail: "Current shipped formula-only validation: 1,080 cycle rows, MAE 414.39 kcal, R2 -0.119. Treat as a rough estimate only.",
                requirements: estimate.requirements,
                calibrationSummary: estimate.calibrationSummary,
                lastUpdated: maxDate(summary.movement.lastUpdated, bodyProfile.updatedAt) ?? summary.date,
                context: estimate.context,
                symbol: "flame"
            )
        }
        return snapshot(
            id: .dailyCalories,
            title: "Daily calories",
            value: nil,
            unit: "kcal",
            source: .calculated,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until profile and activity exist",
            requirements: ["Age", "Biological sex", "Height", "Weight", "Source-labeled active energy, distance, or steps"],
            lastUpdated: summary.movement.lastUpdated,
            unavailableReason: "Add age, biological sex, height, and weight before Whoordan estimates total daily calories.",
            context: "Total daily calories use profile-based resting energy plus source-labeled or distance-derived activity energy.",
            symbol: "flame"
        )
    }

    private static func steps(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        let isWhoordanEstimate = summary.movement.source == .whoordanEstimate
        return snapshot(
            id: .steps,
            title: "Steps",
            value: summary.movement.steps.map { "\($0)" },
            unit: "steps",
            source: summary.movement.steps == nil ? .unavailable : sourceKind(for: summary.movement.source),
            confidence: summary.movement.steps == nil ? .blocked : summary.movement.confidence,
            readiness: summary.movement.steps == nil ? .laterBlocked : (isWhoordanEstimate ? .betaEstimated : .showNow),
            accuracySummary: summary.movement.steps == nil
                ? "Blocked until step source exists"
                : (isWhoordanEstimate ? "Low-confidence R10 IMU estimate" : "Source-labeled steps"),
            accuracyDetail: isWhoordanEstimate
                ? "R10 steps use a wrist vector-magnitude recurrent-peak detector. Local JSONL proves motion-sensitive IMU frames, but local Whoordan R10 step accuracy still needs labeled step ground truth."
                : nil,
            requirements: ["Source-labeled steps or recurrent R10 accelerometer vector-magnitude peaks"],
            lastUpdated: summary.movement.lastUpdated,
            unavailableReason: summary.movement.steps == nil ? "Needs source-labeled steps or enough R10 accelerometer/gyro motion for the BLE-derived step estimator." : nil,
            context: isWhoordanEstimate
                ? "Steps are calculated from recurrent R10 IMU peaks and stay estimated until local labeled-step validation exists."
                : "Steps can show from source-labeled samples or low-confidence R10 IMU-derived estimates.",
            symbol: "shoeprints.fill"
        )
    }

    private static func stress(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        if let estimate = stressEstimate(summary: summary, recentSummaries: recentSummaries) {
            return snapshot(
                id: .stress,
                title: "Stress",
                value: format(estimate.value, digits: 1),
                unit: "/3",
                source: .calculated,
                confidence: estimate.confidence,
                readiness: .betaEstimated,
                accuracySummary: "Not proprietary-label rated",
                accuracyDetail: "Stress is an original Whoordan wellness-load formula. Minimum-data estimates are shown at low confidence.",
                requirements: ["At least one current wellness-load component; personal baseline improves HRV/RHR/respiratory components"],
                calibrationSummary: "Personal baseline days \(estimate.baselineDayCount).",
                lastUpdated: summary.date,
                context: "Wellness load estimate from available personal-baseline HRV/RHR, sleep sufficiency, day strain, respiratory fit, and temperature deviation. Not a medical stress score.",
                symbol: "brain.head.profile"
            )
        }
        return blockedMetric(
            id: .stress,
            title: "Stress",
            unit: "/3",
            reason: "Needs at least one usable wellness-load component before showing stress.",
            context: "Whoordan shows stress only as wellness load with clear source/confidence labels.",
            symbol: "brain.head.profile"
        )
    }

    private static func respiratoryRate(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        let source = summary.respiratoryRateSource ?? summary.source
        let isEstimated = source == .whoordanEstimate
        return snapshot(
            id: .respiratoryRate,
            title: "Respiratory rate",
            value: summary.respiratoryRate.map { format($0, digits: 1) },
            unit: "br/min",
            source: summary.respiratoryRate == nil ? .unavailable : sourceKind(for: source),
            confidence: summary.respiratoryRate == nil ? .blocked : (summary.respiratoryRateConfidence ?? .medium),
            readiness: summary.respiratoryRate == nil ? .laterBlocked : (isEstimated ? .betaEstimated : .showNow),
            accuracySummary: summary.respiratoryRate == nil
                ? "Blocked until measured/validated"
                : (isEstimated ? "Low-confidence RR-interval estimate" : "Source-labeled RR"),
            requirements: ["Measured respiratory rate or BLE-derived RR-interval respiratory estimator"],
            lastUpdated: summary.respiratoryRate == nil ? nil : summary.date,
            unavailableReason: summary.respiratoryRate == nil ? "Blocked unless measured or derived from a validated RR/PPG/IMU method." : nil,
            context: isEstimated
                ? "Calculated from enough clean RR intervals as a beta wellness estimate; not label-validated respiratory monitoring."
                : "Shown from measured/source-labeled respiratory rate when provided.",
            symbol: "lungs"
        )
    }

    private static func spo2(summary: DailyHealthSummary) -> WhoordanMetricSnapshot {
        if let oxygen = summary.oxygenSaturation {
            let source = sourceKind(for: summary.oxygenSaturationSource ?? summary.source)
            return snapshot(
                id: .spo2,
                title: "SpO2",
                value: format(oxygen, digits: 0),
                unit: "%",
                source: source,
                confidence: summary.oxygenSaturationConfidence ?? .medium,
                readiness: source == .mlEstimated ? .betaEstimated : .showNow,
                accuracySummary: source == .mlEstimated ? "Low-confidence R24 candidate" : "Source-labeled",
                accuracyDetail: source == .mlEstimated
                    ? "R24 candidate is shown as a BLE-derived wellness estimate, not a calibrated oximeter value."
                    : "Display uses measured/source-labeled oxygen saturation.",
                requirements: ["Measured/source-labeled oxygen saturation or BLE-derived R24 candidate"],
                lastUpdated: summary.date,
                context: "Shown from measured/source-labeled oxygen or an explicitly marked low-confidence BLE-derived R24 candidate.",
                symbol: "drop"
            )
        }
        return blockedMetric(
            id: .spo2,
            title: "SpO2",
            unit: "%",
            reason: "Blocked unless measured, source-labeled, or calculated from an R24 BLE candidate.",
            context: "R24-derived values must carry explicit device-only derivation metadata.",
            symbol: "drop"
        )
    }

    private static func vo2Max(summary: DailyHealthSummary, bodyProfile: BodyProfile, recentSummaries: [DailyHealthSummary]) -> WhoordanMetricSnapshot {
        if let measured = summary.vo2Max {
            return snapshot(
                id: .vo2Max,
                title: "VO2 max",
                value: format(measured, digits: 1),
                unit: "ml/kg/min",
                source: sourceKind(for: summary.vo2MaxSource ?? summary.source),
                confidence: summary.vo2MaxConfidence ?? .medium,
                readiness: .showNow,
                accuracySummary: "Source-labeled",
                requirements: ["Measured/source-labeled cardio fitness value"],
                lastUpdated: summary.date,
                context: "Source-labeled cardio fitness value; no internal submax protocol is implied.",
                symbol: "figure.run.circle"
            )
        }
        if let estimate = vo2Estimate(summary: summary, bodyProfile: bodyProfile, recentSummaries: recentSummaries) {
            return snapshot(
                id: .vo2Max,
                title: "VO2 max",
                value: format(estimate, digits: 1),
                unit: "ml/kg/min",
                source: .calculated,
                confidence: .low,
                readiness: .betaEstimated,
                accuracySummary: "Low confidence; not label-rated",
                accuracyDetail: "This estimate uses max HR and resting HR; demographics, HRV, and activity history improve interpretation but no longer hide the value.",
                requirements: ["Configured or age-estimated max HR", "Resting HR"],
                calibrationSummary: "Activity-context days \(recentSummariesWithActivity(recentSummaries).count).",
                lastUpdated: maxDate(summary.date, bodyProfile.updatedAt),
                context: "Low-confidence Uth-Sorensen style estimate from max HR and resting HR. Trend context only; no internal workout protocol is implied.",
                symbol: "figure.run.circle"
            )
        }
        return blockedMetric(
            id: .vo2Max,
            title: "VO2 max",
            unit: "ml/kg/min",
            reason: "Needs measured VO2 max, or configured/age-estimated max HR plus resting HR for a clearly labeled beta estimate.",
            context: "No internal workout protocol is used until validated.",
            symbol: "figure.run.circle"
        )
    }

    private static func blockedMetric(
        id: WhoordanMetricID,
        title: String,
        unit: String?,
        reason: String,
        context: String,
        symbol: String,
        requirements: [String]? = nil
    ) -> WhoordanMetricSnapshot {
        snapshot(
            id: id,
            title: title,
            value: nil,
            unit: unit,
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until validated",
            requirements: requirements ?? [reason],
            calibrationSummary: "Not enough validated input data yet.",
            unavailableReason: reason,
            context: context,
            symbol: symbol
        )
    }

    private static func snapshot(
        id: WhoordanMetricID,
        title: String,
        value: String?,
        unit: String?,
        source: WhoordanMetricSource,
        confidence: ConfidenceLevel,
        readiness: WhoordanMetricReadiness,
        accuracySummary: String? = nil,
        accuracyDetail: String? = nil,
        requirements: [String] = [],
        calibrationSummary: String? = nil,
        lastUpdated: Date? = nil,
        unavailableReason: String? = nil,
        context: String,
        symbol: String
    ) -> WhoordanMetricSnapshot {
        WhoordanMetricSnapshot(
            id: id,
            title: title,
            value: value,
            unit: unit,
            source: source,
            confidence: confidence,
            readiness: readiness,
            accuracySummary: accuracySummary,
            accuracyDetail: accuracyDetail,
            requirements: requirements,
            calibrationSummary: calibrationSummary,
            lastUpdated: lastUpdated,
            unavailableReason: unavailableReason,
            context: context,
            symbol: symbol
        )
    }

    private static func sourceKind(for source: DataSource?) -> WhoordanMetricSource {
        switch source {
        case .wearableBLE:
            return .direct
        case .legacyWearableDeviceExport:
            return .legacyWearable
        case .appleHealth, .cloudImport:
            return .imported
        case .localManual:
            return .imported
        case .whoordanEstimate:
            return .mlEstimated
        case .syntheticFixture:
            return .imported
        case nil:
            return .unavailable
        }
    }

    private static func format(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    private static func signed(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }

    private static func duration(_ minutes: Double) -> String {
        let totalMinutes = Int(max(0, minutes).rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return "\(hours)h \(mins)m"
    }

    private struct SleepNeedEstimate {
        let minutes: Double
        let confidence: ConfidenceLevel
        let nightCount: Int
    }

    private struct SleepPerformanceEstimate {
        let value: Double
        let confidence: ConfidenceLevel
        let sleepNeedNightCount: Int
        let baselineDayCount: Int
        let componentWeight: Double
    }

    private struct SleepConsistencyEstimate {
        let value: Double
        let confidence: ConfidenceLevel
        let nightCount: Int
    }

    private struct PersonalBaselineStats {
        static let minimumBaselineDays = 5

        let hrv: Double?
        let restingHeartRate: Double?
        let respiratoryRate: Double?
        let hrvCount: Int
        let restingHeartRateCount: Int
        let respiratoryRateCount: Int

        var coreDayCount: Int {
            min(hrvCount, restingHeartRateCount)
        }
    }

    private struct RecoveryEstimate {
        let value: Double
        let confidence: ConfidenceLevel
        let baselineDayCount: Int
    }

    private struct StressEstimate {
        let value: Double
        let confidence: ConfidenceLevel
        let baselineDayCount: Int
    }

    private struct DailyEnergyEstimate {
        let total: Double
        let confidence: ConfidenceLevel
        let context: String
        let requirements: [String]
        let calibrationSummary: String
    }

    private struct ActivityStrainEstimate {
        let value: Double
        let confidence: ConfidenceLevel
    }

    private struct ActiveEnergyEstimate {
        let value: Double
        let confidence: ConfidenceLevel
        let source: WhoordanMetricSource
        let context: String
    }

    private static func sleepNeedEstimate(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary] = []) -> SleepNeedEstimate? {
        if let storedNeed = summary.sleepNeedMinutes {
            let calculatedNeedDays = uniqueSummariesByDay([summary] + recentSummaries)
                .filter { $0.sleepNeedMinutes != nil }
                .count
            return SleepNeedEstimate(
                minutes: storedNeed,
                confidence: calculatedNeedDays >= 3 ? .directional : .low,
                nightCount: calculatedNeedDays
            )
        }
        let mainSleeps = sourceLabeledMainSleeps(summary: summary, recentSummaries: recentSummaries)
        guard mainSleeps.count >= 1 else { return nil }
        let previous = previousSummary(before: summary.date, in: recentSummaries)
        let priorDebt = min(max(previous?.sleepDebtMinutes ?? 0, 0), 300)
        let priorStrain = min(max(previous?.strain?.value ?? 0, 0), 21)
        let personalBase: Double
        if mainSleeps.count >= 7, let medianSleep = median(mainSleeps.suffix(14).map(\.asleepMinutes)) {
            personalBase = clamp(medianSleep + 30, 420, 540)
        } else {
            personalBase = 480
        }
        let estimate = clamp(personalBase + (0.20 * priorDebt) + (2.0 * priorStrain), 420, 600)
        return SleepNeedEstimate(minutes: estimate, confidence: mainSleeps.count >= 7 ? .directional : .low, nightCount: mainSleeps.count)
    }

    private static func dailyEnergyEstimate(
        summary: DailyHealthSummary,
        bodyProfile: BodyProfile
    ) -> DailyEnergyEstimate? {
        guard let resting = bodyProfile.bmrKilocaloriesPerDay() else { return nil }
        if let active = summary.movement.activeEnergyKilocalories {
            return DailyEnergyEstimate(
                total: max(0, resting + active),
                confidence: .directional,
                context: "Mifflin-St Jeor resting energy from local profile plus source-labeled active energy. Wellness estimate only.",
                requirements: ["Age", "Biological sex", "Height", "Weight", "Source-labeled active energy"],
                calibrationSummary: "Complete body profile plus source-labeled active energy."
            )
        }
        if let heartRateActive = heartRateReserveActiveCalories(summary: summary, bodyProfile: bodyProfile) {
            return DailyEnergyEstimate(
                total: max(0, resting + heartRateActive),
                confidence: summary.heartRateSampleCount.map { $0 >= 60 } == true ? .directional : .low,
                context: "Mifflin-St Jeor resting energy plus a heart-rate reserve active-energy estimate from direct HR coverage. Wellness estimate only.",
                requirements: ["Age", "Biological sex", "Height", "Weight", "Average HR", "Resting HR or default baseline", "Configured or age-estimated max HR"],
                calibrationSummary: "Complete body profile plus \(summary.heartRateSampleCount ?? 0) direct HR samples."
            )
        }
        if let weight = bodyProfile.weightKilograms,
           let distanceMeters = summary.movement.walkingRunningDistanceMeters
                ?? summary.movement.steps.flatMap({ bodyProfile.estimatedDistanceMeters(fromSteps: $0) }) {
            let active = max(0, 0.53 * weight * (distanceMeters / 1_000))
            return DailyEnergyEstimate(
                total: max(0, resting + active),
                confidence: .low,
                context: "Mifflin-St Jeor resting energy plus a low-confidence walking-distance activity estimate from profile and movement data.",
                requirements: ["Age", "Biological sex", "Height", "Weight", "Source-labeled distance or steps"],
                calibrationSummary: "Complete body profile plus movement-derived distance."
            )
        }
        return nil
    }

    private static func fallbackDayStrain(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> ActivityStrainEstimate? {
        let inferredActiveMinutes = summary.movement.movementMinutes
            ?? summary.heartRateCoverageMinutes.map { min(max($0, 0), 1_440) }
            ?? 0
        if let score = WhoordanScoringService().strain(inputs: StrainInputs(
            activeMinutes: inferredActiveMinutes,
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            configuredMaxHeartRate: bodyProfile.preferredMaxHeartRate()?.value,
            zoneMinutes: [:],
            restingHeartRate: summary.restingHeartRate,
            steps: summary.movement.steps,
            stepGoal: summary.movement.goal,
            activeEnergyKilocalories: summary.movement.activeEnergyKilocalories,
            movementConfidence: summary.movement.confidence
        )) {
            return ActivityStrainEstimate(value: score.value, confidence: score.confidence)
        }
        return nil
    }

    private static func activityStrainEstimate(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> ActivityStrainEstimate? {
        guard summary.movement.confidence != .unavailable else { return nil }
        if let movementMinutes = summary.movement.movementMinutes, movementMinutes > 0 {
            if let averageHeartRate = summary.averageHeartRate,
               let maxHeartRate = bodyProfile.preferredMaxHeartRate()?.value ?? summary.maxHeartRate {
                let restingHeartRate = clamp(summary.restingHeartRate ?? 60, 35, 100)
                let reserve = clamp((averageHeartRate - restingHeartRate) / max(maxHeartRate - restingHeartRate, 1), 0, 1)
                let load = movementMinutes * pow(reserve, 1.6) * 5.0
                if load > 0 {
                    return ActivityStrainEstimate(value: clamp(21 * (1 - exp(-load / 120)), 0, 21), confidence: .directional)
                }
            }
            return ActivityStrainEstimate(value: clamp(movementMinutes / 6.0, 0, 21), confidence: .directional)
        }
        if let activeEnergy = summary.movement.activeEnergyKilocalories, activeEnergy > 0 {
            return ActivityStrainEstimate(value: clamp(activeEnergy / 33.0, 0, 21), confidence: .low)
        }
        if let steps = summary.movement.steps, steps > 0 {
            let goal = max(summary.movement.goal, 1)
            return ActivityStrainEstimate(
                value: clamp((Double(steps) / Double(goal)) * 16, 0, 21),
                confidence: .low
            )
        }
        return nil
    }

    private static func activeEnergyEstimate(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> ActiveEnergyEstimate? {
        if let activeEnergy = summary.movement.activeEnergyKilocalories {
            return ActiveEnergyEstimate(
                value: max(0, activeEnergy),
                confidence: .directional,
                source: sourceKind(for: summary.movement.source),
                context: "Source-labeled active energy displayed with device-only source policy."
            )
        }
        if let duration = summary.movement.movementMinutes,
           let calories = keytelCalories(summary: summary, bodyProfile: bodyProfile, durationMinutes: duration) {
            return ActiveEnergyEstimate(
                value: calories,
                confidence: summary.heartRateSampleCount.map { $0 >= 12 } == true ? .directional : .low,
                source: .mlEstimated,
                context: "Keytel-style heart-rate calorie estimate from average HR, duration, age, sex, and weight. Wellness estimate only."
            )
        }
        if let weight = bodyProfile.weightKilograms,
           let distanceMeters = summary.movement.walkingRunningDistanceMeters
                ?? summary.movement.steps.flatMap({ bodyProfile.estimatedDistanceMeters(fromSteps: $0) }) {
            let active = max(0, 0.53 * weight * (distanceMeters / 1_000))
            return ActiveEnergyEstimate(
                value: active,
                confidence: .low,
                source: .mlEstimated,
                context: "Low-confidence walking-distance calorie estimate from profile and movement-derived distance."
            )
        }
        if let movementMinutes = summary.movement.movementMinutes, movementMinutes > 0 {
            return ActiveEnergyEstimate(
                value: movementMinutes * 7,
                confidence: .low,
                source: .mlEstimated,
                context: "Low-confidence duration fallback because heart-rate calorie inputs are incomplete."
            )
        }
        return nil
    }

    private static func stressEstimate(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> StressEstimate? {
        let baselines = personalBaselines(for: summary, recentSummaries: recentSummaries)
        var weighted = 0.0
        var weight = 0.0
        var componentCount = 0

        func add(_ component: Double?, _ componentWeight: Double) {
            guard let component else { return }
            weighted += clamp(component, 0, 1) * componentWeight
            weight += componentWeight
            componentCount += 1
        }

        add(baselines.hrv.flatMap { baseline in summary.hrv.map { 1 - min($0 / baseline, 1.25) } }, 0.28)
        add(baselines.restingHeartRate.flatMap { baseline in summary.restingHeartRate.map { (($0 / baseline) - 1) * 2.4 } }, 0.20)
        if let sleep = summary.sleepMinutes,
           let need = sleepNeedEstimate(summary: summary, recentSummaries: recentSummaries)?.minutes,
           need > 0 {
            add(1 - min(sleep / need, 1.1), 0.18)
        }
        add(summary.strain.map { min($0.value / 21, 1) }, 0.14)
        add(baselines.respiratoryRate.flatMap { baseline in summary.respiratoryRate.map { abs($0 - baseline) / 4 } }, 0.10)
        add(summary.bodyTemperatureDelta.map { abs($0) / 1.2 }, 0.10)

        guard componentCount > 0, weight > 0 else { return nil }
        let value = clamp((weighted / weight) * 3, 0, 3)
        let confidence: ConfidenceLevel = baselines.coreDayCount >= 5 && componentCount >= 3 ? .directional : .low
        return StressEstimate(value: value, confidence: confidence, baselineDayCount: baselines.coreDayCount)
    }

    private static func vo2Estimate(summary: DailyHealthSummary, bodyProfile: BodyProfile, recentSummaries: [DailyHealthSummary]) -> Double? {
        guard let restingHeartRate = summary.restingHeartRate,
              restingHeartRate > 0,
              let maxHR = bodyProfile.preferredMaxHeartRate()?.value else {
            return nil
        }
        return clamp(15.3 * (maxHR / restingHeartRate), 10, 80)
    }

    private static func heartRateReserveActiveCalories(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> Double? {
        guard let averageHeartRate = summary.averageHeartRate,
              let weight = bodyProfile.weightKilograms,
              let maxHeartRate = bodyProfile.preferredMaxHeartRate()?.value else {
            return nil
        }
        let restingHeartRate = clamp(summary.restingHeartRate ?? 60, 35, 100)
        let reserve = clamp((averageHeartRate - restingHeartRate) / max(maxHeartRate - restingHeartRate, 1), 0, 1)
        guard let coverageMinutes = summary.heartRateCoverageMinutes,
              coverageMinutes > 0 else {
            return nil
        }
        let boundedCoverageMinutes = min(max(coverageMinutes, 0), 1_440)
        let coverageScale = clamp(boundedCoverageMinutes / 1_440, 0.10, 1)
        let active = 0.020 * weight * 1_440 * pow(reserve, 1.25) * coverageScale
        return active.isFinite && active > 0 ? active : nil
    }

    private static func keytelCalories(
        summary: DailyHealthSummary,
        bodyProfile: BodyProfile,
        durationMinutes: Double
    ) -> Double? {
        guard let averageHeartRate = summary.averageHeartRate,
              (40...230).contains(averageHeartRate),
              durationMinutes > 0,
              let weight = bodyProfile.weightKilograms,
              let age = bodyProfile.resolvedAgeYears(),
              bodyProfile.biologicalSex != .notSet else {
            return nil
        }
        let kcalPerMinute: Double
        switch bodyProfile.biologicalSex {
        case .female:
            kcalPerMinute = (-20.4022 + 0.4472 * averageHeartRate - 0.1263 * weight + 0.074 * Double(age)) / 4.184
        case .male:
            kcalPerMinute = (-55.0969 + 0.6309 * averageHeartRate + 0.1988 * weight + 0.2017 * Double(age)) / 4.184
        case .notSet:
            return nil
        }
        let calories = max(0, kcalPerMinute) * durationMinutes
        return calories.isFinite && calories > 0 ? calories : nil
    }

    private static func sleepPerformanceEstimate(
        summary: DailyHealthSummary,
        recentSummaries: [DailyHealthSummary]
    ) -> SleepPerformanceEstimate? {
        guard let sleep = summary.sleepMinutes,
              let need = sleepNeedEstimate(summary: summary, recentSummaries: recentSummaries),
              need.minutes > 0 else {
            return nil
        }
        let hoursVsNeeded = clamp((sleep / need.minutes) * 100, 0, 100)
        let baselines = personalBaselines(for: summary, recentSummaries: recentSummaries)
        let optionalComponentWeight = 0.45
            + (sleepConsistencyValue(summary: summary, recentSummaries: recentSummaries) == nil ? 0 : 0.20)
            + (summary.sleepSummary?.mainSleep?.efficiencyPercent == nil ? 0 : 0.20)
            + (sleepStressScore(summary: summary, recentSummaries: recentSummaries) == nil ? 0 : 0.15)
        let confidence: ConfidenceLevel
        if optionalComponentWeight >= 1.0, need.nightCount >= 3, baselines.coreDayCount >= 5 {
            confidence = .directional
        } else if optionalComponentWeight >= 0.65, need.nightCount >= 2 {
            confidence = .directional
        } else {
            confidence = .low
        }
        return SleepPerformanceEstimate(
            value: hoursVsNeeded,
            confidence: confidence,
            sleepNeedNightCount: need.nightCount,
            baselineDayCount: baselines.coreDayCount,
            componentWeight: optionalComponentWeight
        )
    }

    private static func sleepStressScore(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> Double? {
        let baselines = personalBaselines(for: summary, recentSummaries: recentSummaries)
        guard let hrv = summary.hrv,
              let hrvBaseline = baselines.hrv,
              let resting = summary.restingHeartRate,
              let restingBaseline = baselines.restingHeartRate else {
            return nil
        }
        let hrvScore = clamp(50 + ((hrv / hrvBaseline) - 1) * 80, 0, 100)
        let restingScore = clamp(50 + (1 - (resting / restingBaseline)) * 90, 0, 100)
        return clamp((hrvScore + restingScore) / 2, 0, 100)
    }

    private static func recoveryEstimate(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> RecoveryEstimate? {
        let baselines = personalBaselines(for: summary, recentSummaries: recentSummaries)
        let inputs = RecoveryInputs(
            hrv: summary.hrv,
            hrvBaseline: baselines.hrv,
            restingHeartRate: summary.restingHeartRate,
            restingHeartRateBaseline: baselines.restingHeartRate,
            sleepMinutes: summary.sleepMinutes,
            sleepNeedMinutes: sleepNeedEstimate(summary: summary, recentSummaries: recentSummaries)?.minutes,
            respiratoryRate: summary.respiratoryRate,
            respiratoryRateBaseline: baselines.respiratoryRate,
            temperatureDelta: summary.bodyTemperatureDelta,
            oxygenSaturation: summary.oxygenSaturation
        )
        guard let result = RecoveryExplainer.score(inputs: inputs) else { return nil }
        let contributorCount = RecoveryExplainer.contributors(inputs: inputs)
            .filter { $0.componentScore != nil }
            .count
        guard contributorCount > 0 else { return nil }
        return RecoveryEstimate(
            value: result.value,
            confidence: baselines.coreDayCount >= 14 && contributorCount >= 3 ? .directional : .low,
            baselineDayCount: baselines.coreDayCount
        )
    }

    private static func personalBaselines(
        for summary: DailyHealthSummary,
        recentSummaries: [DailyHealthSummary]
    ) -> PersonalBaselineStats {
        let currentDay = Calendar.current.startOfDay(for: summary.date)
        let prior = recentSummaries
            .filter { Calendar.current.startOfDay(for: $0.date) < currentDay }
            .sorted { $0.date < $1.date }
        let hrvValues: [Double] = prior.compactMap { summary -> Double? in
            guard summary.hrv != nil,
                  summary.hrvConfidence != .unavailable,
                  sourceKind(for: summary.hrvSource ?? summary.source) != .unavailable else {
                return nil
            }
            return summary.hrv
        }
        let restingValues: [Double] = prior.compactMap { summary -> Double? in
            guard summary.restingHeartRate != nil,
                  summary.restingHeartRateConfidence != .unavailable,
                  sourceKind(for: summary.restingHeartRateSource ?? summary.source) != .unavailable else {
                return nil
            }
            return summary.restingHeartRate
        }
        let respiratoryValues: [Double] = prior.compactMap { summary -> Double? in
            guard summary.respiratoryRate != nil,
                  summary.respiratoryRateConfidence != .unavailable,
                  sourceKind(for: summary.respiratoryRateSource ?? summary.source) != .unavailable else {
                return nil
            }
            return summary.respiratoryRate
        }
        return PersonalBaselineStats(
            hrv: hrvValues.count >= PersonalBaselineStats.minimumBaselineDays ? median(hrvValues.suffix(28)) : nil,
            restingHeartRate: restingValues.count >= PersonalBaselineStats.minimumBaselineDays ? median(restingValues.suffix(28)) : nil,
            respiratoryRate: respiratoryValues.count >= PersonalBaselineStats.minimumBaselineDays ? median(respiratoryValues.suffix(28)) : nil,
            hrvCount: hrvValues.count,
            restingHeartRateCount: restingValues.count,
            respiratoryRateCount: respiratoryValues.count
        )
    }

    private static func uniqueSummariesByDay(_ summaries: [DailyHealthSummary]) -> [DailyHealthSummary] {
        var byDay: [String: DailyHealthSummary] = [:]
        for summary in summaries.sorted(by: { $0.date < $1.date }) {
            byDay[LocalDayKey.make(for: summary.date)] = summary
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    private static func sourceLabeledMainSleeps(
        summary: DailyHealthSummary,
        recentSummaries: [DailyHealthSummary]
    ) -> [SleepSession] {
        let allSummaries = (recentSummaries + [summary]).sorted { $0.date < $1.date }
        var seen = Set<String>()
        let sessions = allSummaries.flatMap { summary in
            summary.sleepSummary?.sessions ?? []
        }
        let sourceLabeledSessions = sessions.filter { session in
            !session.isNap
                && session.confidence != .unavailable
                && sourceKind(for: session.source) != .unavailable
                && session.asleepMinutes > 0
                && session.inBedMinutes > 0
        }
        let sortedSessions = sourceLabeledSessions.sorted { lhs, rhs in
            lhs.start < rhs.start
        }
        return sortedSessions.filter { session in
            seen.insert(session.id).inserted
        }
    }

    private static func recentSummariesWithActivity(_ summaries: [DailyHealthSummary]) -> [DailyHealthSummary] {
        summaries.filter {
            $0.averageHeartRate != nil
                || $0.maxHeartRate != nil
                || $0.movement.steps != nil
                || $0.movement.activeEnergyKilocalories != nil
                || $0.movement.movementMinutes != nil
        }
    }

    private static func previousSummary(before date: Date, in summaries: [DailyHealthSummary]) -> DailyHealthSummary? {
        let currentDay = Calendar.current.startOfDay(for: date)
        return summaries
            .filter { Calendar.current.startOfDay(for: $0.date) < currentDay }
            .sorted { $0.date < $1.date }
            .last
    }

    private static func freshRawTemperature(
        summary: DailyHealthSummary,
        deviceState: WearableDeviceState,
        now: Date
    ) -> (value: Double?, timestamp: Date?, stale: Bool) {
        if let stored = summary.rawWristTemperatureC {
            return (stored, summary.date, false)
        }
        guard let live = deviceState.skinTemperatureC else {
            return (nil, nil, false)
        }
        let timestamp = deviceState.skinTemperatureAt ?? deviceState.lastPacketAt
        let fresh = isFresh(timestamp, now: now)
        return (fresh ? live : nil, timestamp, !fresh)
    }

    private static func isFresh(_ timestamp: Date?, now: Date) -> Bool {
        guard let timestamp else { return true }
        let age = now.timeIntervalSince(timestamp)
        return age >= -60 && age <= liveSignalFreshness
    }

    private static func median<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }

    private static func maxDate(_ left: Date?, _ right: Date?) -> Date? {
        switch (left, right) {
        case let (left?, right?):
            return max(left, right)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func sleepConsistencyValue(summary: DailyHealthSummary, recentSummaries: [DailyHealthSummary]) -> Double? {
        sleepConsistencyEstimate(summary: summary, recentSummaries: recentSummaries)?.value
    }

    private static func sleepConsistencyEstimate(
        summary: DailyHealthSummary,
        recentSummaries: [DailyHealthSummary]
    ) -> SleepConsistencyEstimate? {
        let sourceLabeledMainSleeps = sourceLabeledMainSleeps(summary: summary, recentSummaries: recentSummaries)
        guard sourceLabeledMainSleeps.count >= 2 else { return nil }

        let window = Array(sourceLabeledMainSleeps.suffix(7))
        let calendar = Calendar.current
        let startHours = window.map { localHour($0.start, calendar: calendar) }
        let wakeHours = window.map { localHour($0.end, calendar: calendar) }
        guard let startStd = circularStandardDeviationHours(startHours),
              let wakeStd = circularStandardDeviationHours(wakeHours) else {
            return nil
        }
        let value = min(max(100 - startStd * 9 - wakeStd * 7, 0), 100)
        return SleepConsistencyEstimate(
            value: value,
            confidence: sourceLabeledMainSleeps.count >= 4 ? .directional : .low,
            nightCount: sourceLabeledMainSleeps.count
        )
    }

    private static func localHour(_ date: Date, calendar: Calendar) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0) / 60
        let second = Double(components.second ?? 0) / 3_600
        let nanosecond = Double(components.nanosecond ?? 0) / 3_600_000_000_000
        return hour + minute + second + nanosecond
    }

    private static func circularStandardDeviationHours(_ hours: [Double]) -> Double? {
        guard hours.count >= 2 else { return nil }
        let angles = hours.map { (($0.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)) / 24 * 2 * Double.pi }
        let sinMean = angles.map(sin).reduce(0, +) / Double(angles.count)
        let cosMean = angles.map(cos).reduce(0, +) / Double(angles.count)
        let resultant = min(max(hypot(sinMean, cosMean), 0), 1)
        guard resultant > Double.ulpOfOne else { return 12 }
        let circularStdRadians = sqrt(max(-2 * log(resultant), 0))
        return circularStdRadians * 24 / (2 * Double.pi)
    }
}
