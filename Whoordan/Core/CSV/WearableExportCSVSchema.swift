import Foundation

enum PrivateCSVKind: String, CaseIterable {
    case journalEntries = "journal_entries.csv"
    case physiologicalCycles = "physiological_cycles.csv"
    case sleeps = "sleeps.csv"
    case workouts = "workouts.csv"

    var requiredColumns: [String] {
        switch self {
        case .journalEntries:
            return ["Cycle start time", "Cycle end time", "Cycle timezone", "Question text", "Answered yes", "Notes"]
        case .physiologicalCycles:
            return ["Cycle start time", "Cycle end time", "Cycle timezone", "Recovery score %", "Resting heart rate (bpm)", "Heart rate variability (ms)", "Skin temp (celsius)", "Blood oxygen %", "Day Strain", "Energy burned (cal)", "Max HR (bpm)", "Average HR (bpm)", "Sleep onset", "Wake onset", "Sleep performance %", "Respiratory rate (rpm)", "Asleep duration (min)", "In bed duration (min)", "Light sleep duration (min)", "Deep (SWS) duration (min)", "REM duration (min)", "Awake duration (min)", "Sleep need (min)", "Sleep debt (min)", "Sleep efficiency %", "Sleep consistency %"]
        case .sleeps:
            return ["Cycle start time", "Cycle end time", "Cycle timezone", "Sleep onset", "Wake onset", "Sleep performance %", "Respiratory rate (rpm)", "Asleep duration (min)", "In bed duration (min)", "Light sleep duration (min)", "Deep (SWS) duration (min)", "REM duration (min)", "Awake duration (min)", "Sleep need (min)", "Sleep debt (min)", "Sleep efficiency %", "Sleep consistency %", "Nap"]
        case .workouts:
            return ["Cycle start time", "Cycle end time", "Cycle timezone", "Workout start time", "Workout end time", "Duration (min)", "Activity name", "Activity Strain", "Energy burned (cal)", "Max HR (bpm)", "Average HR (bpm)", "HR Zone 1 %", "HR Zone 2 %", "HR Zone 3 %", "HR Zone 4 %", "HR Zone 5 %", "GPS enabled"]
        }
    }

    var intentionallyIgnoredColumns: [String] {
        ["Recovery score %", "Day Strain", "Activity Strain", "Sleep performance %", "Sleep need (min)", "Sleep debt (min)"]
    }
}

struct PrivateCSVSchemaValidator {
    func validate(headers: [String], kind: PrivateCSVKind) -> [String] {
        let headerSet = Set(headers)
        return kind.requiredColumns.filter { !headerSet.contains($0) }
    }
}

struct PrivateCSVTable: Equatable {
    let headers: [String]
    let rows: [[String: String]]
}

enum PrivateCSVParserError: Error, Equatable {
    case emptyFile
    case unevenRow(row: Int, expected: Int, actual: Int)
}

