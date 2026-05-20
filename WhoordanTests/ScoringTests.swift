import XCTest
@testable import Whoordan

final class ScoringTests: XCTestCase {
    private let hrvBaseline = 55.0
    private let restingHeartRateBaseline = 58.0
    private let respiratoryRateBaseline = 15.0

    func testRecoveryUsesAvailableSignalsWithoutImputingMissingInputs() {
        let service = WhoordanScoringService()
        let result = service.recovery(inputs: RecoveryInputs(
            hrv: 68,
            hrvBaseline: 55,
            restingHeartRate: nil,
            restingHeartRateBaseline: 58,
            sleepMinutes: 470,
            sleepNeedMinutes: 450,
            respiratoryRate: nil,
            respiratoryRateBaseline: 15,
            temperatureDelta: nil
        ))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.confidence, .medium)
        XCTAssertTrue((0...100).contains(result!.value))
        XCTAssertTrue(result!.explanation.lowercased().contains("not medical"))
    }

    func testRecoveryExplainerKeepsSpO2AsContextOnlyContributor() throws {
        let contributors = RecoveryExplainer.contributors(inputs: RecoveryInputs(
            hrv: 68,
            hrvBaseline: hrvBaseline,
            restingHeartRate: 56,
            restingHeartRateBaseline: restingHeartRateBaseline,
            sleepMinutes: 450,
            sleepNeedMinutes: 480,
            respiratoryRate: 15,
            respiratoryRateBaseline: respiratoryRateBaseline,
            temperatureDelta: 0.2,
            oxygenSaturation: 97
        ))
        let weights = Dictionary(uniqueKeysWithValues: contributors.map { ($0.kind, $0.weight) })
        let oxygen = try XCTUnwrap(contributors.first { $0.kind == .oxygenSaturation })

        XCTAssertEqual(try XCTUnwrap(weights[.hrv]), 0.35, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(weights[.restingHeartRate]), 0.20, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(weights[.sleepSufficiency]), 0.17, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(weights[.respiratoryFit]), 0.20, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(weights[.temperatureDeviation]), 0.08, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(weights[.oxygenSaturation]), 0.0, accuracy: 0.0001)
        XCTAssertEqual(RecoveryContributorKind.allCases.count, 6)
        XCTAssertEqual(oxygen.value, 97)
        XCTAssertNotNil(oxygen.componentScore)
        XCTAssertFalse(RecoveryContributorKind.allCases.map(\.rawValue).contains("previousDayStrain"))
    }

    func testRecoveryScoreDoesNotUseNormalSpO2AsPositiveBooster() throws {
        let withoutOxygen = try XCTUnwrap(RecoveryExplainer.score(inputs: RecoveryInputs(
            hrv: 48,
            hrvBaseline: hrvBaseline,
            restingHeartRate: 64,
            restingHeartRateBaseline: restingHeartRateBaseline,
            sleepMinutes: 390,
            sleepNeedMinutes: 480,
            respiratoryRate: 16,
            respiratoryRateBaseline: respiratoryRateBaseline,
            temperatureDelta: 0.3
        )))
        let withMeasuredOxygen = try XCTUnwrap(RecoveryExplainer.score(inputs: RecoveryInputs(
            hrv: 48,
            hrvBaseline: hrvBaseline,
            restingHeartRate: 64,
            restingHeartRateBaseline: restingHeartRateBaseline,
            sleepMinutes: 390,
            sleepNeedMinutes: 480,
            respiratoryRate: 16,
            respiratoryRateBaseline: respiratoryRateBaseline,
            temperatureDelta: 0.3,
            oxygenSaturation: 99
        )))

        XCTAssertEqual(withMeasuredOxygen.value, withoutOxygen.value, accuracy: 0.0001)
        XCTAssertEqual(withMeasuredOxygen.confidence, .high)
    }

    func testRecoveryDoesNotUseMeasuredSpO2AsOnlySignal() {
        let result = RecoveryExplainer.score(inputs: RecoveryInputs(
            hrv: nil,
            hrvBaseline: hrvBaseline,
            restingHeartRate: nil,
            restingHeartRateBaseline: restingHeartRateBaseline,
            sleepMinutes: nil,
            sleepNeedMinutes: 480,
            respiratoryRate: nil,
            respiratoryRateBaseline: respiratoryRateBaseline,
            temperatureDelta: nil,
            oxygenSaturation: 97
        ))

        XCTAssertNil(result)
    }

    func testRecoveryExplainerReportsMissingContributorConfidence() throws {
        let result = try XCTUnwrap(RecoveryExplainer.score(inputs: RecoveryInputs(
            hrv: 70,
            hrvBaseline: hrvBaseline,
            restingHeartRate: nil,
            restingHeartRateBaseline: restingHeartRateBaseline,
            sleepMinutes: nil,
            sleepNeedMinutes: 480,
            respiratoryRate: nil,
            respiratoryRateBaseline: respiratoryRateBaseline,
            temperatureDelta: nil
        )))

        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(RecoveryExplainer.category(for: result.value).isEmpty, false)
    }

    func testScoreDoesNotComputeRecoveryWithoutPersonalBaselines() {
        let service = WhoordanScoringService()
        var summary = DailyHealthSummary.empty
        summary.hrv = 62
        summary.restingHeartRate = 55
        summary.sleepMinutes = 440
        summary.sleepNeedMinutes = 470
        summary.respiratoryRate = 15.8
        summary.bodyTemperatureDelta = 0.2

        let scored = service.score(summary: summary)

        XCTAssertNil(scored.recovery)
    }

    func testScoreUsesHeartRateCoverageMinutesInsteadOfSampleCountForStrainDuration() {
        let service = WhoordanScoringService()
        var summary = DailyHealthSummary.empty
        summary.averageHeartRate = 135
        summary.maxHeartRate = 165
        summary.restingHeartRate = 58
        summary.heartRateSampleCount = 120

        XCTAssertNil(service.score(summary: summary).strain)

        summary.heartRateCoverageMinutes = 45
        XCTAssertNotNil(service.score(summary: summary).strain)
    }

    func testStrainSaturatesToTwentyOneScale() {
        let service = WhoordanScoringService()
        let result = service.strain(inputs: StrainInputs(
            activeMinutes: 120,
            averageHeartRate: 160,
            maxHeartRate: 190,
            configuredMaxHeartRate: 190,
            zoneMinutes: [3: 30, 4: 30, 5: 20]
        ))
        XCTAssertNotNil(result)
        XCTAssertTrue((0...21).contains(result!.value))
    }

    func testDayStrainUsesAlignedCardioAndMuscularActivityLoadWithBetaProvenance() throws {
        let service = WhoordanScoringService()
        let result = try XCTUnwrap(service.strain(inputs: StrainInputs(
            activeMinutes: 45,
            averageHeartRate: 100,
            maxHeartRate: 160,
            configuredMaxHeartRate: 190,
            zoneMinutes: [4: 20, 5: 10],
            muscularMinutes: 30,
            muscularActivitySourceConfidence: .high
        )))

        let restingHeartRate = 60.0
        let maxHeartRate = 190.0
        let reserveSpan = maxHeartRate - restingHeartRate
        let averageReserve = max(0, min((100 - restingHeartRate) / reserveSpan, 1))
        let peakReserve = max(0, min((160 - restingHeartRate) / reserveSpan, 1))
        let activeMinutes = 45.0
        let allDayCardioLoad = activeMinutes * pow(averageReserve, 1.8) * 0.055
        let peakCardioLoad = min(activeMinutes, 30) * pow(peakReserve, 2)
        let zoneLoad = 20 * 5.0 + 10 * 8.0
        let muscularLoad = 30 * 2.5
        let expected = 21 * (1 - exp(-(allDayCardioLoad + peakCardioLoad + zoneLoad + muscularLoad) / 180))

        XCTAssertEqual(result.value, expected, accuracy: 0.001)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertTrue(result.explanation.contains("Beta"))
        XCTAssertTrue(result.explanation.contains("cardio"))
        XCTAssertTrue(result.explanation.contains("muscular"))
        XCTAssertTrue(result.explanation.contains("source-labeled"))
    }

    func testDayStrainScalesCardioLoadByActiveDuration() throws {
        let service = WhoordanScoringService()
        let short = try XCTUnwrap(service.strain(inputs: StrainInputs(
            activeMinutes: 15,
            averageHeartRate: 135,
            maxHeartRate: 165,
            configuredMaxHeartRate: 190,
            zoneMinutes: [:]
        )))
        let long = try XCTUnwrap(service.strain(inputs: StrainInputs(
            activeMinutes: 120,
            averageHeartRate: 135,
            maxHeartRate: 165,
            configuredMaxHeartRate: 190,
            zoneMinutes: [:]
        )))

        XCTAssertGreaterThan(long.value, short.value)
    }

    func testDayStrainUsesPersonalRestingHeartRateWhenAvailable() throws {
        let service = WhoordanScoringService()
        let defaultResting = try XCTUnwrap(service.strain(inputs: StrainInputs(
            activeMinutes: 60,
            averageHeartRate: 120,
            maxHeartRate: 160,
            configuredMaxHeartRate: 190,
            zoneMinutes: [:]
        )))
        let personalResting = try XCTUnwrap(service.strain(inputs: StrainInputs(
            activeMinutes: 60,
            averageHeartRate: 120,
            maxHeartRate: 160,
            configuredMaxHeartRate: 190,
            zoneMinutes: [:],
            restingHeartRate: 50
        )))

        XCTAssertGreaterThan(personalResting.value, defaultResting.value)
    }

    func testMovementCanContributeToLowConfidenceStrainWhenSourceIsValid() throws {
        let service = WhoordanScoringService()
        let result = try XCTUnwrap(service.strain(inputs: StrainInputs(
            activeMinutes: 0,
            averageHeartRate: nil,
            maxHeartRate: nil,
            configuredMaxHeartRate: nil,
            zoneMinutes: [:],
            steps: 8_000,
            stepGoal: 10_000,
            activeEnergyKilocalories: 220,
            movementConfidence: .high
        )))
        XCTAssertGreaterThan(result.value, 0)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.explanation.contains("source-labeled"))
    }

    func testStrainDoesNotInferCardioLoadWithoutHeartRateIntensityOrMovementSource() {
        let service = WhoordanScoringService()
        let result = service.strain(inputs: StrainInputs(
            activeMinutes: 45,
            averageHeartRate: nil,
            maxHeartRate: nil,
            configuredMaxHeartRate: nil,
            zoneMinutes: [:],
            steps: nil,
            stepGoal: nil,
            activeEnergyKilocalories: nil,
            movementConfidence: .unavailable
        ))

        XCTAssertNil(result)
    }

    func testMovementDoesNotCreateStrainWithoutAValidSource() {
        let service = WhoordanScoringService()
        let result = service.strain(inputs: StrainInputs(
            activeMinutes: 0,
            averageHeartRate: nil,
            maxHeartRate: nil,
            configuredMaxHeartRate: nil,
            zoneMinutes: [:],
            steps: 12_000,
            stepGoal: 10_000,
            activeEnergyKilocalories: nil,
            movementConfidence: .unavailable
        ))
        XCTAssertNil(result)
    }
}
