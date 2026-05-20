import Foundation

enum DeviceMetricSourcePolicy {
    static let queryableProductionSources: [DataSource] = [
        .wearableBLE,
        .legacyWearableDeviceExport,
        .whoordanEstimate
    ]

    static func isProductionMetricSample(_ sample: HealthSample) -> Bool {
        guard sample.confidence != .unavailable else { return false }
        guard hasUsableContactSignal(sample) else { return false }
        switch sample.type {
        case .wearableIMU, .wearablePPG:
            return false
        default:
            break
        }

        switch sample.source {
        case .wearableBLE:
            return true
        case .legacyWearableDeviceExport:
            return true
        case .whoordanEstimate:
            return sample.metadata["device_only_derivation"] == "true"
                && isKnownDeviceEstimate(sample)
        case .appleHealth, .localManual, .cloudImport, .syntheticFixture:
            return false
        }
    }

    static func productionSamples(from samples: [HealthSample]) -> [HealthSample] {
        samples.filter(isProductionMetricSample)
    }

    private static func isKnownDeviceEstimate(_ sample: HealthSample) -> Bool {
        switch sample.type {
        case .steps:
            return sample.metadata["metric_policy"] == "r10_imu_motion_step_estimate"
        case .sleepAnalysis:
            return sample.metadata["metric_policy"] == "r10_hr_imu_sleep_stage_estimate"
        case .respiratoryRate:
            return sample.metadata["metric_policy"] == "rr_interval_respiratory_rate_estimate"
        case .oxygenSaturation:
            return sample.metadata["metric_policy"] == "r24_candidate_ble_derived_spo2"
        default:
            return false
        }
    }

    private static func hasUsableContactSignal(_ sample: HealthSample) -> Bool {
        guard [
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .heartRateVariabilityRMSSD,
            .respiratoryRate
        ].contains(sample.type) else {
            return true
        }
        guard let contact = sample.metadata["contact_detected"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return true
        }
        return !["false", "0", "no", "off"].contains(contact)
    }
}

protocol ScoringServicing {
    func score(summary: DailyHealthSummary, bodyProfile: BodyProfile) -> DailyHealthSummary
    func recovery(inputs: RecoveryInputs) -> ScoreValue?
    func strain(inputs: StrainInputs) -> ScoreValue?
}

extension ScoringServicing {
    func score(summary: DailyHealthSummary) -> DailyHealthSummary {
        score(summary: summary, bodyProfile: BodyProfile())
    }
}

struct RecoveryInputs: Equatable {
    var hrv: Double?
    var hrvBaseline: Double?
    var restingHeartRate: Double?
    var restingHeartRateBaseline: Double?
    var sleepMinutes: Double?
    var sleepNeedMinutes: Double?
    var respiratoryRate: Double?
    var respiratoryRateBaseline: Double?
    var temperatureDelta: Double?
    var oxygenSaturation: Double? = nil
}

struct StrainInputs: Equatable {
    var activeMinutes: Double
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var configuredMaxHeartRate: Double?
    var zoneMinutes: [Int: Double]
    var restingHeartRate: Double? = nil
    var steps: Int? = nil
    var stepGoal: Int? = nil
    var activeEnergyKilocalories: Double? = nil
    var movementConfidence: ConfidenceLevel = .unavailable
    var muscularMinutes: Double? = nil
    var muscularActivitySourceConfidence: ConfidenceLevel = .unavailable
}

enum MovementAggregator {
    static func aggregate(samples: [HealthSample], day: Date, goal: Int = 10_000, calendar: Calendar = .current) -> MovementSummary {
        let daySamples = DeviceMetricSourcePolicy.productionSamples(from: deduplicated(samples))
            .filter { sampleOccurs($0, on: day, calendar: calendar) }
        let selectedSteps = selectedMetricSamples(daySamples, type: .steps)
        let selectedEnergy = selectedMetricSamples(daySamples, type: .activeEnergy)
        let selectedDistance = selectedMetricSamples(daySamples, type: .distanceWalkingRunning)
        let selectedWorkouts = selectedMetricSamples(daySamples, type: .workout)
        let steps = selectedSteps.samples.isEmpty ? nil : Int(selectedSteps.samples.reduce(0) { $0 + $1.value }.rounded())

        let activeEnergy = sum(selectedEnergy.samples)
        let distance = sum(selectedDistance.samples)
        let workoutMinutes = sum(selectedWorkouts.samples)
        let movementMinutes = workoutMinutes ?? activeEnergy.map { min(max($0 / 7.0, 0), 240) }
        let source = selectedSteps.source
            ?? selectedEnergy.source
            ?? selectedDistance.source
            ?? selectedWorkouts.source
            ?? preferredSource(for: daySamples)
        let confidence = confidenceForMovement(steps: steps, source: source, activeEnergy: activeEnergy, distance: distance)
        let lastUpdated = daySamples.map(\.startDate).max()

        return MovementSummary(
            steps: steps,
            goal: goal,
            activeEnergyKilocalories: activeEnergy,
            walkingRunningDistanceMeters: distance,
            movementMinutes: movementMinutes,
            source: source,
            confidence: confidence,
            lastUpdated: lastUpdated,
            trendDescription: nil
        )
    }

    static func movementContributionToStrain(_ movement: MovementSummary) -> Double? {
        guard movement.confidence != .unavailable else { return nil }
        var load = 0.0
        if let steps = movement.steps, movement.goal > 0 {
            load += min(Double(steps) / Double(movement.goal), 1.6) * 16
        }
        if let activeEnergy = movement.activeEnergyKilocalories {
            load += min(activeEnergy / 700, 1.5) * 10
        }
        if let movementMinutes = movement.movementMinutes {
            load += min(movementMinutes / 90, 1.6) * 8
        }
        return load > 0 ? load : nil
    }

    private static func deduplicated(_ samples: [HealthSample]) -> [HealthSample] {
        var seen = Set<String>()
        return samples.filter { sample in
            seen.insert(sample.dedupeID).inserted
        }
    }

    private static func selectedMetricSamples(_ samples: [HealthSample], type: HealthSampleType) -> (source: DataSource?, samples: [HealthSample]) {
        let typed = samples.filter {
            $0.type == type
                && $0.value >= 0
                && $0.confidence != .unavailable
                && DeviceMetricSourcePolicy.isProductionMetricSample($0)
        }
        guard let source = preferredSource(for: typed, allowedTypes: [type]) else {
            return (nil, [])
        }
        return (source, typed.filter { $0.source == source })
    }

