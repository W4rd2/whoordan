import XCTest
@testable import Whoordan

final class HealthKitTests: XCTestCase {
    func testHealthKitIsExportOnlyAtAppLayer() {
        XCTAssertTrue(HealthKitService().supportedReadTypes().isEmpty)
        XCTAssertEqual(
            Set(HealthKitService().supportedWriteTypes()),
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
        )
    }

    func testAppleHealthAuthorizationPlannerSkipsOnlyUnauthorizedTypes() {
        let now = Date(timeIntervalSince1970: 1_000)
        let heartRate = healthSample(type: .heartRate, value: 72, id: "hr-1", date: now)
        let steps = healthSample(type: .steps, value: 120, id: "steps-1", date: now)

        let plan = AppleHealthWriteAuthorizationPlanner.plan(samples: [heartRate, steps]) { type in
            type == .steps ? .notAuthorized : .authorized
        }

        XCTAssertEqual(plan.writableSamples.map(\.type), [.heartRate])
        XCTAssertEqual(plan.notAuthorizedSamples.map(\.type), [.steps])
        XCTAssertEqual(plan.notAuthorizedTypes, [.steps])
    }

    func testHealthKitServiceContainsNoImportQueryRuntime() throws {
        let source = try String(
            contentsOf: projectRoot().appendingPathComponent("Whoordan/Core/HealthKit/HealthKitService.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("HKSampleQuery"), "Whoordan must not keep Apple Health sample import queries in the app runtime.")
        XCTAssertFalse(source.contains("HKAnchoredObjectQuery"), "Whoordan must not keep anchored Apple Health import queries in the app runtime.")
        XCTAssertFalse(source.contains("enableBackgroundDelivery"), "Apple Health background import delivery must stay absent in third-party wearable-device-only mode.")
        XCTAssertFalse(source.contains("hkReadTypes"), "Apple Health read type builders must stay absent in third-party wearable-device-only mode.")
    }

    func testHealthKitMapperRejectsOutlierHeartRate() {
        let sample = HealthKitMapper.normalizeQuantity(
            identifier: "HKQuantityTypeIdentifierHeartRate",
            value: 400,
            start: Date(),
            end: nil,
            sourceName: "Apple Watch",
            sourceRecordID: "sample-1"
        )
        XCTAssertNil(sample)
    }

    private func healthSample(type: HealthSampleType, value: Double, id: String, date: Date) -> HealthSample {
        HealthSample(
            id: id,
            type: type,
            value: value,
            unit: type == .heartRate ? "bpm" : "unit",
            startDate: date,
            endDate: nil,
            source: .wearableBLE,
            sourceRecordID: id,
            confidence: .high,
            metadata: [:]
        )
    }

    func testHealthKitMapperConvertsFractionalOxygenSaturation() throws {
        let sample = HealthKitMapper.normalizeQuantity(
            identifier: "HKQuantityTypeIdentifierOxygenSaturation",
            value: 0.97,
            start: Date(),
            end: nil,
            sourceName: "Apple Watch",
            sourceRecordID: "sample-2"
        )
        let normalized = try XCTUnwrap(sample)
        XCTAssertEqual(normalized.value, 97, accuracy: 0.001)
        XCTAssertEqual(normalized.unit, "%")
        XCTAssertEqual(normalized.source, .appleHealth)
    }

    func testHealthKitMapperMapsStepsActiveEnergyAndDistance() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let steps = try XCTUnwrap(HealthKitMapper.normalizeQuantity(
            identifier: "HKQuantityTypeIdentifierStepCount",
            value: 4321,
            start: start,
            end: nil,
            sourceName: "iPhone",
            sourceRecordID: "steps-1"
        ))
        XCTAssertEqual(steps.type, .steps)
        XCTAssertEqual(steps.value, 4321)
        XCTAssertEqual(steps.unit, "count")

        let energy = try XCTUnwrap(HealthKitMapper.normalizeQuantity(
            identifier: "HKQuantityTypeIdentifierActiveEnergyBurned",
            value: 315.2,
            start: start,
            end: nil,
            sourceName: "Apple Watch",
            sourceRecordID: "energy-1"
        ))
        XCTAssertEqual(energy.type, .activeEnergy)
        XCTAssertEqual(energy.unit, "kcal")

        let distance = try XCTUnwrap(HealthKitMapper.normalizeQuantity(
            identifier: "HKQuantityTypeIdentifierDistanceWalkingRunning",
            value: 2_400,
            start: start,
            end: nil,
            sourceName: "iPhone",
            sourceRecordID: "distance-1"
        ))
        XCTAssertEqual(distance.type, .distanceWalkingRunning)
        XCTAssertEqual(distance.unit, "m")
    }

    func testMovementAggregatorUsesOnlyReliableWearableStepsAndDeduplicatesRecords() {
        let day = Date(timeIntervalSince1970: 1_000)
        let samples = [
            sample(type: .steps, value: 5_000, source: .wearableBLE, id: "shared", date: day),
            sample(type: .steps, value: 4_500, source: .appleHealth, id: "apple-1", date: day),
            sample(type: .steps, value: 4_500, source: .appleHealth, id: "apple-1", date: day),
            sample(type: .activeEnergy, value: 300, source: .appleHealth, id: "energy-1", date: day)
        ]
        let movement = MovementAggregator.aggregate(samples: samples, day: day, goal: 9_000)
        XCTAssertEqual(movement.steps, 5_000)
        XCTAssertEqual(movement.source, .wearableBLE)
        XCTAssertEqual(movement.confidence, .high)
        XCTAssertEqual(try XCTUnwrap(movement.goalProgress), 0.555, accuracy: 0.001)
        XCTAssertNil(movement.activeEnergyKilocalories)
    }

    func testMovementAggregatorDoesNotFallBackToAppleHealthForEachMovementMetric() {
        let day = Date(timeIntervalSince1970: 2_000)
        let samples = [
            sample(type: .activeEnergy, value: 110, source: .wearableBLE, id: "wearable-energy", date: day),
            sample(type: .activeEnergy, value: 420, source: .appleHealth, id: "apple-energy", date: day),
            sample(type: .distanceWalkingRunning, value: 1_600, source: .appleHealth, id: "apple-distance", date: day)
        ]

        let movement = MovementAggregator.aggregate(samples: samples, day: day)

        XCTAssertNil(movement.steps)
        XCTAssertEqual(movement.activeEnergyKilocalories, 110)
        XCTAssertNil(movement.walkingRunningDistanceMeters)
        XCTAssertEqual(movement.source, .wearableBLE)
        XCTAssertEqual(movement.confidence, .high)
    }

    func testMovementAggregatorDoesNotUseAppleHealthStepsWhenWearableStepsAreMissing() {
        let day = Date(timeIntervalSince1970: 3_000)
        let samples = [
            sample(type: .steps, value: 3_200, source: .appleHealth, id: "apple-steps-1", date: day),
            sample(type: .steps, value: 1_800, source: .appleHealth, id: "apple-steps-2", date: day)
        ]

        let movement = MovementAggregator.aggregate(samples: samples, day: day, goal: 8_000)

        XCTAssertNil(movement.steps)
        XCTAssertNil(movement.source)
        XCTAssertNil(movement.goalProgress)
        XCTAssertEqual(movement.confidence, .unavailable)
    }

    func testSleepAggregatorPrefersWearableSleepOverAppleHealthFallback() {
        let day = Date(timeIntervalSince1970: 86_400)
        let samples = [
            sleepSample(source: .appleHealth, id: "apple-main", start: day.addingTimeInterval(60 * 60), minutes: 430),
            sleepSample(source: .appleHealth, id: "apple-nap", start: day.addingTimeInterval(15 * 60 * 60), minutes: 42),
            sleepSample(source: .wearableBLE, id: "wearable-main", start: day.addingTimeInterval(90 * 60), minutes: 390)
        ]

        let sleep = SleepAggregator.aggregate(samples: samples, day: day, calendar: .gregorianUTC)

        XCTAssertEqual(sleep.source, DataSource.wearableBLE)
        XCTAssertEqual(sleep.mainSleep?.asleepMinutes, 390)
        XCTAssertEqual(sleep.naps.count, 0)
        XCTAssertEqual(sleep.totalAsleepMinutes, 390)
    }

    func testSleepAggregatorDoesNotUseAppleHealthFallbackOrClassifyNaps() {
        let day = Date(timeIntervalSince1970: 172_800)
        let samples = [
            sleepSample(source: .appleHealth, id: "overnight", start: day.addingTimeInterval(30 * 60), minutes: 420),
            sleepSample(source: .appleHealth, id: "nap", start: day.addingTimeInterval(14 * 60 * 60), minutes: 38)
        ]

        let sleep = SleepAggregator.aggregate(samples: samples, day: day, calendar: .gregorianUTC)

        XCTAssertFalse(sleep.hasSleep)
        XCTAssertNil(sleep.source)
        XCTAssertNil(sleep.mainSleep)
        XCTAssertTrue(sleep.naps.isEmpty)
        XCTAssertNil(sleep.napMinutes)
        XCTAssertNil(sleep.totalAsleepMinutes)
    }

    func testSleepAggregatorMapsVerifiedWearableStagesAndEfficiency() throws {
        let day = Date(timeIntervalSince1970: 259_200)
        let samples = [
            sleepSample(source: .wearableBLE, id: "in-bed", start: day, minutes: 480, category: "0"),
            sleepSample(source: .wearableBLE, id: "awake", start: day.addingTimeInterval(30 * 60), minutes: 30, category: "2"),
            sleepSample(source: .wearableBLE, id: "core", start: day.addingTimeInterval(90 * 60), minutes: 120, category: "3"),
            sleepSample(source: .wearableBLE, id: "deep", start: day.addingTimeInterval(230 * 60), minutes: 60, category: "4"),
            sleepSample(source: .wearableBLE, id: "rem", start: day.addingTimeInterval(310 * 60), minutes: 90, category: "5")
        ]

        let sleep = SleepAggregator.aggregate(samples: samples, day: day, calendar: .gregorianUTC)

        let main = try XCTUnwrap(sleep.mainSleep)
        XCTAssertEqual(main.asleepMinutes, 270)
        XCTAssertEqual(main.inBedMinutes, 480, accuracy: 0.001)
        XCTAssertEqual(main.efficiencyPercent ?? 0, 56.25, accuracy: 0.001)
        XCTAssertEqual(sleep.stageTotals[.awake], 30)
        XCTAssertEqual(sleep.stageTotals[.core], 120)
        XCTAssertEqual(sleep.stageTotals[.deep], 60)
        XCTAssertEqual(sleep.stageTotals[.rem], 90)
        XCTAssertEqual(sleep.restorativeMinutes, 150)
        XCTAssertEqual(sleep.restorativePercent ?? 0, 55.55, accuracy: 0.01)
    }

    func testMetricCatalogUnlocksRestorativeSleepWhenSourceLabeledStagesExist() throws {
        let day = Date(timeIntervalSince1970: 259_200)
        let sleep = SleepAggregator.aggregate(samples: [
            sleepSample(source: .wearableBLE, id: "core", start: day.addingTimeInterval(90 * 60), minutes: 120, category: "3"),
            sleepSample(source: .wearableBLE, id: "deep", start: day.addingTimeInterval(230 * 60), minutes: 60, category: "4"),
            sleepSample(source: .wearableBLE, id: "rem", start: day.addingTimeInterval(310 * 60), minutes: 90, category: "5")
        ], day: day, calendar: .gregorianUTC)
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.sleepSummary = sleep
        summary.sleepMinutes = sleep.mainSleep?.asleepMinutes

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: day
        )
        let restorativePercent = try XCTUnwrap(metrics.first { $0.id == .restorativeSleepPercent })
        let restorativeHours = try XCTUnwrap(metrics.first { $0.id == .restorativeSleepHours })

        XCTAssertEqual(restorativePercent.readiness, .showNow)
        XCTAssertEqual(restorativePercent.value, "56")
        XCTAssertEqual(restorativeHours.readiness, .showNow)
        XCTAssertEqual(restorativeHours.value, "2h 30m")
    }