enum PrivateCSVParser {
    static func parse(_ text: String) throws -> PrivateCSVTable {
        let records = parseRecords(text)
            .filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let headers = records.first else { throw PrivateCSVParserError.emptyFile }
        let cleanHeaders = headers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var rows: [[String: String]] = []
        for (index, record) in records.dropFirst().enumerated() {
            guard record.count == cleanHeaders.count else {
                throw PrivateCSVParserError.unevenRow(row: index + 2, expected: cleanHeaders.count, actual: record.count)
            }
            var row: [String: String] = [:]
            for (header, value) in zip(cleanHeaders, record) {
                row[header] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            rows.append(row)
        }
        return PrivateCSVTable(headers: cleanHeaders, rows: rows)
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

struct PrivateBenchmarkFileSummary: Equatable {
    let kind: PrivateCSVKind
    let rowCount: Int
    let mappedColumns: [String]
    let missingValueCounts: [String: Int]
    let ignoredColumns: [String]
}

enum PrivateWearableBenchmarkMapper {
    static func summarize(csvText: String, kind: PrivateCSVKind) throws -> PrivateBenchmarkFileSummary {
        let table = try PrivateCSVParser.parse(csvText)
        let mapped = kind.requiredColumns.filter { table.headers.contains($0) }
        let missingCounts = Dictionary(uniqueKeysWithValues: mapped.map { column in
            (column, table.rows.filter { ($0[column] ?? "").isEmpty }.count)
        })
        return PrivateBenchmarkFileSummary(
            kind: kind,
            rowCount: table.rows.count,
            mappedColumns: mapped,
            missingValueCounts: missingCounts,
            ignoredColumns: kind.intentionallyIgnoredColumns.filter { table.headers.contains($0) }
        )
    }

    static func journalHabitCounts(csvText: String) throws -> (yes: Int, no: Int, missing: Int) {
        let table = try PrivateCSVParser.parse(csvText)
        return table.rows.reduce(into: (yes: 0, no: 0, missing: 0)) { partial, row in
            switch (row["Answered yes"] ?? "").lowercased() {
            case "true", "yes", "1":
                partial.yes += 1
            case "false", "no", "0":
                partial.no += 1
            default:
                partial.missing += 1
            }
        }
    }
}

enum PrivateBenchmarkMath {
    static func pearson(_ left: [Double], _ right: [Double]) -> Double? {
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

    static func spearman(_ left: [Double], _ right: [Double]) -> Double? {
        guard left.count == right.count, left.count >= 3 else { return nil }
        return pearson(ranks(left), ranks(right))
    }

    static func rollingBaseline(_ values: [Double?], window: Int, minimumCount: Int = 3) -> [Double?] {
        guard window > 0, minimumCount > 0 else { return values.map { _ in nil } }
        return values.indices.map { index in
            let lowerBound = max(0, index - window)
            let history = values[lowerBound..<index].compactMap { $0 }
            guard history.count >= minimumCount else { return nil }
            return history.reduce(0, +) / Double(history.count)
        }
    }

    static func candidateRecoveryScore(
        hrv: Double?,
        hrvBaseline: Double?,
        restingHeartRate: Double?,
        restingHeartRateBaseline: Double?,
        sleepMinutes: Double?,
        sleepNeedMinutes: Double?,
        respiratoryRate: Double?,
        respiratoryRateBaseline: Double?,
        temperatureDelta: Double?
    ) -> Double? {
        var weighted = 0.0
        var weight = 0.0
        add(&weighted, &weight, positiveRatio(value: hrv, baseline: hrvBaseline), 0.35)
        add(&weighted, &weight, inverseRatio(value: restingHeartRate, baseline: restingHeartRateBaseline), 0.20)
        add(&weighted, &weight, sleepScore(minutes: sleepMinutes, need: sleepNeedMinutes), 0.17)
        add(&weighted, &weight, centered(value: respiratoryRate, baseline: respiratoryRateBaseline, tolerance: 2), 0.20)
        add(&weighted, &weight, temperatureScore(delta: temperatureDelta), 0.08)
        guard weight > 0 else { return nil }
        return clamp(weighted / weight, 0, 100)
    }

    static func recoveryBucket(_ value: Double) -> String {
        if value < 34 { return "low" }
        if value < 67 { return "medium" }
        return "high"
    }

    static func strainBucket(_ value: Double) -> String {
        if value < 7 { return "low" }
        if value < 14 { return "moderate" }
        if value < 18 { return "high" }
        return "veryHigh"
    }

    static func bucketAgreement(
        actual: [Double],
        predicted: [Double],
        bucket: (Double) -> String
    ) -> Double? {
        guard actual.count == predicted.count, actual.count >= 1 else { return nil }
        let matches = zip(actual, predicted).filter { bucket($0.0) == bucket($0.1) }.count
        return Double(matches) / Double(actual.count)
    }

    private static func ranks(_ values: [Double]) -> [Double] {
        let sorted = values.enumerated().sorted { $0.element < $1.element }
        var ranks = Array(repeating: 0.0, count: values.count)
        var index = 0
        while index < sorted.count {
            var end = index
            while end + 1 < sorted.count, sorted[end + 1].element == sorted[index].element {
                end += 1
            }
            let averageRank = (Double(index + 1) + Double(end + 1)) / 2.0
            for sortedIndex in index...end {
                ranks[sorted[sortedIndex].offset] = averageRank
            }
            index = end + 1
        }
        return ranks
    }

    private static func add(_ weighted: inout Double, _ weight: inout Double, _ score: Double?, _ contributor: Double) {
        guard let score else { return }
        weighted += clamp(score, 0, 100) * contributor
        weight += contributor
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

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