    private static func sum(_ samples: [HealthSample]) -> Double? {
        let values = samples.filter { $0.value >= 0 }.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func preferredSource(
        for samples: [HealthSample],
        allowedTypes: [HealthSampleType] = [.steps, .activeEnergy, .distanceWalkingRunning, .workout]
    ) -> DataSource? {
        samples
            .filter {
                $0.confidence != .unavailable
                    && allowedTypes.contains($0.type)
                    && DeviceMetricSourcePolicy.isProductionMetricSample($0)
            }
            .sorted {
                if $0.source.deviceFirstRank != $1.source.deviceFirstRank {
                    return $0.source.deviceFirstRank < $1.source.deviceFirstRank
                }
                return $0.startDate > $1.startDate
            }
            .first?
            .source
    }

    private static func confidenceForMovement(steps: Int?, source: DataSource?, activeEnergy: Double?, distance: Double?) -> ConfidenceLevel {
        guard source != nil else { return .unavailable }
        if steps != nil || activeEnergy != nil || distance != nil {
            if source == .whoordanEstimate {
                return .low
            }
            return source == .wearableBLE ? .high : .directional
        }
        return .low
    }

    private static func sampleOccurs(_ sample: HealthSample, on day: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return calendar.isDate(sample.startDate, inSameDayAs: day)
        }
        guard let endDate = sample.endDate else {
            return sample.startDate >= dayStart && sample.startDate < nextDay
        }
        return sample.startDate < nextDay && endDate > dayStart
    }
}

enum SleepAggregator {
    private struct TimeRange {
        let start: Date
        let end: Date
    }

    private struct StageObservation {
        let sample: HealthSample
        let start: Date
        let end: Date
        let originalStage: SleepStage
        let heartRate: Double?
        let rmssd: Double?
        let sdnn: Double?
        let motionRange: Double?
        let gyroRange: Double?
    }

    private struct StageScoredRange {
        let stage: SleepStage
        let start: Date
        let end: Date
        let confidence: ConfidenceLevel
    }

    private static let minimumEstimatedSleepCoverageMinutes = 20.0
    private static let sleepWakeDayLookbackHours = 12

    static func aggregate(samples: [HealthSample], day: Date, calendar: Calendar = .current) -> SleepSummary {
        let dayStart = calendar.startOfDay(for: day)
        let productionSamples = DeviceMetricSourcePolicy.productionSamples(from: deduplicated(samples))
        let relevantSamples = productionSamples
            .filter { $0.type == .sleepAnalysis && $0.value > 0 }
            .filter { sampleOccurs($0, on: day, calendar: calendar) }
        let sourceCandidates = Dictionary(grouping: relevantSamples, by: \.source).compactMap { source, samples -> (source: DataSource, sessions: [SleepSession], score: Double)? in
            let sourceSamples = samples.sorted { $0.startDate < $1.startDate }
            let sessions = groupedSessions(from: sourceSamples, source: source, contextSamples: productionSamples)
                .filter { $0.end > dayStart }
            guard !sessions.isEmpty else { return nil }
            let longestMainSleep = sessions.filter { !$0.isNap }.map(\.asleepMinutes).max() ?? 0
            let totalAsleep = sessions.reduce(0) { $0 + $1.asleepMinutes }
            let coverage = longestMainSleep > 0 ? longestMainSleep : totalAsleep * 0.5
            let score = coverage * confidenceMultiplier(bestConfidence(in: sourceSamples))
                - Double(source.deviceFirstRank) * 3.0
            return (source, sessions, score)
        }
        guard let selected = sourceCandidates.max(by: { $0.score < $1.score }) else {
            return .empty()
        }
        let sessions = selected.sessions
        guard !sessions.isEmpty else {
            return .empty()
        }

        let mainSleep = sessions
            .filter { !$0.isNap }
            .max { $0.asleepMinutes < $1.asleepMinutes }
        let mainID = mainSleep?.id
        let naps = sessions.filter { $0.id != mainID && $0.isNap }
        return SleepSummary(
            mainSleep: mainSleep,
            naps: naps,
            sessions: sessions,
            source: selected.source,
            confidence: bestConfidence(in: relevantSamples.filter { $0.source == selected.source }),
            lastUpdated: sessions.map(\.end).max()
        )
    }

    private static func groupedSessions(
        from samples: [HealthSample],
        source: DataSource,
        contextSamples: [HealthSample]
    ) -> [SleepSession] {
        var groups: [[HealthSample]] = []
        for sample in samples {
            guard sampleEnd(sample) > sample.startDate else { continue }
            if let lastGroup = groups.indices.last,
               let lastEnd = groups[lastGroup].map(sampleEnd).max(),
               sample.startDate.timeIntervalSince(lastEnd) <= 90 * 60 {
                groups[lastGroup].append(sample)
            } else {
                groups.append([sample])
            }
        }

        return groups.compactMap { group in
            guard let start = group.map(\.startDate).min(),
                  let end = group.map(sampleEnd).max() else {
                return nil
            }
            let asleepMinutes = mergedDurationMinutes(
                ranges: group
                    .filter(isAsleep)
                    .map { TimeRange(start: $0.startDate, end: sampleEnd($0)) }
            )
            guard asleepMinutes > 0 else { return nil }
            if source == .whoordanEstimate,
               asleepMinutes < minimumEstimatedSleepCoverageMinutes {
                return nil
            }
            let inBedMinutes = max(
                asleepMinutes,
                mergedDurationMinutes(
                    ranges: group.map { TimeRange(start: $0.startDate, end: sampleEnd($0)) }
                )
            )
            let efficiency = inBedMinutes > 0 ? min(max((asleepMinutes / inBedMinutes) * 100, 0), 100) : nil
            let stageSegments = estimatedStageSegments(
                from: group,
                source: source,
                contextSamples: contextSamples,
                sessionStart: start,
                sessionEnd: end
            )
            return SleepSession(
                id: [
                    source.rawValue,
                    "sleep",
                    String(Int(start.timeIntervalSince1970)),
                    String(Int(end.timeIntervalSince1970))
                ].joined(separator: ":"),
                start: start,
                end: end,
                asleepMinutes: asleepMinutes,
                inBedMinutes: inBedMinutes,
                efficiencyPercent: efficiency,
                source: source,
                confidence: bestConfidence(in: group),
                stageSegments: stageSegments
            )
        }
    }

    private static func mergedDurationMinutes(ranges: [TimeRange]) -> Double {
        mergedRanges(ranges).reduce(0) { total, range in
            total + max(0, range.end.timeIntervalSince(range.start) / 60)
        }
    }

    private static func mergedRanges(_ ranges: [TimeRange]) -> [TimeRange] {
        let sorted = ranges
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard let first = sorted.first else { return [] }
        return sorted.dropFirst().reduce(into: [first]) { partial, range in
            guard let last = partial.last else {
                partial.append(range)
                return
            }
            if range.start <= last.end {
                partial[partial.count - 1] = TimeRange(start: last.start, end: max(last.end, range.end))
            } else {
                partial.append(range)
            }
        }
    }

