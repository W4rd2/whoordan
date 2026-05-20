#!/usr/bin/env swift

import Foundation

struct CSVTable {
    let headers: [String]
    let rows: [[String: String]]
}

enum CSVParser {
    static func parse(_ text: String) throws -> CSVTable {
        let records = parseRecords(text).filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let headers = records.first else { throw BenchmarkError.emptyCSV }
        let cleanHeaders = headers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var rows: [[String: String]] = []
        for record in records.dropFirst() where record.count == cleanHeaders.count {
            var row: [String: String] = [:]
            for (header, value) in zip(cleanHeaders, record) {
                row[header] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            rows.append(row)
        }
        return CSVTable(headers: cleanHeaders, rows: rows)
    }

    private static func parseRecords(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var iterator = text.makeIterator()
        var inQuotes = false

        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes {
                    var lookahead = iterator
                    if let next = lookahead.next(), next == "\"" {
                        field.append("\"")
                        iterator = lookahead
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if character == "," && !inQuotes {
                record.append(field)
                field = ""
            } else if (character == "\n" || character == "\r") && !inQuotes {
                if character == "\r" {
                    var lookahead = iterator
                    if let next = lookahead.next(), next == "\n" {
                        iterator = lookahead
                    }
                }
                record.append(field)
                records.append(record)
                record = []
                field = ""
            } else {
                field.append(character)
            }
        }

        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}

enum BenchmarkError: Error {
    case emptyCSV
    case missingDirectory(String)
}

struct FileSummary {
    let name: String
    let rows: Int
    let columnsMapped: Int
    let columnsPresent: Int
    let dateRange: String
    let missingCounts: [String: Int]
}

struct ComparisonSummary {
    let rowsCompared: Int
    let correlation: Double?
    let bucketAgreement: Double?
    let lowDayDetection: Double?
}

enum Benchmark {
    static let expectedColumns: [String: [String]] = [
        "journal_entries.csv": ["Cycle start time", "Cycle end time", "Cycle timezone", "Question text", "Answered yes", "Notes"],
        "physiological_cycles.csv": ["Cycle start time", "Cycle end time", "Cycle timezone", "Recovery score %", "Resting heart rate (bpm)", "Heart rate variability (ms)", "Skin temp (celsius)", "Blood oxygen %", "Day Strain", "Energy burned (cal)", "Max HR (bpm)", "Average HR (bpm)", "Sleep onset", "Wake onset", "Sleep performance %", "Respiratory rate (rpm)", "Asleep duration (min)", "In bed duration (min)", "Light sleep duration (min)", "Deep (SWS) duration (min)", "REM duration (min)", "Awake duration (min)", "Sleep need (min)", "Sleep debt (min)", "Sleep efficiency %", "Sleep consistency %"],
        "sleeps.csv": ["Cycle start time", "Cycle end time", "Cycle timezone", "Sleep onset", "Wake onset", "Sleep performance %", "Respiratory rate (rpm)", "Asleep duration (min)", "In bed duration (min)", "Light sleep duration (min)", "Deep (SWS) duration (min)", "REM duration (min)", "Awake duration (min)", "Sleep need (min)", "Sleep debt (min)", "Sleep efficiency %", "Sleep consistency %", "Nap"],
        "workouts.csv": ["Cycle start time", "Cycle end time", "Cycle timezone", "Workout start time", "Workout end time", "Duration (min)", "Activity name", "Activity Strain", "Energy burned (cal)", "Max HR (bpm)", "Average HR (bpm)", "HR Zone 1 %", "HR Zone 2 %", "HR Zone 3 %", "HR Zone 4 %", "HR Zone 5 %", "GPS enabled"]
    ]

    static func run(directory: URL) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw BenchmarkError.missingDirectory(directory.path)
        }
        print("Whoordan private export benchmark")
        print("Privacy: aggregate-only output; no raw rows, notes, tokens, or personal values are printed.")
        print("Policy: third-party scores are comparison benchmarks only, not formulas to copy.")
        print("")

        var loaded: [String: CSVTable] = [:]
        for name in ["journal_entries.csv", "physiological_cycles.csv", "sleeps.csv", "workouts.csv"] {
            let url = directory.appendingPathComponent(name)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                print("- \(name): not found or unreadable")
                continue
            }
            let table = try CSVParser.parse(text)
            loaded[name] = table
            printSummary(summary(for: name, table: table))
        }

        if let cycles = loaded["physiological_cycles.csv"] {
            printComparison("Recovery trend", recoveryComparison(cycles: cycles))
            printComparison("Daily strain trend", strainComparison(rows: cycles.rows, strainColumn: "Day Strain"))
        }
        if let workouts = loaded["workouts.csv"] {
            printComparison("Workout strain trend", workoutStrainComparison(workouts: workouts))
        }
        if let sleeps = loaded["sleeps.csv"] {
            printSleepSummary(sleeps)
        }
        if let journal = loaded["journal_entries.csv"] {
            printJournalSummary(journal)
        }
    }