    func testSleepAggregatorDoesNotCreateNapFromMotionOrHeartRateOnly() {
        let day = Date(timeIntervalSince1970: 345_600)
        let samples = [
            sample(type: .wearableIMU, value: 100, source: .wearableBLE, id: "imu-rest", date: day.addingTimeInterval(14 * 60 * 60)),
            sample(type: .heartRate, value: 51, source: .wearableBLE, id: "low-hr", date: day.addingTimeInterval(14 * 60 * 60))
        ]

        let sleep = SleepAggregator.aggregate(samples: samples, day: day, calendar: .gregorianUTC)

        XCTAssertFalse(sleep.hasSleep)
        XCTAssertTrue(sleep.naps.isEmpty)
    }

    func testSleepAggregatorMergesOverlappingEstimatedSleepByCoveredTime() throws {
        let day = Date(timeIntervalSince1970: 86_400)
        let start = day.addingTimeInterval(10 * 60 * 60)
        let samples = (0..<50).map { index in
            sleepSample(
                source: .whoordanEstimate,
                id: "estimated-sleep-\(index)",
                start: start.addingTimeInterval(TimeInterval(index * 30)),
                minutes: 1,
                category: "4"
            )
        }

        let sleep = SleepAggregator.aggregate(samples: samples, day: day, calendar: .gregorianUTC)
        let session = try XCTUnwrap(sleep.sessions.first)

        XCTAssertEqual(session.asleepMinutes, 25.5, accuracy: 0.01)
        XCTAssertEqual(session.inBedMinutes, 25.5, accuracy: 0.01)
        XCTAssertEqual(sleep.stageTotals[.deep] ?? 0, 25.5, accuracy: 0.01)
        XCTAssertEqual(session.confidence, .low)
    }

    func testSleepAggregatorRequiresEnoughEstimatedSleepCoverage() {
        let day = Date(timeIntervalSince1970: 86_400)
        let sample = sleepSample(
            source: .whoordanEstimate,
            id: "short-estimated-sleep",
            start: day.addingTimeInterval(10 * 60 * 60),
            minutes: 5,
            category: "4"
        )

        let sleep = SleepAggregator.aggregate(samples: [sample], day: day, calendar: .gregorianUTC)

        XCTAssertFalse(sleep.hasSleep)
    }

    func testSleepAggregatorIncludesPreviousEveningEstimatedChunksForWakeDay() throws {
        let day = Date(timeIntervalSince1970: 86_400)
        let start = day.addingTimeInterval(-30 * 60)
        let samples = (0..<45).map { index in
            sleepSample(
                source: .whoordanEstimate,
                id: "overnight-estimated-sleep-\(index)",
                start: start.addingTimeInterval(TimeInterval(index * 60)),
                minutes: 1,
                category: "3"
            )
        }

        let sleep = SleepAggregator.aggregate(samples: samples, day: day, calendar: .gregorianUTC)
        let session = try XCTUnwrap(sleep.sessions.first)

        XCTAssertEqual(session.start, start)
        XCTAssertEqual(session.asleepMinutes, 45, accuracy: 0.001)
        XCTAssertEqual(session.stageSegments.first?.stage, .core)
    }

    func testSleepAggregatorDoesNotLetShortDirectNapHideBleDerivedMainSleep() throws {
        let day = Date(timeIntervalSince1970: 86_400)
        let directNap = sleepSample(
            source: .wearableBLE,
            id: "short-direct-nap",
            start: day.addingTimeInterval(14 * 60 * 60),
            minutes: 25
        )
        let estimatedMain = sleepSample(
            source: .whoordanEstimate,
            id: "estimated-main",
            start: day.addingTimeInterval(22 * 60 * 60),
            minutes: 450,
            category: "3"
        )

        let sleep = SleepAggregator.aggregate(samples: [directNap, estimatedMain], day: day, calendar: .gregorianUTC)

        XCTAssertEqual(sleep.source, .whoordanEstimate)
        XCTAssertEqual(sleep.mainSleep?.asleepMinutes, 450)
        XCTAssertEqual(sleep.naps.count, 0)
    }

    func testSleepAggregatorRefinesEstimatedStagesWithBleSessionContext() throws {
        let day = Date(timeIntervalSince1970: 86_400)
        let start = day.addingTimeInterval(60 * 60)
        let stageSamples = (0..<240).map { index -> HealthSample in
            let heartRate: Int
            let motionRange: Double
            if index < 75 {
                heartRate = 52
                motionRange = 0.012
            } else if index < 165 {
                heartRate = index.isMultiple(of: 7) ? 61 : 60
                motionRange = 0.035
            } else {
                heartRate = index.isMultiple(of: 9) ? 69 : 67
                motionRange = 0.018
            }
            return estimatedSleepSample(
                id: "estimated-context-\(index)",
                start: start.addingTimeInterval(TimeInterval(index * 60)),
                minutes: 1,
                heartRate: heartRate,
                motionRange: motionRange
            )
        }
        let hrvSamples = stride(from: 0, to: 240, by: 5).map { index in
            sample(
                type: .heartRateVariabilityRMSSD,
                value: index >= 165 ? 62 : 39,
                source: .wearableBLE,
                id: "rmssd-\(index)",
                date: start.addingTimeInterval(TimeInterval(index * 60))
            )
        }

        let sleep = SleepAggregator.aggregate(
            samples: stageSamples + hrvSamples,
            day: day,
            calendar: .gregorianUTC
        )

        let session = try XCTUnwrap(sleep.mainSleep)
        XCTAssertEqual(session.asleepMinutes, 240, accuracy: 0.001)
        XCTAssertGreaterThan(sleep.stageTotals[.deep] ?? 0, 40)
        XCTAssertGreaterThan(sleep.stageTotals[.core] ?? 0, 40)
        XCTAssertGreaterThan(sleep.stageTotals[.rem] ?? 0, 10)
        XCTAssertNil(sleep.stageTotals[.asleep])
        XCTAssertTrue(session.stageSegments.allSatisfy { $0.confidence == .low })
    }

    func testSourceResolverUsesWearableDeviceOnly() throws {
        let now = Date(timeIntervalSince1970: 5_000)
        let samples = [
            sample(type: .heartRate, value: 69, source: .cloudImport, id: "cloud", date: now),
            sample(type: .heartRate, value: 68, source: .localManual, id: "manual", date: now),
            sample(type: .heartRate, value: 67, source: .appleHealth, id: "apple", date: now),
            sample(type: .heartRate, value: 66, source: .wearableBLE, id: "wearable", date: now)
        ]
        let resolved = HealthSourceResolver.resolve(type: .heartRate, samples: samples, now: now, staleAfter: nil)
        XCTAssertEqual(resolved.value, 66)
        XCTAssertEqual(resolved.source, .wearableBLE)
        XCTAssertEqual(resolved.status, .available)
        XCTAssertEqual(resolved.reason, "Selected by device-first source policy.")
    }

    func testSourceResolverDoesNotFallBackToAppleHealthWhenWearableIsMissing() {
        let now = Date(timeIntervalSince1970: 5_000)
        let samples = [
            sample(type: .heartRate, value: 67, source: .appleHealth, id: "apple", date: now),
            sample(type: .heartRate, value: 69, source: .cloudImport, id: "cloud", date: now)
        ]
        let resolved = HealthSourceResolver.resolve(type: .heartRate, samples: samples, now: now, staleAfter: nil)
        XCTAssertNil(resolved.value)
        XCTAssertNil(resolved.source)
        XCTAssertEqual(resolved.status, .missing)
        XCTAssertTrue(resolved.reason.contains("device-first sample"))
    }

