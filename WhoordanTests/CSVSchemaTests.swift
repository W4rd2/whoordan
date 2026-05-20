import XCTest
@testable import Whoordan

final class CSVSchemaTests: XCTestCase {
    func testProvidedSchemaHeadersAreValidatedWithoutPrivateRows() {
        let validator = PrivateCSVSchemaValidator()
        for kind in PrivateCSVKind.allCases {
            XCTAssertTrue(validator.validate(headers: kind.requiredColumns, kind: kind).isEmpty)
        }
    }

    func testMissingHeaderIsReported() {
        let validator = PrivateCSVSchemaValidator()
        let headers = PrivateCSVKind.workouts.requiredColumns.filter { $0 != "Workout start time" }
        XCTAssertEqual(validator.validate(headers: headers, kind: .workouts), ["Workout start time"])
    }

    func testProprietaryScoresAreIntentionallyIgnored() {
        XCTAssertTrue(PrivateCSVKind.physiologicalCycles.intentionallyIgnoredColumns.contains("Recovery score %"))
        XCTAssertTrue(PrivateCSVKind.workouts.intentionallyIgnoredColumns.contains("Activity Strain"))
    }

    func testBenchmarkParserHandlesQuotedSyntheticFixturesWithoutPrivateRows() throws {
        let csv = """
        Cycle start time,Cycle end time,Cycle timezone,Question text,Answered yes,Notes
        2026-01-01,2026-01-02,UTC,"Caffeine, late",yes,"synthetic note, not private"
        2026-01-02,2026-01-03,UTC,Hydration,no,
        """
        let table = try PrivateCSVParser.parse(csv)
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows.first?["Question text"], "Caffeine, late")
        XCTAssertEqual(table.rows.first?["Notes"], "synthetic note, not private")
    }

    func testBenchmarkSummaryReportsAggregateOnlyCounts() throws {
        let headers = PrivateCSVKind.physiologicalCycles.requiredColumns.joined(separator: ",")
        let values = PrivateCSVKind.physiologicalCycles.requiredColumns.map { column in
            switch column {
            case "Recovery score %": return "72"
            case "Resting heart rate (bpm)": return "58"
            case "Heart rate variability (ms)": return "64"
            case "Sleep need (min)": return ""
            default: return "1"
            }
        }.joined(separator: ",")
        let summary = try PrivateWearableBenchmarkMapper.summarize(csvText: "\(headers)\n\(values)\n", kind: .physiologicalCycles)
        XCTAssertEqual(summary.rowCount, 1)
        XCTAssertEqual(summary.mappedColumns.count, PrivateCSVKind.physiologicalCycles.requiredColumns.count)
        XCTAssertEqual(summary.missingValueCounts["Sleep need (min)"], 1)
        XCTAssertTrue(summary.ignoredColumns.contains("Recovery score %"))
    }

    func testJournalHabitMappingPreservesYesNoDistinction() throws {
        let csv = """
        Cycle start time,Cycle end time,Cycle timezone,Question text,Answered yes,Notes
        2026-01-01,2026-01-02,UTC,Caffeine,yes,
        2026-01-02,2026-01-03,UTC,Caffeine,no,
        2026-01-03,2026-01-04,UTC,Caffeine,,
        """
        let counts = try PrivateWearableBenchmarkMapper.journalHabitCounts(csvText: csv)
        XCTAssertEqual(counts.yes, 1)
        XCTAssertEqual(counts.no, 1)
        XCTAssertEqual(counts.missing, 1)
    }

    func testBenchmarkMathPearsonUsesAggregateArraysOnly() throws {
        let correlation = try XCTUnwrap(PrivateBenchmarkMath.pearson([1, 2, 3], [2, 4, 6]))
        XCTAssertEqual(correlation, 1, accuracy: 0.0001)
        XCTAssertEqual(PrivateBenchmarkMath.recoveryBucket(20), "low")
        XCTAssertEqual(PrivateBenchmarkMath.recoveryBucket(50), "medium")
        XCTAssertEqual(PrivateBenchmarkMath.recoveryBucket(80), "high")
    }

    func testBenchmarkMathSpearmanAndRollingBaselineUseSyntheticValuesOnly() throws {
        let spearman = try XCTUnwrap(PrivateBenchmarkMath.spearman([10, 20, 30], [1, 2, 3]))
        XCTAssertEqual(spearman, 1, accuracy: 0.0001)

        let baseline = PrivateBenchmarkMath.rollingBaseline([10, 20, 30, 40], window: 3, minimumCount: 2)
        XCTAssertNil(baseline[0])
        XCTAssertNil(baseline[1])
        XCTAssertEqual(try XCTUnwrap(baseline[2]), 15, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(baseline[3]), 20, accuracy: 0.0001)
    }

    func testCandidateRecoveryFormulaIsExplainableAndBaselineRelative() throws {
        let higherHRV = try XCTUnwrap(PrivateBenchmarkMath.candidateRecoveryScore(
            hrv: 70,
            hrvBaseline: 55,
            restingHeartRate: 56,
            restingHeartRateBaseline: 58,
            sleepMinutes: 450,
            sleepNeedMinutes: 480,
            respiratoryRate: 15,
            respiratoryRateBaseline: 15,
            temperatureDelta: 0
        ))
        let lowerHRV = try XCTUnwrap(PrivateBenchmarkMath.candidateRecoveryScore(
            hrv: 40,
            hrvBaseline: 55,
            restingHeartRate: 56,
            restingHeartRateBaseline: 58,
            sleepMinutes: 450,
            sleepNeedMinutes: 480,
            respiratoryRate: 15,
            respiratoryRateBaseline: 15,
            temperatureDelta: 0
        ))
        XCTAssertGreaterThan(higherHRV, lowerHRV)
    }

    func testBucketAgreementUsesAggregateBucketsOnly() throws {
        let agreement = try XCTUnwrap(PrivateBenchmarkMath.bucketAgreement(
            actual: [20, 50, 80],
            predicted: [25, 55, 90],
            bucket: PrivateBenchmarkMath.recoveryBucket
        ))
        XCTAssertEqual(agreement, 1, accuracy: 0.0001)
        XCTAssertEqual(PrivateBenchmarkMath.strainBucket(5), "low")
        XCTAssertEqual(PrivateBenchmarkMath.strainBucket(12), "moderate")
        XCTAssertEqual(PrivateBenchmarkMath.strainBucket(16), "high")
        XCTAssertEqual(PrivateBenchmarkMath.strainBucket(19), "veryHigh")
    }
}