    private static func summary(for name: String, table: CSVTable) -> FileSummary {
        let expected = expectedColumns[name] ?? []
        let presentExpected = expected.filter { table.headers.contains($0) }
        let missingCounts = Dictionary(uniqueKeysWithValues: presentExpected.map { column in
            (column, table.rows.filter { ($0[column] ?? "").isEmpty }.count)
        })
        return FileSummary(
            name: name,
            rows: table.rows.count,
            columnsMapped: presentExpected.count,
            columnsPresent: table.headers.count,
            dateRange: dateRange(in: table.rows),
            missingCounts: missingCounts
        )
    }

    private static func printSummary(_ summary: FileSummary) {
        let topMissing = summary.missingCounts
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "; ")
        print("- \(summary.name): rows=\(summary.rows), columns_present=\(summary.columnsPresent), mapped_columns=\(summary.columnsMapped), date_range=\(summary.dateRange)")
        print("  missing_values_top=\(topMissing.isEmpty ? "none in mapped columns" : topMissing)")
    }

    private static func printComparison(_ title: String, _ summary: ComparisonSummary) {
        let correlation = summary.correlation.map { String(format: "%.3f", $0) } ?? "unavailable"
        let bucket = summary.bucketAgreement.map { String(format: "%.1f%%", $0 * 100) } ?? "not applicable"
        let low = summary.lowDayDetection.map { String(format: "%.1f%%", $0 * 100) } ?? "not applicable"
        print("- \(title): rows_compared=\(summary.rowsCompared), correlation=\(correlation), bucket_agreement=\(bucket), low_day_detection=\(low)")
    }

    private static func printSleepSummary(_ table: CSVTable) {
        let durationRows = table.rows.filter { number($0["Asleep duration (min)"]) != nil }.count
        let efficiencyRows = table.rows.filter { number($0["Sleep efficiency %"]) != nil }.count
        let stageRows = table.rows.filter {
            number($0["Light sleep duration (min)"]) != nil
                || number($0["Deep (SWS) duration (min)"]) != nil
                || number($0["REM duration (min)"]) != nil
        }.count
        print("- Sleep direct mapping: duration_rows=\(durationRows), efficiency_rows=\(efficiencyRows), stage_rows=\(stageRows)")
    }

    private static func printJournalSummary(_ table: CSVTable) {
        var yes = 0
        var no = 0
        var missing = 0
        for row in table.rows {
            switch (row["Answered yes"] ?? "").lowercased() {
            case "yes", "true", "1":
                yes += 1
            case "no", "false", "0":
                no += 1
            default:
                missing += 1
            }
        }
        print("- Journal habit mapping: yes_rows=\(yes), no_rows=\(no), missing_answer_rows=\(missing), notes_redacted=true")
    }

    private static func recoveryComparison(cycles: CSVTable) -> ComparisonSummary {
        var wearable: [Double] = []
        var whoordan: [Double] = []
        for row in cycles.rows {
            guard let exported = number(row["Recovery score %"]),
                  let estimated = recoveryEstimate(row: row) else { continue }
            wearable.append(exported)
            whoordan.append(estimated)
        }
        let agreement = bucketAgreement(left: wearable, right: whoordan, bucket: recoveryBucket)
        let lowDetection = lowDayDetection(reference: wearable, estimate: whoordan)
        return ComparisonSummary(rowsCompared: wearable.count, correlation: pearson(wearable, whoordan), bucketAgreement: agreement, lowDayDetection: lowDetection)
    }

    private static func strainComparison(rows: [[String: String]], strainColumn: String) -> ComparisonSummary {
        var exportedScores: [Double] = []
        var estimates: [Double] = []
        for row in rows {
            guard let exported = number(row[strainColumn]),
                  let estimated = strainEstimate(row: row, durationColumn: nil) else { continue }
            exportedScores.append(exported)
            estimates.append(estimated)
        }
        return ComparisonSummary(rowsCompared: exportedScores.count, correlation: pearson(exportedScores, estimates), bucketAgreement: nil, lowDayDetection: nil)
    }

    private static func workoutStrainComparison(workouts: CSVTable) -> ComparisonSummary {
        var exportedScores: [Double] = []
        var estimates: [Double] = []
        for row in workouts.rows {
            guard let exported = number(row["Activity Strain"]),
                  let estimated = strainEstimate(row: row, durationColumn: "Duration (min)") else { continue }
            exportedScores.append(exported)
            estimates.append(estimated)
        }
        return ComparisonSummary(rowsCompared: exportedScores.count, correlation: pearson(exportedScores, estimates), bucketAgreement: nil, lowDayDetection: nil)
    }

    private static func recoveryEstimate(row: [String: String]) -> Double? {
        var weighted = 0.0
        var weight = 0.0
        add(&weighted, &weight, positiveRatio(value: number(row["Heart rate variability (ms)"]), baseline: 55), weight: 0.25)
        add(&weighted, &weight, inverseRatio(value: number(row["Resting heart rate (bpm)"]), baseline: 58), weight: 0.20)
        add(&weighted, &weight, sleepScore(minutes: number(row["Asleep duration (min)"]), need: number(row["Sleep need (min)"])), weight: 0.25)
        add(&weighted, &weight, centered(value: number(row["Respiratory rate (rpm)"]), baseline: 15, tolerance: 3), weight: 0.15)
        add(&weighted, &weight, temperatureScore(number(row["Skin temp (celsius)"])), weight: 0.15)
        guard weight > 0 else { return nil }
        return clamp(weighted / weight, 0, 100)
    }

    private static func strainEstimate(row: [String: String], durationColumn: String?) -> Double? {
        let duration = durationColumn.flatMap { number(row[$0]) } ?? 30
        let avgHR = number(row["Average HR (bpm)"])
        let maxHR = number(row["Max HR (bpm)"])
        let energy = number(row["Energy burned (cal)"])
        let zoneLoad = (1...5).reduce(0.0) { partial, zone in
            partial + Double(zone) * (number(row["HR Zone \(zone) %"]) ?? 0) * max(duration, 1) / 100.0
        }
        let hrLoad: Double
        if let avgHR, let maxHR, maxHR > 0 {
            hrLoad = max(0, (avgHR / maxHR) - 0.45) * duration * 2.2
        } else {
            hrLoad = 0
        }
        let energyLoad = energy.map { min($0 / 700, 1.5) * 9 } ?? 0
        let load = zoneLoad + hrLoad + duration * 0.08 + energyLoad
        guard load > 0 else { return nil }
        return clamp(21 * (1 - exp(-load / 95)), 0, 21)
    }

    private static func dateRange(in rows: [[String: String]]) -> String {
        let columns = ["Cycle start time", "Workout start time", "Sleep onset"]
        let dates = rows.compactMap { row in
            columns.compactMap { parseDate(row[$0]) }.first
        }.sorted()
        guard let first = dates.first, let last = dates.last else { return "unavailable" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: first))...\(formatter.string(from: last))"
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss ZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func number(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    private static func pearson(_ left: [Double], _ right: [Double]) -> Double? {
        guard left.count == right.count, left.count >= 3 else { return nil }
        let leftMean = left.reduce(0, +) / Double(left.count)
        let rightMean = right.reduce(0, +) / Double(right.count)
        var numerator = 0.0
        var leftDenominator = 0.0
        var rightDenominator = 0.0
        for (leftValue, rightValue) in zip(left, right) {
            let leftDelta = leftValue - leftMean
            let rightDelta = rightValue - rightMean
            numerator += leftDelta * rightDelta
            leftDenominator += leftDelta * leftDelta
            rightDenominator += rightDelta * rightDelta
        }
        guard leftDenominator > 0, rightDenominator > 0 else { return nil }
        return numerator / sqrt(leftDenominator * rightDenominator)
    }

    private static func bucketAgreement(left: [Double], right: [Double], bucket: (Double) -> String) -> Double? {
        guard left.count == right.count, !left.isEmpty else { return nil }
        let matching = zip(left, right).filter { bucket($0) == bucket($1) }.count
        return Double(matching) / Double(left.count)
    }

    private static func lowDayDetection(reference: [Double], estimate: [Double]) -> Double? {
        let paired = zip(reference, estimate).filter { recoveryBucket($0.0) == "low" }
        guard !paired.isEmpty else { return nil }
        let detected = paired.filter { recoveryBucket($0.1) == "low" || recoveryBucket($0.1) == "medium" }.count
        return Double(detected) / Double(paired.count)
    }

    private static func recoveryBucket(_ value: Double) -> String {
        if value < 34 { return "low" }
        if value < 67 { return "medium" }
        return "high"
    }

    private static func add(_ weighted: inout Double, _ totalWeight: inout Double, _ score: Double?, weight: Double) {
        guard let score else { return }
        weighted += clamp(score, 0, 100) * weight
        totalWeight += weight
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

    private static func temperatureScore(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return 100 - min(abs(value) / 1.2, 1) * 80
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

let arguments = CommandLine.arguments.dropFirst()
let firstArgument = arguments.first
guard let first = firstArgument, first != "--help" else {
    print("Usage: swift Tools/WhoordanBenchmark/WhoordanBenchmark.swift <directory-containing-private-export-csvs>")
    print("Reads CSV exports locally and prints aggregate-only benchmark summaries.")
    exit(firstArgument == nil ? 1 : 0)
}

do {
    try Benchmark.run(directory: URL(fileURLWithPath: first, isDirectory: true))
} catch {
    fputs("Benchmark failed: \(error)\n", stderr)
    exit(1)
}