    func testSourceResolverAcceptsTrustedLegacyWearableDeviceExport() {
        let now = Date(timeIntervalSince1970: 5_000)
        let samples = [
            sample(type: .heartRate, value: 67, source: .appleHealth, id: "apple", date: now),
            sample(type: .heartRate, value: 64, source: .legacyWearableDeviceExport, id: "legacy", date: now)
        ]

        let resolved = HealthSourceResolver.resolve(type: .heartRate, samples: samples, now: now, staleAfter: nil)

        XCTAssertEqual(resolved.value, 64)
        XCTAssertEqual(resolved.source, .legacyWearableDeviceExport)
        XCTAssertEqual(resolved.status, .available)
    }

    func testCloudCopyIsNotPrimaryMeasurementUnlessRestoredCopyIsMarked() {
        let now = Date(timeIntervalSince1970: 5_000)
        let hiddenCloud = HealthSample(
            id: "cloud",
            type: .restingHeartRate,
            value: 60,
            unit: "bpm",
            startDate: now,
            endDate: nil,
            source: .cloudImport,
            sourceRecordID: "cloud",
            confidence: .high,
            metadata: [:]
        )
        XCTAssertEqual(
            HealthSourceResolver.resolve(type: .restingHeartRate, samples: [hiddenCloud], now: now).status,
            .missing
        )

        let restored = HealthSample(
            id: "cloud-restored",
            type: .restingHeartRate,
            value: 60,
            unit: "bpm",
            startDate: now,
            endDate: nil,
            source: .cloudImport,
            sourceRecordID: "cloud-restored",
            confidence: .medium,
            metadata: ["restored_measurement_copy": "true"]
        )
        let resolved = HealthSourceResolver.resolve(type: .restingHeartRate, samples: [restored], now: now)
        XCTAssertNil(resolved.source)
        XCTAssertNil(resolved.value)
        XCTAssertEqual(resolved.status, .missing)
    }

    func testSourceResolverDoesNotCreateTrueHRVFromBPMOnlyData() {
        let now = Date(timeIntervalSince1970: 5_000)
        let samples = [
            sample(type: .heartRate, value: 62, source: .wearableBLE, id: "wearable-hr", date: now)
        ]
        let resolved = HealthSourceResolver.resolve(type: .heartRateVariabilitySDNN, samples: samples, now: now)
        XCTAssertEqual(resolved.status, .missing)
        XCTAssertTrue(resolved.reason.contains("HRV is unavailable"))
    }

    func testDailyHealthAggregatorPrefersRMSSDOverSDNNForHRV() {
        let day = Date(timeIntervalSince1970: 86_400)
        let rmssd = sample(type: .heartRateVariabilityRMSSD, value: 52, source: .wearableBLE, id: "rmssd", date: day)
        let sdnn = sample(type: .heartRateVariabilitySDNN, value: 31, source: .wearableBLE, id: "sdnn", date: day)

        let summary = DailyHealthAggregator.aggregate(samples: [sdnn, rmssd], day: day, calendar: .gregorianUTC)

        XCTAssertEqual(summary.hrv, 52)
        XCTAssertEqual(summary.hrvSource, .wearableBLE)
        XCTAssertEqual(summary.hrvConfidence, .high)
    }

    func testDailyHealthAggregatorFallsBackToSDNNWhenRMSSDIsMissing() {
        let day = Date(timeIntervalSince1970: 86_400)
        let sdnn = sample(type: .heartRateVariabilitySDNN, value: 31, source: .wearableBLE, id: "sdnn", date: day)

        let summary = DailyHealthAggregator.aggregate(samples: [sdnn], day: day, calendar: .gregorianUTC)

        XCTAssertEqual(summary.hrv, 31)
        XCTAssertEqual(summary.hrvSource, .wearableBLE)
    }

    func testSourceResolverDoesNotPromoteUncalibratedSpO2Estimate() {
        let now = Date(timeIntervalSince1970: 5_000)
        let estimated = sample(type: .oxygenSaturation, value: 97, source: .whoordanEstimate, id: "estimated-spo2", date: now)
        let resolved = HealthSourceResolver.resolve(type: .oxygenSaturation, samples: [estimated], now: now)
        XCTAssertEqual(resolved.status, .missing)
        XCTAssertTrue(resolved.reason.contains("SpO2 is unavailable"))
    }

    func testDailyHealthAggregatorCarriesOnlyWearableSpO2IntoSummary() {
        let day = Date(timeIntervalSince1970: 86_400)
        let sourceLabeled = sample(type: .oxygenSaturation, value: 96, source: .wearableBLE, id: "wearable-spo2", date: day)
        let unconfirmedEstimate = sample(type: .oxygenSaturation, value: 99, source: .whoordanEstimate, id: "r24-estimate", date: day)

        let summary = DailyHealthAggregator.aggregate(
            samples: [unconfirmedEstimate, sourceLabeled],
            day: day,
            calendar: .gregorianUTC
        )

        XCTAssertEqual(summary.oxygenSaturation, 96)
    }

    func testDailyHealthAggregatorIgnoresAppleHealthSpO2InWearableDeviceOnlyMode() {
        let day = Date(timeIntervalSince1970: 86_400)
        let sourceLabeled = sample(type: .oxygenSaturation, value: 96, source: .appleHealth, id: "apple-spo2", date: day)

        let summary = DailyHealthAggregator.aggregate(
            samples: [sourceLabeled],
            day: day,
            calendar: .gregorianUTC
        )

        XCTAssertNil(summary.oxygenSaturation)
    }

    func testDailyHealthAggregatorDoesNotPromoteUnconfirmedSpO2Estimate() {
        let day = Date(timeIntervalSince1970: 86_400)
        let unconfirmedEstimate = sample(type: .oxygenSaturation, value: 99, source: .whoordanEstimate, id: "r24-estimate", date: day)

        let summary = DailyHealthAggregator.aggregate(
            samples: [unconfirmedEstimate],
            day: day,
            calendar: .gregorianUTC
        )

        XCTAssertNil(summary.oxygenSaturation)
    }

    func testDailyHealthAggregatorDoesNotCarryPriorSpO2WithoutCurrentMeasuredSource() {
        let day = Date(timeIntervalSince1970: 86_400)
        let unconfirmedEstimate = sample(type: .oxygenSaturation, value: 99, source: .whoordanEstimate, id: "r24-estimate", date: day)
        var prior = DailyHealthSummary.empty
        prior.date = day.addingTimeInterval(-86_400)
        prior.oxygenSaturation = 96

        let summary = DailyHealthAggregator.aggregate(
            samples: [unconfirmedEstimate],
            day: day,
            calendar: .gregorianUTC,
            prior: prior
        )

        XCTAssertNil(summary.oxygenSaturation)
    }

    func testDailyHealthAggregatorDowngradesDeviceDerivedSpO2CandidateConfidence() {
        let day = Date(timeIntervalSince1970: 86_400)
        let derived = HealthSample(
            id: "r24-estimated-spo2",
            type: .oxygenSaturation,
            value: 97.5,
            unit: "%",
            startDate: day,
            endDate: nil,
            source: .whoordanEstimate,
            sourceRecordID: "r24-estimated-spo2",
            confidence: .directional,
            metadata: [
                "device_only_derivation": "true",
                "metric_policy": "r24_candidate_ble_derived_spo2",
                "verification_basis": "crc_valid_r24_frames"
            ]
        )

        let summary = DailyHealthAggregator.aggregate(
            samples: [derived],
            day: day,
            calendar: .gregorianUTC
        )

        XCTAssertEqual(summary.oxygenSaturation, 97.5)
        XCTAssertEqual(summary.oxygenSaturationSource, .whoordanEstimate)
        XCTAssertEqual(summary.oxygenSaturationConfidence, .low)
    }

    func testDailyHealthAggregatorUsesBleDerivedStepsAndSleep() {
        let day = Date(timeIntervalSince1970: 86_400)
        let steps = HealthSample(
            id: "ble-derived-steps",
            type: .steps,
            value: 18,
            unit: "count",
            startDate: day,
            endDate: nil,
            source: .whoordanEstimate,
            sourceRecordID: "ble-derived-steps",
            confidence: .low,
            metadata: [
                "device_only_derivation": "true",
                "metric_policy": "r10_imu_motion_step_estimate"
            ]
        )
        let sleep = HealthSample(
            id: "ble-derived-sleep",
            type: .sleepAnalysis,
            value: 25,
            unit: "min",
            startDate: day,
            endDate: day.addingTimeInterval(25 * 60),
            source: .whoordanEstimate,
            sourceRecordID: "ble-derived-sleep",
            confidence: .low,
            metadata: [
                "device_only_derivation": "true",
                "metric_policy": "r10_hr_imu_sleep_stage_estimate",
                "sleep_category": "4"
            ]
        )

        let summary = DailyHealthAggregator.aggregate(
            samples: [steps, sleep],
            day: day,
            goal: 10_000,
            calendar: .gregorianUTC
        )

        XCTAssertEqual(summary.movement.steps, 18)
        XCTAssertEqual(summary.movement.source, .whoordanEstimate)
        XCTAssertEqual(summary.movement.confidence, .low)
        XCTAssertEqual(summary.sleepMinutes, 25)
        XCTAssertEqual(summary.sleepSummary?.source, .whoordanEstimate)
        XCTAssertEqual(summary.sleepSummary?.stageTotals[.deep], 25)
    }