    private static func preferredSource(for samples: [HealthSample]) -> DataSource? {
        samples
            .filter { $0.confidence != .unavailable }
            .filter { DeviceMetricSourcePolicy.isProductionMetricSample($0) }
            .sorted {
                if $0.source.deviceFirstRank != $1.source.deviceFirstRank {
                    return $0.source.deviceFirstRank < $1.source.deviceFirstRank
                }
                return $0.startDate > $1.startDate
            }
            .first?
            .source
    }

    private static func deduplicated(_ samples: [HealthSample]) -> [HealthSample] {
        var seen = Set<String>()
        return samples.filter { seen.insert($0.dedupeID).inserted }
    }

    private static func sampleOccurs(_ sample: HealthSample, on day: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return calendar.isDate(sample.startDate, inSameDayAs: day)
        }
        let sleepWindowStart = calendar.date(
            byAdding: .hour,
            value: -sleepWakeDayLookbackHours,
            to: dayStart
        ) ?? dayStart.addingTimeInterval(TimeInterval(-sleepWakeDayLookbackHours * 60 * 60))
        let endDate = sampleEnd(sample)
        return sample.startDate < nextDay && endDate > sleepWindowStart
    }

    private static func sampleEnd(_ sample: HealthSample) -> Date {
        sample.endDate ?? sample.startDate.addingTimeInterval(sample.value * 60)
    }

    private static func isAsleep(_ sample: HealthSample) -> Bool {
        guard let category = sample.metadata["sleep_category"] else { return true }
        return ["1", "3", "4", "5"].contains(category)
    }

    private static func stageSegment(from sample: HealthSample, source: DataSource) -> SleepStageSegment? {
        let end = sampleEnd(sample)
        let minutes = max(0, end.timeIntervalSince(sample.startDate) / 60)
        guard minutes > 0 else { return nil }
        let stage = sleepStage(for: sample)
        return SleepStageSegment(
            id: [
                source.rawValue,
                "stage",
                stage.rawValue,
                String(Int(sample.startDate.timeIntervalSince1970)),
                String(Int(end.timeIntervalSince1970))
            ].joined(separator: ":"),
            stage: stage,
            start: sample.startDate,
            end: end,
            minutes: minutes,
            source: source,
            confidence: sample.confidence
        )
    }

    private static func estimatedStageSegments(
        from samples: [HealthSample],
        source: DataSource,
        contextSamples: [HealthSample],
        sessionStart: Date,
        sessionEnd: Date
    ) -> [SleepStageSegment] {
        guard source == .whoordanEstimate else {
            return mergedStageSegments(from: samples, source: source)
        }

        let orderedSamples = samples.sorted { $0.startDate < $1.startDate }
        let heartRateSamples = contextSamples
            .filter { $0.type == .heartRate && $0.source == .wearableBLE }
            .sorted { $0.startDate < $1.startDate }
        let rmssdSamples = contextSamples
            .filter { $0.type == .heartRateVariabilityRMSSD && $0.source == .wearableBLE }
            .sorted { $0.startDate < $1.startDate }
        let sdnnSamples = contextSamples
            .filter { $0.type == .heartRateVariabilitySDNN && $0.source == .wearableBLE }
            .sorted { $0.startDate < $1.startDate }

        let observations = orderedSamples.compactMap { sample -> StageObservation? in
            let end = sampleEnd(sample)
            guard end > sample.startDate else { return nil }
            let center = sample.startDate.addingTimeInterval(end.timeIntervalSince(sample.startDate) / 2)
            return StageObservation(
                sample: sample,
                start: sample.startDate,
                end: end,
                originalStage: sleepStage(for: sample),
                heartRate: metadataDouble("heart_rate_bpm", in: sample)
                    ?? nearestValue(in: heartRateSamples, to: center, within: 90),
                rmssd: nearestValue(in: rmssdSamples, to: center, within: 5 * 60),
                sdnn: nearestValue(in: sdnnSamples, to: center, within: 5 * 60),
                motionRange: metadataDouble("sleep_motion_normalized_range", in: sample),
                gyroRange: metadataDouble("sleep_gyroscope_range", in: sample)
            )
        }

        let asleepObservations = observations.filter { isAsleep($0.sample) }
        let heartRates = asleepObservations.compactMap(\.heartRate)
        let requiredHeartRates = min(asleepObservations.count, max(8, asleepObservations.count / 3))
        guard asleepObservations.count >= Int(minimumEstimatedSleepCoverageMinutes),
              heartRates.count >= requiredHeartRates,
              let heartRateMedian = percentile(heartRates, fraction: 0.50),
              let heartRateLow = percentile(heartRates, fraction: 0.15),
              let heartRateHigh = percentile(heartRates, fraction: 0.85) else {
            return mergedStageSegments(from: samples, source: source)
        }

        let rmssdMedian = percentile(asleepObservations.compactMap(\.rmssd), fraction: 0.50)
        let sdnnMedian = percentile(asleepObservations.compactMap(\.sdnn), fraction: 0.50)
        let scoredRanges = observations.enumerated().map { index, observation in
            StageScoredRange(
                stage: contextualStage(
                    for: observation,
                    at: index,
                    observations: observations,
                    sessionStart: sessionStart,
                    sessionEnd: sessionEnd,
                    heartRateMedian: heartRateMedian,
                    heartRateLow: heartRateLow,
                    heartRateHigh: heartRateHigh,
                    rmssdMedian: rmssdMedian,
                    sdnnMedian: sdnnMedian
                ),
                start: observation.start,
                end: observation.end,
                confidence: .low
            )
        }

        return mergedStageRanges(scoredRanges, source: source)
    }

    private static func contextualStage(
        for observation: StageObservation,
        at index: Int,
        observations: [StageObservation],
        sessionStart: Date,
        sessionEnd: Date,
        heartRateMedian: Double,
        heartRateLow: Double,
        heartRateHigh: Double,
        rmssdMedian: Double?,
        sdnnMedian: Double?
    ) -> SleepStage {
        if observation.originalStage == .awake || observation.originalStage == .inBed {
            return observation.originalStage
        }
        guard let heartRate = observation.heartRate else {
            return observation.originalStage == .asleep ? .core : observation.originalStage
        }

        let sessionMinutes = max(sessionEnd.timeIntervalSince(sessionStart) / 60, 1)
        let elapsedMinutes = max(observation.start.timeIntervalSince(sessionStart) / 60, 0)
        let progress = clamp(elapsedMinutes / sessionMinutes, 0, 1)
        let motionRange = observation.motionRange ?? 0.04
        if motionRange > 0.20 || (observation.gyroRange ?? 0) > 700 {
            return .awake
        }

        let stillnessScore = clamp(1 - (motionRange / 0.12), 0, 1)
        let heartRateLowSpan = max(4, heartRateMedian - heartRateLow)
        let heartRateHighSpan = max(4, heartRateHigh - heartRateMedian)
        let heartRateLowScore = clamp((heartRateMedian - heartRate) / heartRateLowSpan, 0, 1)
        let heartRateHighScore = clamp((heartRate - heartRateMedian) / heartRateHighSpan, 0, 1)
        let heartRateCentrality = clamp(1 - (abs(heartRate - heartRateMedian) / max(6, heartRateMedian * 0.10)), 0, 1)
        let heartRateInstability = localHeartRateInstability(at: index, observations: observations, median: heartRateMedian)
        let earlyDeepPrior = clamp(1 - (progress / 0.55), 0, 1)
        let lateREMPrior = clamp((progress - 0.25) / 0.75, 0, 1)
        let remCyclePrior = remCycleScore(elapsedMinutes: elapsedMinutes)
        let rmssdHighScore = relativeHighScore(value: observation.rmssd, median: rmssdMedian, floor: 8)
        let sdnnHighScore = relativeHighScore(value: observation.sdnn, median: sdnnMedian, floor: 8)
        let hrvHighScore = max(rmssdHighScore, sdnnHighScore)

        var deepScore = (0.46 * heartRateLowScore)
            + (0.24 * stillnessScore)
            + (0.30 * earlyDeepPrior)
            - (0.10 * heartRateInstability)
        var remScore = (0.35 * remCyclePrior)
            + (0.20 * lateREMPrior)
            + (0.20 * heartRateHighScore)
            + (0.15 * heartRateInstability)
            + (0.10 * hrvHighScore)
        let coreScore = 0.42
            + (0.16 * heartRateCentrality)
            + (0.12 * (1 - earlyDeepPrior))
            + (0.08 * stillnessScore)

        if observation.originalStage == .deep {
            deepScore += 0.08
        } else if observation.originalStage == .rem {
            remScore += 0.08
        }

        if deepScore >= 0.55 && deepScore > remScore + 0.08 && deepScore >= coreScore {
            return .deep
        }
        if remScore >= 0.55 && remScore > deepScore + 0.05 && remScore >= coreScore - 0.02 {
            return .rem
        }
        return .core
    }

    private static func mergedStageRanges(_ ranges: [StageScoredRange], source: DataSource) -> [SleepStageSegment] {
        Dictionary(grouping: ranges, by: \.stage)
            .flatMap { stage, stageRanges in
                let confidence = bestConfidence(stageRanges.map(\.confidence))
                return mergedRanges(stageRanges.map { TimeRange(start: $0.start, end: $0.end) })
                    .map { range in
                        let minutes = max(0, range.end.timeIntervalSince(range.start) / 60)
                        return SleepStageSegment(
                            id: [
                                source.rawValue,
                                "stage",
                                stage.rawValue,
                                String(Int(range.start.timeIntervalSince1970)),
                                String(Int(range.end.timeIntervalSince1970))
                            ].joined(separator: ":"),
                            stage: stage,
                            start: range.start,
                            end: range.end,
                            minutes: minutes,
                            source: source,
                            confidence: confidence
                        )
                    }
            }
            .sorted { $0.start < $1.start }
    }

    private static func mergedStageSegments(from samples: [HealthSample], source: DataSource) -> [SleepStageSegment] {
        Dictionary(grouping: samples, by: sleepStage(for:))
            .flatMap { stage, stageSamples in
                let confidence = bestConfidence(in: stageSamples)
                return mergedRanges(stageSamples.map { TimeRange(start: $0.startDate, end: sampleEnd($0)) })
                    .map { range in
                        let minutes = max(0, range.end.timeIntervalSince(range.start) / 60)
                        return SleepStageSegment(
                            id: [
                                source.rawValue,
                                "stage",
                                stage.rawValue,
                                String(Int(range.start.timeIntervalSince1970)),
                                String(Int(range.end.timeIntervalSince1970))
                            ].joined(separator: ":"),
                            stage: stage,
                            start: range.start,
                            end: range.end,
                            minutes: minutes,
                            source: source,
                            confidence: confidence
                        )
                    }
            }
            .sorted { $0.start < $1.start }
    }

    private static func sleepStage(for sample: HealthSample) -> SleepStage {
        switch sample.metadata["sleep_category"] {
        case "0":
            return .inBed
        case "1", nil:
            return .asleep
        case "2":
            return .awake
        case "3":
            return .core
        case "4":
            return .deep
        case "5":
            return .rem
        default:
            return .unknown
        }
    }

    private static func bestConfidence(in samples: [HealthSample]) -> ConfidenceLevel {
        if samples.contains(where: { $0.confidence == .high }) { return .high }
        if samples.contains(where: { $0.confidence == .medium }) { return .medium }
        if samples.contains(where: { $0.confidence == .low }) { return .low }
        return .unavailable
    }

    private static func bestConfidence(_ levels: [ConfidenceLevel]) -> ConfidenceLevel {
        if levels.contains(.high) { return .high }
        if levels.contains(.medium) { return .medium }
        if levels.contains(.low) { return .low }
        return .unavailable
    }

    private static func confidenceMultiplier(_ confidence: ConfidenceLevel) -> Double {
        switch confidence {
        case .high:
            return 1.20
        case .medium:
            return 1.10
        case .directional:
            return 1.00
        case .low:
            return 0.85
        case .blocked, .unavailable:
            return 0
        }
    }

    private static func metadataDouble(_ key: String, in sample: HealthSample) -> Double? {
        guard let raw = sample.metadata[key] else { return nil }
        return Double(raw) ?? Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    private static func nearestValue(in samples: [HealthSample], to date: Date, within seconds: TimeInterval) -> Double? {
        samples
            .compactMap { sample -> (distance: TimeInterval, value: Double)? in
                let distance = abs(sample.startDate.timeIntervalSince(date))
                guard distance <= seconds else { return nil }
                return (distance, sample.value)
            }
            .min { $0.distance < $1.distance }?
            .value
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(max(Int((Double(sorted.count - 1) * fraction).rounded()), 0), sorted.count - 1)
        return sorted[index]
    }

    private static func localHeartRateInstability(
        at index: Int,
        observations: [StageObservation],
        median: Double
    ) -> Double {
        guard let heartRate = observations[index].heartRate else { return 0 }
        var deltas: [Double] = []
        if index > observations.startIndex, let previous = observations[index - 1].heartRate {
            deltas.append(abs(heartRate - previous))
        }
        let nextIndex = index + 1
        if nextIndex < observations.endIndex, let next = observations[nextIndex].heartRate {
            deltas.append(abs(heartRate - next))
        }
        guard let maxDelta = deltas.max() else { return 0 }
        return clamp(maxDelta / max(4, median * 0.08), 0, 1)
    }

    private static func remCycleScore(elapsedMinutes: Double) -> Double {
        guard elapsedMinutes >= 45 else { return 0 }
        let phase = elapsedMinutes.truncatingRemainder(dividingBy: 90) / 90
        return gaussian(phase, mean: 0.82, standardDeviation: 0.18)
    }

    private static func relativeHighScore(value: Double?, median: Double?, floor: Double) -> Double {
        guard let value, let median, median > 0 else { return 0 }
        return clamp((value - median) / max(floor, median * 0.25), 0, 1)
    }

    private static func gaussian(_ value: Double, mean: Double, standardDeviation: Double) -> Double {
        let normalized = (value - mean) / standardDeviation
        return exp(-0.5 * normalized * normalized)
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

enum HealthMetricStatus: String, Codable, Equatable {
    case available
    case missing
    case stale
    case unsupported
}

struct ResolvedHealthMetric: Codable, Equatable {
    let type: HealthSampleType
    let value: Double?
    let unit: String?
    let source: DataSource?
    let confidence: ConfidenceLevel
    let status: HealthMetricStatus
    let sourceLabel: String
    let sampleID: String?
    let measuredAt: Date?
    let reason: String
}

enum HealthSourceResolver {
    static func resolve(
        type: HealthSampleType,
        samples: [HealthSample],
        now: Date = Date(),
        staleAfter: TimeInterval? = 36 * 60 * 60
    ) -> ResolvedHealthMetric {
        let candidates = samples
            .filter { $0.type == type && $0.confidence != .unavailable }
            .filter { DeviceMetricSourcePolicy.isProductionMetricSample($0) }
            .filter { isAllowed(sample: $0) }
            .sorted {
                if $0.source.deviceFirstRank != $1.source.deviceFirstRank {
                    return $0.source.deviceFirstRank < $1.source.deviceFirstRank
                }
                return $0.startDate > $1.startDate
            }

        guard let selected = candidates.first else {
            return ResolvedHealthMetric(
                type: type,
                value: nil,
                unit: nil,
                source: nil,
                confidence: .unavailable,
                status: .missing,
                sourceLabel: "No source",
                sampleID: nil,
                measuredAt: nil,
                reason: missingReason(for: type)
            )
        }

        let isStale = staleAfter.map { now.timeIntervalSince(selected.startDate) > $0 } ?? false
        return ResolvedHealthMetric(
            type: type,
            value: selected.value,
            unit: selected.unit,
            source: selected.source,
            confidence: resolvedConfidence(for: selected),
            status: isStale ? .stale : .available,
            sourceLabel: selected.source.label,
            sampleID: selected.id,
            measuredAt: selected.startDate,
            reason: isStale ? "Latest selected device value is stale." : "Selected by device-first source policy."
        )
    }

    static func primarySource(in samples: [HealthSample]) -> DataSource? {
        samples
            .filter { $0.confidence != .unavailable }
            .filter { DeviceMetricSourcePolicy.isProductionMetricSample($0) }
            .sorted {
                if $0.source.deviceFirstRank != $1.source.deviceFirstRank {
                    return $0.source.deviceFirstRank < $1.source.deviceFirstRank
                }
                return $0.startDate > $1.startDate
            }
            .first?
            .source
    }

    private static func isAllowed(sample: HealthSample) -> Bool {
        if sample.source == .whoordanEstimate,
           !isKnownDeviceEstimate(sample) {
            return false
        }
        switch sample.type {
        case .heartRate, .restingHeartRate:
            return (25...240).contains(sample.value)
        case .heartRateVariabilitySDNN, .heartRateVariabilityRMSSD:
            return sample.unit == "ms" && sample.source != .whoordanEstimate && (1...300).contains(sample.value)
        case .oxygenSaturation:
            return (50...100).contains(sample.value) && (
                sample.source == .wearableBLE
                || sample.source == .legacyWearableDeviceExport
                || (
                    sample.source == .whoordanEstimate
                        && sample.metadata["device_only_derivation"] == "true"
                        && sample.metadata["metric_policy"] == "r24_candidate_ble_derived_spo2"
                )
            )
        case .respiratoryRate:
            return (4...60).contains(sample.value)
        case .vo2Max:
            return (5..<100).contains(sample.value)
        case .steps:
            return (0...200_000).contains(sample.value)
        case .activeEnergy:
            return (0...20_000).contains(sample.value)
        case .distanceWalkingRunning:
            return (0...200_000).contains(sample.value)
        case .bodyTemperature, .wristTemperature, .temperatureEvent:
            return (20...45).contains(sample.value)
        case .sleepAnalysis:
            return (0...1_440).contains(sample.value)
        case .workout:
            return (0...1_440).contains(sample.value)
        case .wearableIMU, .wearablePPG:
            return false
        }
    }

    private static func missingReason(for type: HealthSampleType) -> String {
        switch type {
        case .heartRateVariabilitySDNN, .heartRateVariabilityRMSSD:
            return "HRV is unavailable without measured RMSSD/SDNN or true RR/IBI data."
        case .oxygenSaturation:
            return "SpO2 is unavailable without a measured source or explicitly marked low-confidence R24 BLE candidate."
        case .steps:
            return "Steps are unavailable without a step-count source."
        case .wearableIMU:
            return "Raw IMU is not a production movement metric."
        case .wearablePPG:
            return "Raw PPG is not a production oxygen metric."
        default:
            return "No valid device-first sample is available."
        }
    }

    private static func isKnownDeviceEstimate(_ sample: HealthSample) -> Bool {
        guard sample.metadata["device_only_derivation"] == "true" else { return false }
        switch sample.type {
        case .steps:
            return sample.metadata["metric_policy"] == "r10_imu_motion_step_estimate"
        case .sleepAnalysis:
            return sample.metadata["metric_policy"] == "r10_hr_imu_sleep_stage_estimate"
        case .respiratoryRate:
            return sample.metadata["metric_policy"] == "rr_interval_respiratory_rate_estimate"
        case .oxygenSaturation:
            return sample.metadata["metric_policy"] == "r24_candidate_ble_derived_spo2"
        default:
            return false
        }
    }

    private static func resolvedConfidence(for sample: HealthSample) -> ConfidenceLevel {
        if sample.type == .oxygenSaturation,
           sample.source == .whoordanEstimate,
           sample.metadata["metric_policy"] == "r24_candidate_ble_derived_spo2" {
            return .low
        }
        return sample.confidence
    }
}

enum DailyHealthAggregator {
    static func aggregate(
        samples: [HealthSample],
        day: Date,
        goal: Int = 10_000,
        calendar: Calendar = .current,
        prior: DailyHealthSummary = .empty,
        skinTemperatureBaseline: SkinTemperatureBaselineProfile = SkinTemperatureBaselineProfile()
    ) -> DailyHealthSummary {
        let dayStart = calendar.startOfDay(for: day)
        let uniqueSamples = DeviceMetricSourcePolicy.productionSamples(from: deduplicated(samples))
        let daySamples = uniqueSamples.filter { sampleOccurs($0, on: day, calendar: calendar) }
        let sleepSummary = SleepAggregator.aggregate(samples: uniqueSamples, day: day, calendar: calendar)
        let priorIsSameDay = calendar.isDate(prior.date, inSameDayAs: day)
        var summary = DailyHealthSummary.empty
        summary.date = dayStart
        if priorIsSameDay {
            summary.sleepNeedMinutes = prior.sleepNeedMinutes
        }
        summary.movement = MovementAggregator.aggregate(samples: daySamples, day: day, goal: goal, calendar: calendar)
        if sleepSummary.hasSleep {
            summary.sleepSummary = sleepSummary
            summary.sleepMinutes = sleepSummary.mainSleep?.asleepMinutes
                ?? sleepSummary.sessions.max { $0.asleepMinutes < $1.asleepMinutes }?.asleepMinutes
            if let sleepNeed = summary.sleepNeedMinutes {
                summary.sleepDebtMinutes = max(0, sleepNeed - (sleepSummary.totalAsleepMinutes ?? summary.sleepMinutes ?? 0))
            } else {
                summary.sleepDebtMinutes = nil
            }
        } else if priorIsSameDay, (prior.sleepSummary?.hasSleep == true || prior.sleepMinutes != nil) {
            summary.sleepSummary = prior.sleepSummary
            summary.sleepMinutes = prior.sleepMinutes
            summary.sleepDebtMinutes = prior.sleepDebtMinutes
        } else {
            summary.sleepSummary = nil
            summary.sleepMinutes = nil
            summary.sleepDebtMinutes = nil
        }
        let heartRateStats = heartRateWindowStats(samples: daySamples)
        summary.averageHeartRate = heartRateStats?.average
        summary.maxHeartRate = heartRateStats?.max
        summary.heartRateSampleCount = heartRateStats?.count
        summary.heartRateCoverageMinutes = heartRateStats?.coverageMinutes
        let restingHeartRate = HealthSourceResolver.resolve(type: .restingHeartRate, samples: daySamples, staleAfter: nil)
        if let value = restingHeartRate.value {
            summary.restingHeartRate = value
            summary.restingHeartRateSource = restingHeartRate.source
            summary.restingHeartRateConfidence = restingHeartRate.confidence
        } else if let sleepResting = sleepWindowRestingHeartRate(samples: daySamples, sleepSummary: sleepSummary) {
            summary.restingHeartRate = sleepResting.value
            summary.restingHeartRateSource = .whoordanEstimate
            summary.restingHeartRateConfidence = .directional
        }
        let rmssd = HealthSourceResolver.resolve(type: .heartRateVariabilityRMSSD, samples: daySamples, staleAfter: nil)
        let sdnn = HealthSourceResolver.resolve(type: .heartRateVariabilitySDNN, samples: daySamples, staleAfter: nil)
        let hrv = rmssd.value == nil ? sdnn : rmssd
        summary.hrv = hrv.value
        summary.hrvSource = hrv.source
        summary.hrvConfidence = hrv.value == nil ? nil : hrv.confidence
        let respiratory = HealthSourceResolver.resolve(type: .respiratoryRate, samples: daySamples, staleAfter: nil)
        summary.respiratoryRate = respiratory.value
        summary.respiratoryRateSource = respiratory.source
        summary.respiratoryRateConfidence = respiratory.value == nil ? nil : respiratory.confidence
        let oxygen = HealthSourceResolver.resolve(type: .oxygenSaturation, samples: daySamples, staleAfter: nil)
        summary.oxygenSaturation = oxygen.value
        summary.oxygenSaturationSource = oxygen.source
        summary.oxygenSaturationConfidence = oxygen.value == nil ? nil : oxygen.confidence
        let vo2Max = HealthSourceResolver.resolve(type: .vo2Max, samples: daySamples, staleAfter: nil)
        summary.vo2Max = vo2Max.value
        summary.vo2MaxSource = vo2Max.source
        summary.vo2MaxConfidence = vo2Max.value == nil ? nil : vo2Max.confidence
        let wristTemperature = HealthSourceResolver.resolve(type: .wristTemperature, samples: daySamples, staleAfter: nil)
        let temperatureEvent = HealthSourceResolver.resolve(type: .temperatureEvent, samples: daySamples, staleAfter: nil)
        let resolvedTemperature = wristTemperature.value == nil ? temperatureEvent : wristTemperature
        summary.rawWristTemperatureC = resolvedTemperature.value
        summary.rawWristTemperatureSource = resolvedTemperature.source
        summary.rawWristTemperatureConfidence = resolvedTemperature.value == nil ? nil : resolvedTemperature.confidence
        summary.bodyTemperatureDelta = resolvedTemperature.value.flatMap { value in
            skinTemperatureBaseline.activeBaselineC.map { value - $0 }
        }
        summary.source = summary.movement.source ?? sleepSummary.source ?? HealthSourceResolver.primarySource(in: daySamples)
        summary.confidence = bestConfidence(in: daySamples, fallback: summary.movement.confidence)
        return summary
    }

    private static func deduplicated(_ samples: [HealthSample]) -> [HealthSample] {
        var seen = Set<String>()
        return samples.filter { seen.insert($0.dedupeID).inserted }
    }

    private static func bestConfidence(in samples: [HealthSample], fallback: ConfidenceLevel) -> ConfidenceLevel {
        if samples.contains(where: { $0.confidence == .high }) { return .high }
        if samples.contains(where: { $0.confidence == .medium }) { return .medium }
        if samples.contains(where: { $0.confidence == .low }) { return .low }
        return fallback
    }

    private static func sampleOccurs(_ sample: HealthSample, on day: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return calendar.isDate(sample.startDate, inSameDayAs: day)
        }
        guard let endDate = sample.endDate else {
            return sample.startDate >= dayStart && sample.startDate < nextDay
        }
        return sample.startDate < nextDay && endDate > dayStart
    }

    private static func heartRateWindowStats(samples: [HealthSample]) -> (average: Double, max: Double, count: Int, coverageMinutes: Double)? {
        let heartRateSamples = usableHeartRateSamples(samples)
            .filter { $0.source != .cloudImport || $0.metadata["restored_measurement_copy"] == "true" }
        let values = heartRateSamples.map(\.value)
        guard values.count >= 6 else { return nil }
        let weighted = heartRateSamples.reduce(into: (total: 0.0, weight: 0.0)) { partial, sample in
            guard let endDate = sample.endDate else { return }
            let seconds = endDate.timeIntervalSince(sample.startDate)
            guard seconds > 0, seconds.isFinite else { return }
            partial.total += sample.value * seconds
            partial.weight += seconds
        }
        let average = weighted.weight > 0
            ? weighted.total / weighted.weight
            : values.reduce(0, +) / Double(values.count)
        guard let maxValue = values.max() else { return nil }
        return (average, maxValue, values.count, heartRateCoverageMinutes(for: heartRateSamples))
    }

    private static func sleepWindowRestingHeartRate(
        samples: [HealthSample],
        sleepSummary: SleepSummary
    ) -> (value: Double, count: Int)? {
        guard let mainSleep = sleepSummary.mainSleep else { return nil }
        let values = usableHeartRateSamples(samples)
            .filter { sample in
                sample.startDate >= mainSleep.start && sample.startDate <= mainSleep.end
            }
            .map(\.value)
            .sorted()
        guard values.count >= 12 else { return nil }
        let percentileIndex = min(max(Int((Double(values.count - 1) * 0.20).rounded()), 0), values.count - 1)
        return (values[percentileIndex], values.count)
    }

    private static func usableHeartRateSamples(_ samples: [HealthSample]) -> [HealthSample] {
        samples.filter { sample in
            sample.type == .heartRate
                && sample.confidence != .unavailable
                && (25...240).contains(sample.value)
                && sample.metadata["contact_detected"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "false"
        }
    }

    private static func heartRateCoverageMinutes(for samples: [HealthSample]) -> Double {
        let sorted = samples.sorted { $0.startDate < $1.startDate }
        guard !sorted.isEmpty else { return 0 }
        let seconds = sorted.enumerated().reduce(0.0) { total, item in
            let index = item.offset
            let sample = item.element
            if let endDate = sample.endDate {
                let duration = endDate.timeIntervalSince(sample.startDate)
                if duration > 0, duration.isFinite {
                    return total + min(duration, 5 * 60)
                }
            }
            if index + 1 < sorted.count {
                let gap = sorted[index + 1].startDate.timeIntervalSince(sample.startDate)
                if gap > 0, gap.isFinite, gap <= 5 * 60 {
                    return total + gap
                }
            }
            return total + 60
        }
        return max(seconds / 60, 0)
    }
}

enum RecoveryContributorKind: String, Equatable, CaseIterable {
    case hrv
    case restingHeartRate
    case sleepSufficiency
    case respiratoryFit
    case temperatureDeviation
    case oxygenSaturation

    var title: String {
        switch self {
        case .hrv: return "HRV relative to baseline"
        case .restingHeartRate: return "RHR relative to baseline"
        case .sleepSufficiency: return "Sleep sufficiency"
        case .respiratoryFit: return "Respiratory fit"
        case .temperatureDeviation: return "Temperature deviation"
        case .oxygenSaturation: return "SpO2 source context"
        }
    }

    var shortTitle: String {
        switch self {
        case .hrv: return "HRV"
        case .restingHeartRate: return "RHR"
        case .sleepSufficiency: return "Sleep"
        case .respiratoryFit: return "Respiratory"
        case .temperatureDeviation: return "Temperature"
        case .oxygenSaturation: return "SpO2"
        }
    }

    var symbol: String {
        switch self {
        case .hrv: return "waveform.path.ecg"
        case .restingHeartRate: return "heart"
        case .sleepSufficiency: return "moon"
        case .respiratoryFit: return "lungs"
        case .temperatureDeviation: return "thermometer.medium"
        case .oxygenSaturation: return "drop"
        }
    }
}

struct RecoveryContributorScore: Equatable, Identifiable {
    let kind: RecoveryContributorKind
    let value: Double?
    let baseline: Double?
    let componentScore: Double?
    let weight: Double

    var id: RecoveryContributorKind { kind }

    var isMissing: Bool {
        componentScore == nil
    }

    var impact: Double? {
        componentScore.map { ($0 - 50) * weight }
    }
}

enum RecoveryExplainer {
    static let hrvWeight = 0.35
    static let restingHeartRateWeight = 0.20
    static let sleepWeight = 0.17
    static let respiratoryWeight = 0.20
    static let temperatureWeight = 0.08
    static let oxygenSaturationWeight = 0.0

    static func inputs(from summary: DailyHealthSummary) -> RecoveryInputs {
        RecoveryInputs(
            hrv: summary.hrv,
            hrvBaseline: nil,
            restingHeartRate: summary.restingHeartRate,
            restingHeartRateBaseline: nil,
            sleepMinutes: summary.sleepMinutes,
            sleepNeedMinutes: summary.sleepNeedMinutes,
            respiratoryRate: summary.respiratoryRate,
            respiratoryRateBaseline: nil,
            temperatureDelta: summary.bodyTemperatureDelta,
            oxygenSaturation: summary.oxygenSaturation
        )
    }

    static func contributors(inputs: RecoveryInputs) -> [RecoveryContributorScore] {
        [
            RecoveryContributorScore(
                kind: .hrv,
                value: inputs.hrv,
                baseline: inputs.hrvBaseline,
                componentScore: positiveRatio(value: inputs.hrv, baseline: inputs.hrvBaseline),
                weight: hrvWeight
            ),
            RecoveryContributorScore(
                kind: .restingHeartRate,
                value: inputs.restingHeartRate,
                baseline: inputs.restingHeartRateBaseline,
                componentScore: inverseRatio(value: inputs.restingHeartRate, baseline: inputs.restingHeartRateBaseline),
                weight: restingHeartRateWeight
            ),
            RecoveryContributorScore(
                kind: .sleepSufficiency,
                value: inputs.sleepMinutes,
                baseline: inputs.sleepNeedMinutes,
                componentScore: sleepScore(minutes: inputs.sleepMinutes, need: inputs.sleepNeedMinutes),
                weight: sleepWeight
            ),
            RecoveryContributorScore(
                kind: .respiratoryFit,
                value: inputs.respiratoryRate,
                baseline: inputs.respiratoryRateBaseline,
                componentScore: centered(value: inputs.respiratoryRate, baseline: inputs.respiratoryRateBaseline, tolerance: 2),
                weight: respiratoryWeight
            ),
            RecoveryContributorScore(
                kind: .temperatureDeviation,
                value: inputs.temperatureDelta,
                baseline: 0,
                componentScore: temperatureScore(delta: inputs.temperatureDelta),
                weight: temperatureWeight
            ),
            RecoveryContributorScore(
                kind: .oxygenSaturation,
                value: inputs.oxygenSaturation,
                baseline: nil,
                componentScore: oxygenSaturationScore(percent: inputs.oxygenSaturation),
                weight: oxygenSaturationWeight
            )
        ]
    }

    static func score(inputs: RecoveryInputs) -> (value: Double, confidence: ConfidenceLevel)? {
        let contributors = contributors(inputs: inputs)
        let available = contributors.compactMap { contributor -> (kind: RecoveryContributorKind, score: Double, weight: Double)? in
            guard let score = contributor.componentScore else { return nil }
            return (contributor.kind, clamp(score, 0, 100), contributor.weight)
        }
        let weight = available.reduce(0) { $0 + $1.weight }
        guard weight > 0 else { return nil }
        let coreWeight = available
            .filter { $0.kind != .oxygenSaturation }
            .reduce(0) { $0 + $1.weight }
        guard coreWeight > 0 else { return nil }
        let weighted = available.reduce(0) { $0 + $1.score * $1.weight }
        let confidence: ConfidenceLevel = weight >= 0.75 ? .high : (weight >= 0.4 ? .medium : .low)
        return (clamp(weighted / weight, 0, 100), confidence)
    }

    static func category(for score: Double?) -> String {
        guard let score else { return "Building" }
        if score < 40 { return "Low" }
        if score < 70 { return "Steady" }
        return "Strong"
    }

    private static func positiveRatio(value: Double?, baseline: Double?) -> Double? {
        guard let value, let baseline, baseline > 0 else { return nil }
        return 50 + ((value / baseline) - 1) * 80
    }

    private static func inverseRatio(value: Double?, baseline: Double?) -> Double? {
        guard let value, let baseline, baseline > 0 else { return nil }
        return 50 + (1 - (value / baseline)) * 90
    }

    private static func sleepScore(minutes: Double?, need: Double?) -> Double? {
        guard let minutes, let need, need > 0 else { return nil }
        return min(minutes / need, 1.12) * 89
    }

    private static func centered(value: Double?, baseline: Double?, tolerance: Double) -> Double? {
        guard let value, let baseline else { return nil }
        return 100 - min(abs(value - baseline) / tolerance, 1) * 80
    }

    private static func temperatureScore(delta: Double?) -> Double? {
        guard let delta else { return nil }
        return 100 - min(abs(delta) / 1.2, 1) * 80
    }

    private static func oxygenSaturationScore(percent: Double?) -> Double? {
        guard let percent, (50...100).contains(percent) else { return nil }
        if percent >= 95 { return 50 }
        return clamp(20 + ((percent - 90) / 5 * 30), 20, 50)
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

struct WhoordanScoringService: ScoringServicing {
    func score(summary: DailyHealthSummary, bodyProfile: BodyProfile = BodyProfile()) -> DailyHealthSummary {
        var copy = summary
        if copy.strain == nil {
            let inferredActiveMinutes = summary.movement.movementMinutes
                ?? summary.heartRateCoverageMinutes.map { min(max($0, 0), 1_440) }
                ?? 0
            copy.strain = strain(inputs: StrainInputs(
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
            ))
        }
        return copy
    }

    func recovery(inputs: RecoveryInputs) -> ScoreValue? {
        guard let result = RecoveryExplainer.score(inputs: inputs) else { return nil }
        return ScoreValue(
            value: result.value,
            scale: 0...100,
            confidence: result.confidence,
            explanation: "Original Whoordan recovery estimate from available personal signals. Not medical guidance."
        )
    }

    func strain(inputs: StrainInputs) -> ScoreValue? {
        let zoneLoad = inputs.zoneMinutes.reduce(0.0) { partial, item in
            partial + zoneWeight(for: item.key) * max(item.value, 0)
        }
        let maxHeartRate = inputs.configuredMaxHeartRate ?? inputs.maxHeartRate
        let restingHeartRate = clamp(inputs.restingHeartRate ?? 60.0, 35, 100)
        let reserveSpan = maxHeartRate.map { max($0 - restingHeartRate, 1) }
        let averageReserve: Double
        if let averageHeartRate = inputs.averageHeartRate,
           let reserveSpan {
            averageReserve = clamp((averageHeartRate - restingHeartRate) / reserveSpan, 0, 1)
        } else {
            averageReserve = 0
        }
        let peakReserve: Double
        if let peakHeartRate = inputs.maxHeartRate,
           let reserveSpan {
            peakReserve = clamp((peakHeartRate - restingHeartRate) / reserveSpan, 0, 1)
        } else {
            peakReserve = 0
        }
        let zoneMinutes = inputs.zoneMinutes.values.reduce(0) { $0 + max($1, 0) }
        let activeMinutes = min(max(inputs.activeMinutes, zoneMinutes), 1_440)
        let peakMinutes = min(activeMinutes, 30)
        let allDayCardioLoad = activeMinutes * pow(averageReserve, 1.8) * 0.055
        let peakCardioLoad = peakMinutes * pow(peakReserve, 2)
        let movementLoad: Double
        if inputs.movementConfidence == .unavailable {
            movementLoad = 0
        } else {
            let stepGoal = max(Double(inputs.stepGoal ?? 10_000), 1)
            let stepLoad = inputs.steps.map { min(Double($0) / stepGoal, 1.6) * 12 } ?? 0
            let energyLoad = inputs.activeEnergyKilocalories.map { min($0 / 700, 1.5) * 9 } ?? 0
            movementLoad = stepLoad + energyLoad
        }
        let muscularLoad = inputs.muscularActivitySourceConfidence == .unavailable
            ? 0
            : max(inputs.muscularMinutes ?? 0, 0) * 2.5
        let load = allDayCardioLoad + peakCardioLoad + zoneLoad + muscularLoad + movementLoad
        guard load > 0 else { return nil }
        let score = 21 * (1 - exp(-load / 180))
        let confidence: ConfidenceLevel
        if inputs.averageHeartRate != nil {
            confidence = .medium
        } else if inputs.movementConfidence != .unavailable {
            confidence = .low
        } else if inputs.muscularActivitySourceConfidence != .unavailable {
            confidence = .low
        } else {
            confidence = .unavailable
        }
        return ScoreValue(
            value: clamp(score, 0, 21),
            scale: 0...21,
            confidence: confidence,
            explanation: "Beta Whoordan day-strain estimate from aligned cardio, muscular, and source-labeled activity load. Wellness context only; not medical guidance."
        )
    }

    func heartRateZones(age: Int?, configuredMax: Double?) -> [ClosedRange<Double>] {
        let maxHR = configuredMax ?? age.map { 208 - 0.7 * Double($0) } ?? 190
        return [
            (0.50 * maxHR)...(0.60 * maxHR),
            (0.60 * maxHR)...(0.70 * maxHR),
            (0.70 * maxHR)...(0.80 * maxHR),
            (0.80 * maxHR)...(0.90 * maxHR),
            (0.90 * maxHR)...maxHR
        ]
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func zoneWeight(for zone: Int) -> Double {
        switch zone {
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 4: return 5
        case 5: return 8
        default: return Double(max(zone, 0))
        }
    }
}