    func testDailyHealthAggregatorUsesLocalDayAndWearableDeviceOnlySources() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 86_400)
        let previousDay = Date(timeIntervalSince1970: 1_000)
        let samples = [
            sample(type: .steps, value: 3_000, source: .appleHealth, id: "old", date: previousDay),
            sample(type: .steps, value: 4_000, source: .appleHealth, id: "apple-steps", date: day),
            sample(type: .steps, value: 5_000, source: .wearableBLE, id: "wearable-steps", date: day),
            sample(type: .restingHeartRate, value: 57, source: .appleHealth, id: "rhr", date: day),
            sample(type: .wristTemperature, value: 34.4, source: .wearableBLE, id: "r10-temp", date: day),
            HealthSample(
                id: "sleep",
                type: .sleepAnalysis,
                value: 420,
                unit: "min",
                startDate: day,
                endDate: day.addingTimeInterval(420 * 60),
                source: .appleHealth,
                sourceRecordID: "sleep",
                confidence: .high,
                metadata: ["sleep_category": "1"]
            )
        ]
        let summary = DailyHealthAggregator.aggregate(samples: samples, day: day, goal: 10_000, calendar: calendar)
        XCTAssertEqual(summary.movement.steps, 5_000)
        XCTAssertEqual(summary.movement.source, .wearableBLE)
        XCTAssertNil(summary.restingHeartRate)
        XCTAssertNil(summary.sleepMinutes)
        XCTAssertNil(summary.sleepNeedMinutes)
        XCTAssertNil(summary.sleepDebtMinutes)
        XCTAssertEqual(summary.rawWristTemperatureC, 34.4)
    }

    func testDailyHealthAggregatorComputesSkinTemperatureDeviationFromActiveBaseline() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 86_400)
        let baseline = SkinTemperatureBaselineProfile(
            activeBaselineC: 34.0,
            source: .automatic,
            eligibleDayCount: 5,
            requiredDayCount: 5,
            updatedAt: day,
            automaticBaselineSetAt: day
        )
        let summary = DailyHealthAggregator.aggregate(
            samples: [
                sample(type: .wristTemperature, value: 34.6, source: .wearableBLE, id: "wrist-temp", date: day)
            ],
            day: day,
            calendar: calendar,
            skinTemperatureBaseline: baseline
        )

        XCTAssertEqual(summary.rawWristTemperatureC, 34.6)
        XCTAssertEqual(summary.bodyTemperatureDelta ?? 0, 0.6, accuracy: 0.0001)
    }

    func testDailyHealthAggregatorUsesTemperatureEventWhenWristTemperatureIsMissing() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 86_400)
        let baseline = SkinTemperatureBaselineProfile(
            activeBaselineC: 34.0,
            source: .automatic,
            eligibleDayCount: 5,
            requiredDayCount: 5,
            updatedAt: day,
            automaticBaselineSetAt: day
        )
        let summary = DailyHealthAggregator.aggregate(
            samples: [
                sample(type: .temperatureEvent, value: 34.3, source: .wearableBLE, id: "temp-event", date: day)
            ],
            day: day,
            calendar: calendar,
            skinTemperatureBaseline: baseline
        )

        XCTAssertEqual(summary.rawWristTemperatureC, 34.3)
        XCTAssertEqual(summary.rawWristTemperatureSource, .wearableBLE)
        XCTAssertEqual(summary.rawWristTemperatureConfidence, .high)
        XCTAssertEqual(summary.bodyTemperatureDelta ?? 0, 0.3, accuracy: 0.0001)
    }

    func testMetricCatalogClassifiesCurrentTruthWithoutOverclaiming() throws {
        let now = Date(timeIntervalSince1970: 86_400)
        var device = WearableDeviceState()
        device.connection = .realtime
        device.liveHeartRateBPM = 72
        device.liveHeartRateSource = "R10 realtime IMU/HR"
        device.skinTemperatureC = 34.5
        device.lastPacketAt = now
        var summary = DailyHealthSummary.empty
        summary.rawWristTemperatureC = 34.5
        summary.movement = MovementSummary(
            steps: 4,
            goal: 10_000,
            activeEnergyKilocalories: nil,
            walkingRunningDistanceMeters: nil,
            movementMinutes: nil,
            source: .whoordanEstimate,
            confidence: .low,
            lastUpdated: now,
            trendDescription: nil
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: device,
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: now
        )

        let heartRate = try XCTUnwrap(metrics.first { $0.id == .heartRate })
        XCTAssertEqual(heartRate.value, "72")
        XCTAssertEqual(heartRate.unit, "bpm")
        XCTAssertEqual(heartRate.source, .direct)
        XCTAssertEqual(heartRate.confidence, .high)
        XCTAssertEqual(heartRate.readiness, .showNow)
        XCTAssertEqual(heartRate.lastUpdated, now)
        XCTAssertEqual(heartRate.accuracySummary, "100% within 3 bpm in targeted validation")
        XCTAssertFalse(heartRate.requirements.isEmpty)

        let rawTemperature = try XCTUnwrap(metrics.first { $0.id == .rawWristTemperature })
        XCTAssertEqual(rawTemperature.value, "34.5")
        XCTAssertEqual(rawTemperature.unit, "C")
        XCTAssertEqual(rawTemperature.source, .direct)
        XCTAssertEqual(rawTemperature.confidence, .high)
        XCTAssertTrue(rawTemperature.context.contains("raw wrist/contact"))

        let steps = try XCTUnwrap(metrics.first { $0.id == .steps })
        XCTAssertEqual(steps.value, "4")
        XCTAssertEqual(steps.source, .mlEstimated)
        XCTAssertEqual(steps.confidence, .low)
        XCTAssertEqual(steps.readiness, .betaEstimated)
        XCTAssertEqual(steps.accuracySummary, "Low-confidence R10 IMU estimate")
        XCTAssertTrue(steps.accuracyDetail?.contains("needs labeled step ground truth") == true)

        let skinDelta = try XCTUnwrap(metrics.first { $0.id == .skinTemperatureDelta })
        XCTAssertEqual(skinDelta.source, .calculated)
        XCTAssertEqual(skinDelta.confidence, .blocked)
        XCTAssertTrue(skinDelta.unavailableReason?.contains("personal baseline") == true)

        let sleepDuration = try XCTUnwrap(metrics.first { $0.id == .sleepDuration })
        XCTAssertEqual(sleepDuration.source, .unavailable)
        XCTAssertEqual(sleepDuration.confidence, .blocked)
        XCTAssertEqual(sleepDuration.readiness, .laterBlocked)

        let sleepPerformance = try XCTUnwrap(metrics.first { $0.id == .sleepPerformance })
        XCTAssertEqual(sleepPerformance.source, .mlEstimated)
        XCTAssertEqual(sleepPerformance.confidence, .blocked)
        XCTAssertEqual(sleepPerformance.readiness, .laterBlocked)
        XCTAssertTrue(sleepPerformance.unavailableReason?.contains("sleep duration") == true)
        XCTAssertEqual(sleepPerformance.accuracySummary, "Blocked until sleep and need exist")
        XCTAssertFalse(sleepPerformance.requirements.isEmpty)

        let stress = try XCTUnwrap(metrics.first { $0.id == .stress })
        XCTAssertEqual(stress.source, .unavailable)
        XCTAssertEqual(stress.confidence, .blocked)
        XCTAssertEqual(stress.readiness, .laterBlocked)
        XCTAssertFalse(stress.requirements.isEmpty)

        let recovery = try XCTUnwrap(metrics.first { $0.id == .recovery })
        XCTAssertNil(recovery.value)
        XCTAssertEqual(recovery.source, .mlEstimated)
        XCTAssertEqual(recovery.confidence, .blocked)
        XCTAssertEqual(recovery.readiness, .laterBlocked)
        XCTAssertTrue(recovery.requirements.contains { $0.contains("sleep sufficiency") })

        let vo2 = try XCTUnwrap(metrics.first { $0.id == .vo2Max })
        XCTAssertNil(vo2.value)
        XCTAssertEqual(vo2.source, .unavailable)
        XCTAssertEqual(vo2.confidence, .blocked)
        XCTAssertEqual(vo2.readiness, .laterBlocked)
        XCTAssertFalse(vo2.requirements.isEmpty)
    }

    func testMetricVisibilityRegistryCoversEveryMetricAndSampleType() {
        let metricIDs = MetricVisibilityRegistry.metricEntries.compactMap(\.metricID)
        XCTAssertEqual(metricIDs.count, WhoordanMetricID.allCases.count)
        XCTAssertEqual(Set(metricIDs.map(\.rawValue)), Set(WhoordanMetricID.allCases.map(\.rawValue)))
        XCTAssertEqual(metricIDs.map(\.rawValue).count, Set(metricIDs.map(\.rawValue)).count)

        let coveredSampleTypes = Set(MetricVisibilityRegistry.entries.flatMap { $0.sampleTypes.map(\.rawValue) })
        XCTAssertEqual(coveredSampleTypes, Set(HealthSampleType.allCases.map(\.rawValue)))
        XCTAssertTrue(MetricVisibilityRegistry.entries.allSatisfy { $0.status != .unimplementedReleaseBlocker })

        for entry in MetricVisibilityRegistry.entries {
            XCTAssertFalse(entry.sourceFields.isEmpty, entry.id)
            XCTAssertFalse(entry.codeLocations.isEmpty, entry.id)
            XCTAssertFalse(entry.sourceKind.isEmpty, entry.id)
            XCTAssertFalse(entry.formulaOrDerivation.isEmpty, entry.id)
            XCTAssertFalse(entry.minimumDataRequired.isEmpty, entry.id)
            XCTAssertFalse(entry.uiDestination.isEmpty, entry.id)
            XCTAssertFalse(entry.emptyStateCopy.isEmpty, entry.id)
            XCTAssertFalse(entry.insufficientDataCopy.isEmpty, entry.id)
            XCTAssertFalse(entry.automatedTests.isEmpty, entry.id)
        }
    }

    func testMetricCatalogMatchesVisibilityRegistry() {
        let metrics = WhoordanMetricCatalog.metrics(
            summary: .empty,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: Date(timeIntervalSince1970: 86_400)
        )
        let catalogIDs = metrics.map(\.id.rawValue)
        let registryIDs = MetricVisibilityRegistry.metricEntries.compactMap { $0.metricID?.rawValue }

        XCTAssertEqual(catalogIDs.count, Set(catalogIDs).count)
        XCTAssertEqual(Set(catalogIDs), Set(registryIDs))
        XCTAssertEqual(Set(registryIDs), Set(WhoordanMetricID.allCases.map(\.rawValue)))
    }

    func testMetricCatalogKeepsUnavailableCurrentMetricsOutOfShowNow() throws {
        let now = Date(timeIntervalSince1970: 86_400)
        let metrics = WhoordanMetricCatalog.metrics(
            summary: .empty,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: now
        )

        for id in [
            WhoordanMetricID.heartRate,
            .restingHeartRate,
            .hrv,
            .rawWristTemperature,
            .dayStrain,
            .activityStrain,
            .workoutCalories
        ] {
            let metric = try XCTUnwrap(metrics.first { $0.id == id })
            XCTAssertNil(metric.value)
            XCTAssertEqual(metric.confidence, .blocked)
            XCTAssertEqual(metric.readiness, .laterBlocked)
        }

        XCTAssertEqual(metrics.first { $0.id == .heartRate }?.source, .unavailable)
        XCTAssertEqual(metrics.first { $0.id == .restingHeartRate }?.source, .unavailable)
        XCTAssertEqual(metrics.first { $0.id == .hrv }?.source, .unavailable)
        XCTAssertEqual(metrics.first { $0.id == .rawWristTemperature }?.source, .unavailable)
    }

    func testMetricCatalogBlocksStaleLivePacketMetrics() throws {
        let now = Date(timeIntervalSince1970: 1_720_001_200)
        var device = WearableDeviceState()
        device.liveHeartRateBPM = 72
        device.liveHeartRateAt = now.addingTimeInterval(-11 * 60)
        device.skinTemperatureC = 34.5
        device.skinTemperatureAt = now.addingTimeInterval(-11 * 60)
        device.lastPacketAt = now

        let metrics = WhoordanMetricCatalog.metrics(
            summary: DailyHealthSummary(date: now),
            deviceState: device,
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: now
        )

        let heartRate = try XCTUnwrap(metrics.first { $0.id == .heartRate })
        XCTAssertNil(heartRate.value)
        XCTAssertEqual(heartRate.confidence, .blocked)
        XCTAssertEqual(heartRate.readiness, .laterBlocked)
        XCTAssertTrue(heartRate.unavailableReason?.contains("stale") == true)

        let rawTemperature = try XCTUnwrap(metrics.first { $0.id == .rawWristTemperature })
        XCTAssertNil(rawTemperature.value)
        XCTAssertEqual(rawTemperature.confidence, .blocked)
        XCTAssertEqual(rawTemperature.readiness, .laterBlocked)
        XCTAssertTrue(rawTemperature.unavailableReason?.contains("stale") == true)
    }

    func testMetricCatalogShowsStoredSkinTemperatureDeltaWithoutActiveBaseline() throws {
        let now = Date(timeIntervalSince1970: 88_000)
        var summary = DailyHealthSummary.empty
        summary.rawWristTemperatureC = 34.8
        summary.bodyTemperatureDelta = 0.7

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: now
        )

        let skinDelta = try XCTUnwrap(metrics.first { $0.id == .skinTemperatureDelta })
        XCTAssertEqual(skinDelta.value, "+0.7")
        XCTAssertEqual(skinDelta.confidence, .low)
        XCTAssertEqual(skinDelta.readiness, .betaEstimated)
        XCTAssertNil(skinDelta.unavailableReason)
    }

    func testMetricCatalogRequiresBaselineBeforeShowingSkinTemperatureDelta() throws {
        let now = Date(timeIntervalSince1970: 90_000)
        var summary = DailyHealthSummary.empty
        summary.rawWristTemperatureC = 34.8
        let baseline = SkinTemperatureBaselineProfile(
            activeBaselineC: 34.1,
            source: .automatic,
            eligibleDayCount: 5,
            requiredDayCount: 5,
            updatedAt: now,
            automaticBaselineSetAt: now
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: baseline,
            now: now
        )

        let skinDelta = try XCTUnwrap(metrics.first { $0.id == .skinTemperatureDelta })
        XCTAssertEqual(skinDelta.value, "+0.7")
        XCTAssertEqual(skinDelta.unit, "C")
        XCTAssertEqual(skinDelta.source, .calculated)
        XCTAssertEqual(skinDelta.confidence, .medium)
        XCTAssertNil(skinDelta.unavailableReason)
        XCTAssertTrue(skinDelta.context.contains("5/5"))
    }

    func testMetricCatalogUsesRollingSevenDaySleepConsistencyFromSourceLabeledSessions() throws {
        let day = Date(timeIntervalSince1970: 864_000)
        let sessions = [
            sleepSession(day: day, bedtimeHour: 22.50, wakeHour: 6.50, id: "night-1", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(86_400), bedtimeHour: 22.75, wakeHour: 6.60, id: "night-2", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(2 * 86_400), bedtimeHour: 22.60, wakeHour: 6.55, id: "night-3", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(3 * 86_400), bedtimeHour: 22.70, wakeHour: 6.70, id: "night-4", source: .wearableBLE)
        ]
        var summary = DailyHealthSummary.empty
        summary.date = day.addingTimeInterval(3 * 86_400)
        summary.sleepSummary = SleepSummary(
            mainSleep: sessions.last,
            naps: [],
            sessions: Array(sessions.suffix(1)),
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: sessions.last?.end
        )
        let recentSummaries = sessions.dropLast().map { session -> DailyHealthSummary in
            var prior = DailyHealthSummary.empty
            prior.date = Calendar.gregorianUTC.startOfDay(for: session.start)
            prior.sleepSummary = SleepSummary(
                mainSleep: session,
                naps: [],
                sessions: [session],
                source: .wearableBLE,
                confidence: .high,
                lastUpdated: session.end
            )
            return prior
        }

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: recentSummaries,
            now: summary.date
        )

        let consistency = try XCTUnwrap(metrics.first { $0.id == .sleepConsistency })
        let value = try XCTUnwrap(Double(try XCTUnwrap(consistency.value)))
        XCTAssertGreaterThan(value, 90)
        XCTAssertEqual(consistency.confidence, .directional)
        XCTAssertEqual(consistency.readiness, .betaEstimated)
        XCTAssertTrue(consistency.context.contains("rolling 7-day"))
    }

    func testMetricCatalogBlocksSleepConsistencyUntilTwoSourceLabeledSessionsExist() throws {
        let day = Date(timeIntervalSince1970: 864_000)
        let sessions = [
            sleepSession(day: day, bedtimeHour: 22.50, wakeHour: 6.50, id: "night-1", source: .wearableBLE)
        ]
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.sleepSummary = SleepSummary(
            mainSleep: sessions.last,
            naps: [],
            sessions: sessions,
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: sessions.last?.end
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: [],
            now: summary.date
        )

        let consistency = try XCTUnwrap(metrics.first { $0.id == .sleepConsistency })
        XCTAssertNil(consistency.value)
        XCTAssertEqual(consistency.confidence, .blocked)
        XCTAssertEqual(consistency.readiness, .laterBlocked)
        XCTAssertTrue(consistency.requirements.contains { $0.contains("source-labeled") })
    }

    func testMetricCatalogShowsSleepConsistencyWithTwoSourceLabeledSessions() throws {
        let day = Date(timeIntervalSince1970: 864_000)
        let sessions = [
            sleepSession(day: day, bedtimeHour: 22.50, wakeHour: 6.50, id: "night-1", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(86_400), bedtimeHour: 22.75, wakeHour: 6.60, id: "night-2", source: .wearableBLE)
        ]
        var summary = DailyHealthSummary.empty
        summary.date = day.addingTimeInterval(86_400)
        summary.sleepSummary = SleepSummary(
            mainSleep: sessions.last,
            naps: [],
            sessions: Array(sessions.suffix(1)),
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: sessions.last?.end
        )
        var prior = DailyHealthSummary.empty
        prior.date = Calendar.gregorianUTC.startOfDay(for: sessions[0].start)
        prior.sleepSummary = SleepSummary(
            mainSleep: sessions[0],
            naps: [],
            sessions: [sessions[0]],
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: sessions[0].end
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: [prior],
            now: summary.date
        )

        let consistency = try XCTUnwrap(metrics.first { $0.id == .sleepConsistency })
        XCTAssertNotNil(consistency.value)
        XCTAssertEqual(consistency.confidence, .low)
        XCTAssertEqual(consistency.readiness, .betaEstimated)
        XCTAssertNil(consistency.unavailableReason)
    }

    func testMovementAggregatorDoesNotFakeStepsWithoutStepSource() {
        let day = Date(timeIntervalSince1970: 1_000)
        let samples = [
            sample(type: .wearableIMU, value: 1, source: .wearableBLE, id: "imu-1", date: day),
            sample(type: .activeEnergy, value: 120, source: .wearableBLE, id: "energy-1", date: day)
        ]
        let movement = MovementAggregator.aggregate(samples: samples, day: day)
        XCTAssertNil(movement.steps)
        XCTAssertEqual(movement.activeEnergyKilocalories, 120)
        XCTAssertNotNil(MovementAggregator.movementContributionToStrain(movement))
    }

    func testDailyHealthAggregatorComputesHeartStatsSleepRHRAndVo2() {
        let day = Date(timeIntervalSince1970: 86_400)
        let sleep = sleepSample(source: .wearableBLE, id: "sleep", start: day, minutes: 8 * 60)
        let sleepHeartRates = (0..<12).map { index in
            sample(
                type: .heartRate,
                value: Double(50 + index),
                source: .wearableBLE,
                id: "sleep-hr-\(index)",
                date: day.addingTimeInterval(Double(index) * 10 * 60)
            )
        }
        let dayHeartRates = (0..<6).map { index in
            sample(
                type: .heartRate,
                value: Double(70 + index),
                source: .wearableBLE,
                id: "day-hr-\(index)",
                date: day.addingTimeInterval(10 * 60 * 60 + Double(index) * 60)
            )
        }
        let vo2 = sample(type: .vo2Max, value: 42.4, source: .wearableBLE, id: "vo2", date: day)

        let summary = DailyHealthAggregator.aggregate(
            samples: [sleep, vo2] + sleepHeartRates + dayHeartRates,
            day: day,
            calendar: .gregorianUTC
        )

        XCTAssertEqual(summary.averageHeartRate ?? 0, 61.166, accuracy: 0.001)
        XCTAssertEqual(summary.maxHeartRate, 75)
        XCTAssertEqual(summary.heartRateSampleCount, 18)
        XCTAssertEqual(summary.heartRateCoverageMinutes ?? 0, 18, accuracy: 0.001)
        XCTAssertEqual(summary.restingHeartRate, 52)
        XCTAssertEqual(summary.restingHeartRateSource, .whoordanEstimate)
        XCTAssertEqual(summary.restingHeartRateConfidence, .directional)
        XCTAssertEqual(summary.vo2Max, 42.4)
        XCTAssertEqual(summary.vo2MaxSource, .wearableBLE)
    }

    func testDailyHealthAggregatorIgnoresContactFalseHeartRateSamples() {
        let day = Date(timeIntervalSince1970: 1_200_000)
        let offWrist = (0..<8).map { index in
            sample(
                type: .heartRate,
                value: 150,
                source: .wearableBLE,
                id: "off-wrist-hr-\(index)",
                date: day.addingTimeInterval(Double(index) * 60),
                metadata: ["contact_detected": "false"]
            )
        }

        let summary = DailyHealthAggregator.aggregate(samples: offWrist, day: day, calendar: .gregorianUTC)

        XCTAssertNil(summary.averageHeartRate)
        XCTAssertNil(summary.maxHeartRate)
        XCTAssertNil(summary.heartRateSampleCount)
        XCTAssertNil(summary.heartRateCoverageMinutes)
    }

    func testDailyHealthAggregatorClearsPriorMetricsWhenCurrentDayInputsAreMissing() {
        let day = Date(timeIntervalSince1970: 172_800)
        var prior = DailyHealthSummary.empty
        prior.date = day.addingTimeInterval(-86_400)
        prior.sleepMinutes = 430
        prior.sleepSummary = SleepSummary(
            mainSleep: sleepSession(day: prior.date, bedtimeHour: 22.5, wakeHour: 6.5, id: "prior-sleep", source: .wearableBLE),
            naps: [],
            sessions: [],
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: prior.date
        )
        prior.restingHeartRate = 54
        prior.hrv = 62
        prior.respiratoryRate = 15.2
        prior.oxygenSaturation = 97
        prior.rawWristTemperatureC = 34.5
        prior.bodyTemperatureDelta = 0.2
        prior.recovery = ScoreValue(value: 80, scale: 0...100, confidence: .high, explanation: "Prior")
        prior.strain = ScoreValue(value: 12, scale: 0...21, confidence: .high, explanation: "Prior")

        let summary = DailyHealthAggregator.aggregate(samples: [], day: day, calendar: .gregorianUTC, prior: prior)

        XCTAssertNil(summary.sleepMinutes)
        XCTAssertNil(summary.sleepSummary)
        XCTAssertNil(summary.restingHeartRate)
        XCTAssertNil(summary.hrv)
        XCTAssertNil(summary.respiratoryRate)
        XCTAssertNil(summary.oxygenSaturation)
        XCTAssertNil(summary.rawWristTemperatureC)
        XCTAssertNil(summary.bodyTemperatureDelta)
        XCTAssertNil(summary.recovery)
        XCTAssertNil(summary.strain)
    }

    func testDailyHealthAggregatorPreservesSameDayRestoredSleepWhenOnlyNonSleepSamplesArrive() {
        let day = Date(timeIntervalSince1970: 172_800)
        var prior = DailyHealthSummary.empty
        prior.date = day
        prior.sleepMinutes = 512
        prior.sleepNeedMinutes = 540
        prior.sleepDebtMinutes = 28
        prior.source = .cloudImport
        prior.confidence = .low
        let heartRate = HealthSample(
            id: "current-hr",
            type: .heartRate,
            value: 68,
            unit: "bpm",
            startDate: day.addingTimeInterval(12 * 60 * 60),
            endDate: nil,
            source: .wearableBLE,
            sourceRecordID: "current-hr",
            confidence: .high,
            metadata: [:]
        )

        let summary = DailyHealthAggregator.aggregate(
            samples: [heartRate],
            day: day,
            calendar: .gregorianUTC,
            prior: prior
        )

        XCTAssertEqual(summary.sleepMinutes, 512)
        XCTAssertEqual(summary.sleepNeedMinutes, 540)
        XCTAssertEqual(summary.sleepDebtMinutes, 28)
    }

    func testHealthSourceResolverRejectsOutOfRangeAndUnknownEstimatePolicies() {
        let day = Date(timeIntervalSince1970: 86_400)
        let unknownEstimatedSteps = HealthSample(
            id: "unknown-estimated-steps",
            type: .steps,
            value: 100,
            unit: "count",
            startDate: day,
            endDate: nil,
            source: .whoordanEstimate,
            sourceRecordID: "unknown-estimated-steps",
            confidence: .low,
            metadata: ["device_only_derivation": "true", "metric_policy": "unknown_policy"]
        )
        let movement = MovementAggregator.aggregate(samples: [unknownEstimatedSteps], day: day, calendar: .gregorianUTC)
        XCTAssertNil(movement.steps)

        let oxygen = sample(type: .oxygenSaturation, value: 120, source: .wearableBLE, id: "bad-spo2", date: day)
        XCTAssertNil(HealthSourceResolver.resolve(type: .oxygenSaturation, samples: [oxygen], now: day).value)

        let wristTemperature = sample(type: .wristTemperature, value: 60, source: .wearableBLE, id: "bad-temp", date: day)
        XCTAssertNil(HealthSourceResolver.resolve(type: .wristTemperature, samples: [wristTemperature], now: day).value)
    }

    func testDailyHealthAggregatorUsesDurationWeightedAverageHeartRateWhenAvailable() {
        let day = Date(timeIntervalSince1970: 86_400)
        let low = (0..<3).map { index in
            timedSample(
                type: .heartRate,
                value: 60,
                source: .wearableBLE,
                id: "low-\(index)",
                start: day.addingTimeInterval(Double(index) * 60),
                minutes: 1
            )
        }
        let high = (0..<3).map { index in
            timedSample(
                type: .heartRate,
                value: 120,
                source: .wearableBLE,
                id: "high-\(index)",
                start: day.addingTimeInterval(Double(10 + index * 10) * 60),
                minutes: 10
            )
        }

        let summary = DailyHealthAggregator.aggregate(samples: low + high, day: day, calendar: .gregorianUTC)

        XCTAssertEqual(summary.averageHeartRate ?? 0, 114.545, accuracy: 0.001)
        XCTAssertEqual(summary.heartRateSampleCount, 6)
    }

    func testMetricCatalogUnlocksProfileGatedEstimatesWithoutTreatingThemAsDirect() throws {
        let day = Date(timeIntervalSince1970: 864_000)
        let sessions = [
            sleepSession(day: day, bedtimeHour: 22.5, wakeHour: 6.5, id: "sleep-1", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(86_400), bedtimeHour: 22.6, wakeHour: 6.6, id: "sleep-2", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(2 * 86_400), bedtimeHour: 22.7, wakeHour: 6.7, id: "sleep-3", source: .wearableBLE)
        ]
        var summary = DailyHealthSummary.empty
        summary.date = day.addingTimeInterval(2 * 86_400)
        summary.movement = MovementSummary(
            steps: 7_500,
            goal: 10_000,
            activeEnergyKilocalories: 300,
            walkingRunningDistanceMeters: 5_000,
            movementMinutes: 45,
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: summary.date,
            trendDescription: nil
        )
        summary.sleepSummary = SleepSummary(
            mainSleep: sessions.last,
            naps: [],
            sessions: sessions,
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: sessions.last?.end
        )
        summary.sleepMinutes = 450
        summary.restingHeartRate = 58
        summary.restingHeartRateSource = .wearableBLE
        summary.restingHeartRateConfidence = .medium
        summary.hrv = 50
        summary.respiratoryRate = 16.2
        summary.oxygenSaturation = 97
        summary.bodyTemperatureDelta = 0.3
        summary.strain = ScoreValue(value: 10, scale: 0...21, confidence: .directional, explanation: "Test")
        summary.source = .wearableBLE
        let profile = BodyProfile(
            ageYears: 30,
            biologicalSex: .male,
            heightCentimeters: 180,
            weightKilograms: 80,
            configuredMaxHeartRate: 190,
            updatedAt: summary.date
        )
        let recentSummaries = (0..<7).map { index -> DailyHealthSummary in
            var prior = DailyHealthSummary.empty
            prior.date = day.addingTimeInterval(Double(index - 7) * 86_400)
            prior.hrv = 49 + Double(index % 3)
            prior.restingHeartRate = 58 + Double(index % 2)
            prior.respiratoryRate = 16 + Double(index % 2) * 0.1
            prior.movement = MovementSummary(
                steps: 6_000 + index * 100,
                goal: 10_000,
                activeEnergyKilocalories: 220 + Double(index * 5),
                walkingRunningDistanceMeters: 4_000 + Double(index * 100),
                movementMinutes: 35,
                source: .wearableBLE,
                confidence: .high,
                lastUpdated: prior.date,
                trendDescription: nil
            )
            return prior
        }

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            bodyProfile: profile,
            recentSummaries: recentSummaries,
            now: summary.date
        )

        let calories = try XCTUnwrap(metrics.first { $0.id == .dailyCalories })
        XCTAssertEqual(calories.value, "2080")
        XCTAssertEqual(calories.source, .calculated)
        XCTAssertEqual(calories.readiness, .betaEstimated)

        let zones = try XCTUnwrap(metrics.first { $0.id == .heartRateZones })
        XCTAssertEqual(zones.value, "190")
        XCTAssertEqual(zones.unit, "max bpm")
        XCTAssertEqual(zones.confidence, .medium)

        let sleepNeed = try XCTUnwrap(metrics.first { $0.id == .sleepNeed })
        XCTAssertEqual(sleepNeed.readiness, .betaEstimated)
        XCTAssertNotNil(sleepNeed.value)

        let stress = try XCTUnwrap(metrics.first { $0.id == .stress })
        XCTAssertEqual(stress.source, .calculated)
        XCTAssertEqual(stress.readiness, .betaEstimated)
        XCTAssertEqual(stress.unit, "/3")
        XCTAssertFalse(stress.requirements.isEmpty)

        let recovery = try XCTUnwrap(metrics.first { $0.id == .recovery })
        XCTAssertEqual(recovery.source, .mlEstimated)
        XCTAssertEqual(recovery.readiness, .betaEstimated)
        XCTAssertNotNil(recovery.value)

        let sleepPerformance = try XCTUnwrap(metrics.first { $0.id == .sleepPerformance })
        XCTAssertEqual(sleepPerformance.source, .mlEstimated)
        XCTAssertEqual(sleepPerformance.readiness, .betaEstimated)
        XCTAssertNotNil(sleepPerformance.value)

        let oxygen = try XCTUnwrap(metrics.first { $0.id == .spo2 })
        XCTAssertEqual(oxygen.value, "97")
        XCTAssertEqual(oxygen.readiness, .showNow)

        let vo2 = try XCTUnwrap(metrics.first { $0.id == .vo2Max })
        XCTAssertEqual(vo2.source, .calculated)
        XCTAssertEqual(vo2.readiness, .betaEstimated)
        XCTAssertEqual(vo2.value, "50.1")
    }

    func testMetricCatalogShowsMinimumDataSleepEstimatesWithLowConfidence() throws {
        let day = Date(timeIntervalSince1970: 1_296_000)
        let session = sleepSession(
            day: day,
            bedtimeHour: 22.5,
            wakeHour: 6.5,
            id: "wearable-sleep-1",
            source: .wearableBLE,
            confidence: .low
        )
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.sleepSummary = SleepSummary(
            mainSleep: session,
            naps: [],
            sessions: [session],
            source: .wearableBLE,
            confidence: .low,
            lastUpdated: session.end
        )
        summary.sleepMinutes = session.asleepMinutes

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: day
        )

        let sleepNeed = try XCTUnwrap(metrics.first { $0.id == .sleepNeed })
        XCTAssertNotNil(sleepNeed.value)
        XCTAssertEqual(sleepNeed.confidence, .low)
        XCTAssertEqual(sleepNeed.readiness, .betaEstimated)

        let sleepDebt = try XCTUnwrap(metrics.first { $0.id == .sleepDebt })
        XCTAssertNotNil(sleepDebt.value)
        XCTAssertEqual(sleepDebt.confidence, .low)
        XCTAssertEqual(sleepDebt.readiness, .betaEstimated)

        let sleepPerformance = try XCTUnwrap(metrics.first { $0.id == .sleepPerformance })
        XCTAssertNotNil(sleepPerformance.value)
        XCTAssertEqual(sleepPerformance.confidence, .low)
        XCTAssertEqual(sleepPerformance.readiness, .betaEstimated)
        XCTAssertNil(sleepPerformance.unavailableReason)
    }

    func testMetricCatalogDoesNotPromoteSleepNeedWithoutSleepData() throws {
        let day = Date(timeIntervalSince1970: 1_303_200)
        var summary = DailyHealthSummary.empty
        summary.date = day

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            now: day
        )

        let sleepDuration = try XCTUnwrap(metrics.first { $0.id == .sleepDuration })
        XCTAssertNil(sleepDuration.value)
        XCTAssertEqual(sleepDuration.readiness, .laterBlocked)

        let sleepNeed = try XCTUnwrap(metrics.first { $0.id == .sleepNeed })
        XCTAssertNil(sleepNeed.value)
        XCTAssertEqual(sleepNeed.readiness, .laterBlocked)
        XCTAssertEqual(sleepNeed.confidence, .blocked)
        XCTAssertEqual(
            sleepNeed.unavailableReason,
            "Needs a main sleep from the wearable or a source-labeled import before showing sleep need."
        )

        let sleepPerformance = try XCTUnwrap(metrics.first { $0.id == .sleepPerformance })
        XCTAssertNil(sleepPerformance.value)
        XCTAssertEqual(sleepPerformance.readiness, .laterBlocked)
    }

    func testMetricCatalogUsesPriorDebtAndPriorStrainForSleepNeedEstimate() throws {
        let day = Date(timeIntervalSince1970: 1_310_400)
        let currentSleep = sleepSession(
            day: day,
            bedtimeHour: 22.5,
            wakeHour: 6.5,
            id: "current-sleep",
            source: .wearableBLE
        )
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.sleepSummary = SleepSummary(
            mainSleep: currentSleep,
            naps: [],
            sessions: [currentSleep],
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: currentSleep.end
        )
        summary.sleepMinutes = currentSleep.asleepMinutes
        summary.strain = ScoreValue(value: 20, scale: 0...21, confidence: .medium, explanation: "Current day should not drive sleep need.")

        var prior = DailyHealthSummary.empty
        prior.date = day.addingTimeInterval(-86_400)
        prior.sleepDebtMinutes = 60
        prior.strain = ScoreValue(value: 10, scale: 0...21, confidence: .medium, explanation: "Prior strain")

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: [prior],
            now: day
        )

        let sleepNeed = try XCTUnwrap(metrics.first { $0.id == .sleepNeed })
        XCTAssertEqual(sleepNeed.value, "8h 32m")
        XCTAssertEqual(sleepNeed.confidence, .low)
    }

    func testMetricCatalogSleepPerformanceUsesSleepNeedRatioAsPrimaryFormula() throws {
        let day = Date(timeIntervalSince1970: 1_315_200)
        let sessions = [
            sleepSession(day: day.addingTimeInterval(-2 * 86_400), bedtimeHour: 22.5, wakeHour: 6.5, id: "prior-1", source: .wearableBLE),
            sleepSession(day: day.addingTimeInterval(-86_400), bedtimeHour: 22.5, wakeHour: 6.5, id: "prior-2", source: .wearableBLE),
            sleepSession(day: day, bedtimeHour: 22.5, wakeHour: 6.0, id: "current", source: .wearableBLE)
        ]
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.sleepNeedMinutes = 500
        summary.sleepSummary = SleepSummary(
            mainSleep: sessions[2],
            naps: [],
            sessions: [sessions[2]],
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: sessions[2].end
        )
        summary.sleepMinutes = 450
        let recentSummaries = sessions.prefix(2).map { session -> DailyHealthSummary in
            var prior = DailyHealthSummary.empty
            prior.date = Calendar.gregorianUTC.startOfDay(for: session.start)
            prior.sleepSummary = SleepSummary(
                mainSleep: session,
                naps: [],
                sessions: [session],
                source: .wearableBLE,
                confidence: .high,
                lastUpdated: session.end
            )
            prior.sleepMinutes = session.asleepMinutes
            return prior
        }

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: recentSummaries,
            now: day
        )

        let performance = try XCTUnwrap(metrics.first { $0.id == .sleepPerformance })
        XCTAssertEqual(performance.value, "90")
        XCTAssertNotEqual(performance.confidence, .high)
    }

    func testMetricCatalogUsesAverageHeartRateForDailyCaloriesWhenEnergyIsMissing() throws {
        let day = Date(timeIntervalSince1970: 1_320_000)
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.averageHeartRate = 100
        summary.restingHeartRate = 58
        summary.heartRateSampleCount = 120
        summary.heartRateCoverageMinutes = 120
        let profile = BodyProfile(
            ageYears: 30,
            biologicalSex: .male,
            heightCentimeters: 180,
            weightKilograms: 80,
            configuredMaxHeartRate: 190,
            updatedAt: day
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            bodyProfile: profile,
            now: day
        )

        let calories = try XCTUnwrap(metrics.first { $0.id == .dailyCalories })
        XCTAssertNotNil(calories.value)
        XCTAssertEqual(calories.confidence, .directional)
        XCTAssertTrue(calories.context.contains("heart-rate reserve"))
    }

    func testMetricCatalogUsesKeytelHeartRateCaloriesBeforeMovementMinuteFallback() throws {
        let day = Date(timeIntervalSince1970: 1_324_800)
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.averageHeartRate = 150
        summary.heartRateSampleCount = 60
        summary.movement = MovementSummary(
            steps: nil,
            goal: 10_000,
            activeEnergyKilocalories: nil,
            walkingRunningDistanceMeters: nil,
            movementMinutes: 60,
            source: .wearableBLE,
            confidence: .high,
            lastUpdated: day,
            trendDescription: nil
        )
        let profile = BodyProfile(
            ageYears: 30,
            biologicalSex: .male,
            heightCentimeters: 180,
            weightKilograms: 80,
            updatedAt: day
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            bodyProfile: profile,
            now: day
        )

        let calories = try XCTUnwrap(metrics.first { $0.id == .workoutCalories })
        XCTAssertEqual(calories.value, "882")
        XCTAssertEqual(calories.confidence, .directional)
        XCTAssertTrue(calories.context.contains("Keytel"))
    }

    func testRecoveryUsesStoredSleepNeedWithoutSleepPayload() throws {
        let day = Date(timeIntervalSince1970: 1_339_200)
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.sleepMinutes = 430
        summary.sleepNeedMinutes = 470
        summary.hrv = 62
        summary.hrvSource = .cloudImport
        summary.hrvConfidence = .medium
        summary.restingHeartRate = 55
        summary.restingHeartRateSource = .cloudImport
        summary.restingHeartRateConfidence = .medium
        summary.respiratoryRate = 15.2
        summary.respiratoryRateSource = .cloudImport
        summary.respiratoryRateConfidence = .medium
        summary.oxygenSaturation = 97
        summary.bodyTemperatureDelta = 0.1
        summary.source = .cloudImport
        summary.confidence = .medium

        let recentSummaries = (1...5).map { offset -> DailyHealthSummary in
            var prior = DailyHealthSummary.empty
            prior.date = day.addingTimeInterval(Double(-offset) * 86_400)
            prior.sleepMinutes = 420 + Double(offset)
            prior.sleepNeedMinutes = 465 + Double(offset)
            prior.hrv = 58 + Double(offset % 3)
            prior.restingHeartRate = 56 + Double(offset % 2)
            prior.respiratoryRate = 15 + (Double(offset) * 0.05)
            prior.source = .cloudImport
            prior.confidence = .medium
            return prior
        }

        XCTAssertNil(summary.sleepSummary)
        XCTAssertTrue(recentSummaries.allSatisfy { $0.sleepSummary == nil })

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: recentSummaries,
            now: day
        )

        let sleepNeed = try XCTUnwrap(metrics.first { $0.id == .sleepNeed })
        XCTAssertEqual(sleepNeed.readiness, .betaEstimated)
        XCTAssertEqual(sleepNeed.confidence, .directional)
        XCTAssertEqual(sleepNeed.value, "7h 50m")
        XCTAssertEqual(sleepNeed.calibrationSummary, "Sleep-need data days 6.")

        let recovery = try XCTUnwrap(metrics.first { $0.id == .recovery })
        XCTAssertEqual(recovery.source, .mlEstimated)
        XCTAssertEqual(recovery.readiness, .betaEstimated)
        XCTAssertNotNil(recovery.value)

        let sleepPerformance = try XCTUnwrap(metrics.first { $0.id == .sleepPerformance })
        XCTAssertEqual(sleepPerformance.readiness, .betaEstimated)
        XCTAssertNotNil(sleepPerformance.value)
    }

    func testMetricCatalogShowsMovementEstimatesFromBleDerivedStepsWithoutEnergy() throws {
        let day = Date(timeIntervalSince1970: 1_382_400)
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.movement = MovementSummary(
            steps: 6_000,
            goal: 10_000,
            activeEnergyKilocalories: nil,
            walkingRunningDistanceMeters: nil,
            movementMinutes: nil,
            source: .whoordanEstimate,
            confidence: .low,
            lastUpdated: day,
            trendDescription: nil
        )
        let profile = BodyProfile(
            ageYears: 30,
            biologicalSex: .male,
            heightCentimeters: 180,
            weightKilograms: 80,
            updatedAt: day
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            bodyProfile: profile,
            now: day
        )

        let activityStrain = try XCTUnwrap(metrics.first { $0.id == .activityStrain })
        XCTAssertNotNil(activityStrain.value)
        XCTAssertEqual(activityStrain.confidence, .low)
        XCTAssertEqual(activityStrain.readiness, .betaEstimated)

        let workoutCalories = try XCTUnwrap(metrics.first { $0.id == .workoutCalories })
        XCTAssertNotNil(workoutCalories.value)
        XCTAssertEqual(workoutCalories.source, .mlEstimated)
        XCTAssertEqual(workoutCalories.confidence, .low)

        let dailyCalories = try XCTUnwrap(metrics.first { $0.id == .dailyCalories })
        XCTAssertNotNil(dailyCalories.value)
        XCTAssertEqual(dailyCalories.confidence, .low)
    }

    func testMetricCatalogShowsVo2WithRestingAndMaxHeartRateMinimumData() throws {
        let day = Date(timeIntervalSince1970: 1_468_800)
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.restingHeartRate = 58
        summary.restingHeartRateSource = .wearableBLE
        summary.restingHeartRateConfidence = .medium
        let profile = BodyProfile(
            ageYears: 30,
            biologicalSex: .notSet,
            configuredMaxHeartRate: 190,
            updatedAt: day
        )

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            bodyProfile: profile,
            now: day
        )

        let vo2 = try XCTUnwrap(metrics.first { $0.id == .vo2Max })
        XCTAssertEqual(vo2.value, "50.1")
        XCTAssertEqual(vo2.confidence, .low)
        XCTAssertEqual(vo2.readiness, .betaEstimated)
        XCTAssertNil(vo2.unavailableReason)
    }

    func testMetricCatalogShowsRecoveryAndStressWithShortPersonalBaseline() throws {
        let day = Date(timeIntervalSince1970: 1_555_200)
        let currentSleep = sleepSession(
            day: day,
            bedtimeHour: 22.5,
            wakeHour: 6.5,
            id: "current-sleep",
            source: .wearableBLE
        )
        var summary = DailyHealthSummary.empty
        summary.date = day
        summary.hrv = 50
        summary.hrvSource = .wearableBLE
        summary.hrvConfidence = .medium
        summary.restingHeartRate = 58
        summary.restingHeartRateSource = .wearableBLE
        summary.restingHeartRateConfidence = .medium
        summary.respiratoryRate = 16.1
        summary.sleepSummary = SleepSummary(
            mainSleep: currentSleep,
            naps: [],
            sessions: [currentSleep],
            source: .wearableBLE,
            confidence: .medium,
            lastUpdated: currentSleep.end
        )
        summary.sleepMinutes = currentSleep.asleepMinutes

        var prior = DailyHealthSummary.empty
        prior.date = day.addingTimeInterval(-86_400)
        prior.hrv = 46
        prior.restingHeartRate = 61
        prior.respiratoryRate = 16.4

        let metrics = WhoordanMetricCatalog.metrics(
            summary: summary,
            deviceState: WearableDeviceState(),
            baselineProfile: SkinTemperatureBaselineProfile(),
            recentSummaries: [prior],
            now: day
        )

        let recovery = try XCTUnwrap(metrics.first { $0.id == .recovery })
        XCTAssertNotNil(recovery.value)
        XCTAssertEqual(recovery.confidence, .low)
        XCTAssertEqual(recovery.readiness, .betaEstimated)

        let stress = try XCTUnwrap(metrics.first { $0.id == .stress })
        XCTAssertNotNil(stress.value)
        XCTAssertEqual(stress.confidence, .low)
        XCTAssertEqual(stress.readiness, .betaEstimated)
    }

    private func sample(
        type: HealthSampleType,
        value: Double,
        source: DataSource,
        id: String,
        date: Date,
        metadata: [String: String] = [:],
        confidence: ConfidenceLevel = .high
    ) -> HealthSample {
        return HealthSample(
            id: id,
            type: type,
            value: value,
            unit: unit(for: type),
            startDate: date,
            endDate: nil,
            source: source,
            sourceRecordID: id,
            confidence: confidence,
            metadata: metadata
        )
    }

    private func timedSample(
        type: HealthSampleType,
        value: Double,
        source: DataSource,
        id: String,
        start: Date,
        minutes: Double
    ) -> HealthSample {
        return HealthSample(
            id: id,
            type: type,
            value: value,
            unit: unit(for: type),
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60),
            source: source,
            sourceRecordID: id,
            confidence: .high,
            metadata: [:]
        )
    }

    private func unit(for type: HealthSampleType) -> String {
        switch type {
        case .heartRate, .restingHeartRate:
            return "bpm"
        case .heartRateVariabilitySDNN, .heartRateVariabilityRMSSD:
            return "ms"
        case .oxygenSaturation:
            return "%"
        case .respiratoryRate:
            return "br/min"
        case .steps:
            return "count"
        case .activeEnergy:
            return "kcal"
        case .distanceWalkingRunning:
            return "m"
        case .bodyTemperature, .wristTemperature, .temperatureEvent:
            return "C"
        case .sleepAnalysis:
            return "min"
        case .workout:
            return "min"
        case .vo2Max:
            return "ml/kg/min"
        case .wearablePPG, .wearableIMU:
            return "raw"
        }
    }

    private func sleepSample(
        source: DataSource,
        id: String,
        start: Date,
        minutes: Double,
        category: String = "1"
    ) -> HealthSample {
        var metadata = [
            "source_label": source.label,
            "sleep_category": category
        ]
        if source == .whoordanEstimate {
            metadata["device_only_derivation"] = "true"
            metadata["metric_policy"] = "r10_hr_imu_sleep_stage_estimate"
        }
        return HealthSample(
            id: id,
            type: .sleepAnalysis,
            value: minutes,
            unit: "min",
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60),
            source: source,
            sourceRecordID: id,
            confidence: source == .whoordanEstimate ? .low : .high,
            metadata: metadata
        )
    }

    private func estimatedSleepSample(
        id: String,
        start: Date,
        minutes: Double,
        heartRate: Int,
        motionRange: Double,
        category: String = "1"
    ) -> HealthSample {
        HealthSample(
            id: id,
            type: .sleepAnalysis,
            value: minutes,
            unit: "min",
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60),
            source: .whoordanEstimate,
            sourceRecordID: id,
            confidence: .low,
            metadata: [
                "source_label": "BLE-derived R10 sleep-stage estimate",
                "device_only_derivation": "true",
                "metric_policy": "r10_hr_imu_sleep_stage_estimate",
                "sleep_category": category,
                "heart_rate_bpm": "\(heartRate)",
                "sleep_motion_normalized_range": String(format: "%.5f", motionRange),
                "sleep_gyroscope_range": "0.00"
            ]
        )
    }

    private func sleepSession(
        day: Date,
        bedtimeHour: Double,
        wakeHour: Double,
        id: String,
        source: DataSource = .appleHealth,
        confidence: ConfidenceLevel = .high
    ) -> SleepSession {
        let start = date(on: day, hour: bedtimeHour)
        let wakeDay = wakeHour <= bedtimeHour ? day.addingTimeInterval(86_400) : day
        let end = date(on: wakeDay, hour: wakeHour)
        let minutes = end.timeIntervalSince(start) / 60
        return SleepSession(
            id: id,
            start: start,
            end: end,
            asleepMinutes: minutes,
            inBedMinutes: minutes,
            efficiencyPercent: 100,
            source: source,
            confidence: confidence,
            stageSegments: []
        )
    }

    private func date(on day: Date, hour: Double) -> Date {
        let start = Calendar.gregorianUTC.startOfDay(for: day)
        return start.addingTimeInterval(hour * 60 * 60)
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
