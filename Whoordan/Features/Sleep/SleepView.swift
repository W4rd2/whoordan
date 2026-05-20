import SwiftUI

struct SleepView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Sleep", subtitle: "Last night")
                        hero
                        if hasMeasuredSleep {
                            sleepRows
                        } else if environment.deviceState.shouldShowPairWearableCTA {
                            sourceCTA
                        }
                        if hasSleepAnalysisMetrics {
                            analysisRows
                        }
                        if hasMeasuredStages {
                            stageRows
                        }
                        if hasSleepHistory {
                            patternRows
                        }
                        if hasSleepPlannerMetrics {
                            plannerRows
                        }
                        if !hasMeasuredSleep && !hasSleepAnalysisMetrics && !hasSleepHistory && !hasSleepPlannerMetrics {
                            WFootnote(text: "Wearable sleep decoding is pending capture. Apple Health remains export-only.")
                        }
                        Button {
                            showInfo = true
                        } label: {
                            Label("Sleep signal notes", systemImage: "info.circle")
                                .font(WTypography.caption.weight(.medium))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(WColors.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, WSpacing.l)
                    .padding(.top, WSpacing.m)
                    .padding(.bottom, WSpacing.xxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showInfo) {
                infoSheet
            }
        }
    }

    private var hero: some View {
        let sleep = currentSleep
        let mainMinutes = displayedSleepMinutes
        return WHeroModule(
            eyebrow: "Last sleep",
            title: mainMinutes == nil ? "No overnight sleep yet" : "Sleep recorded",
            value: durationText(mainMinutes),
            message: sleepMessage,
            symbol: "moon",
            confidence: sleep?.confidence ?? (mainMinutes == nil ? .unavailable : environment.todaySnapshot.confidence)
        )
    }

    private var sleepRows: some View {
        let sleep = currentSleep
        let main = sleep?.mainSleep
        return WSignalList(rows: [
            WSignalRowModel(
                title: "Last sleep",
                value: durationText(main?.asleepMinutes ?? environment.todaySnapshot.sleepMinutes) ?? "Building",
                detail: sleepDurationDetail,
                symbol: "bed.double"
            ),
            WSignalRowModel(
                title: "Time in bed",
                value: durationText(main?.inBedMinutes) ?? "Building",
                detail: main.map { "Bed \(Self.timeFormatter.string(from: $0.start)), wake \(Self.timeFormatter.string(from: $0.end))" } ?? "Measured sessions only.",
                symbol: "clock"
            ),
            WSignalRowModel(
                title: "Awake",
                value: durationText(sleep?.awakeMinutes) ?? "Not reported",
                detail: "Shown only when the source provides awake segments.",
                symbol: "eye"
            ),
            WSignalRowModel(
                title: "Naps",
                value: durationText(sleep?.napMinutes) ?? "None",
                detail: sleep?.naps.isEmpty == false ? "\(sleep?.naps.count ?? 0) nap session(s)" : "Short sleep sessions stay separate from main sleep.",
                symbol: "clock.badge.exclamationmark",
                tint: WColors.warning
            ),
            WSignalRowModel(
                title: "Efficiency",
                value: main?.efficiencyPercent.map { "\(Int($0.rounded()))%" } ?? "Building",
                detail: "Calculated only from measured session timing.",
                symbol: "gauge.with.dots.needle.50percent"
            ),
            WSignalRowModel(
                title: "Source",
                value: sleep?.source?.label ?? environment.todaySnapshot.source?.label ?? "Setup",
                detail: sleepSourceDetail,
                symbol: "link"
            )
        ])
    }

    private var stageRows: some View {
        let sleep = currentSleep
        let totals = sleep?.stageTotals ?? [:]
        let measuredStages: [SleepStage] = [.awake, .rem, .core, .deep]
        let rows: [WSignalRowModel]
        if hasMeasuredStages {
            rows = measuredStages.map { stage in
                WSignalRowModel(
                    title: stage.label,
                    value: durationText(totals[stage]) ?? "0m",
                    detail: stageDetail(for: sleep),
                    symbol: symbol(for: stage)
                )
            }
        } else {
            rows = []
        }
        return WSignalList(rows: rows)
    }

    private var analysisRows: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text("Sleep analysis")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WSignalList(rows: [
                WSignalRowModel(
                    title: "Sleep performance",
                    value: sleepPerformanceMetric.displayValueWithUnit,
                    detail: sleepPerformanceMetric.signalDetail,
                    symbol: "bed.double",
                    tint: sleepPerformanceMetric.confidence.color
                ),
                WSignalRowModel(
                    title: "Hours vs needed",
                    value: hoursVsNeededText,
                    detail: "Calculated from measured sleep and Whoordan's conservative sleep-need estimate.",
                    symbol: "clock.arrow.circlepath",
                    tint: WColors.secondary
                ),
                WSignalRowModel(
                    title: "Restorative sleep",
                    value: restorativeMetric.displayValueWithUnit,
                    detail: restorativeMetric.signalDetail,
                    symbol: "sparkles",
                    tint: restorativeMetric.confidence.color
                ),
                WSignalRowModel(
                    title: "Stress context",
                    value: stressMetric.displayValueWithUnit,
                    detail: stressMetric.signalDetail,
                    symbol: stressMetric.symbol,
                    tint: stressMetric.confidence.color
                )
            ])
        }
    }

    private var patternRows: some View {
        let sleeps = environment.recentSummaries.compactMap(\.sleepSummary?.mainSleep)
        let durations = environment.recentSummaries.compactMap {
            $0.sleepSummary?.mainSleep?.asleepMinutes ?? $0.sleepMinutes
        }
        let average = average(durations)
        let bedtimeConsistency = consistencyMinutes(sleeps.map { minutesSinceStartOfDay($0.start) })
        let wakeConsistency = consistencyMinutes(sleeps.map { minutesSinceStartOfDay($0.end) })
        return WSignalList(rows: [
            WSignalRowModel(
                title: "7-night average",
                value: durationText(average) ?? "Building",
                detail: durations.count < 2 ? "Collect more nights for patterns." : "\(durations.count) nights with measured sleep.",
                symbol: "chart.bar"
            ),
            WSignalRowModel(
                title: "Bedtime consistency",
                value: consistencyText(bedtimeConsistency),
                detail: sleeps.count < 2 ? "Requires decoded sleep sessions with timing." : "Variation in measured sleep start times.",
                symbol: "moon.zzz"
            ),
            WSignalRowModel(
                title: "Wake consistency",
                value: consistencyText(wakeConsistency),
                detail: sleeps.count < 2 ? "Requires decoded sleep sessions with timing." : "Variation in measured wake times.",
                symbol: "sunrise"
            )
        ])
    }

    private var plannerRows: some View {
        let need = displayedSleepNeedMinutes
        let suggestedBedtime = currentSleep?.mainSleep.map { main in
            need.map { main.end.addingTimeInterval(24 * 60 * 60 - $0 * 60) }
        }
        return WSignalList(rows: [
            WSignalRowModel(
                title: "Sleep need",
                value: sleepNeedMetric.displayValueWithUnit,
                detail: sleepNeedMetric.signalDetail,
                symbol: "gauge",
                tint: sleepNeedMetric.confidence.color
            ),
            WSignalRowModel(
                title: "Sleep debt",
                value: sleepDebtMetric.displayValueWithUnit,
                detail: sleepDebtMetric.signalDetail,
                symbol: "minus.plus.batteryblock",
                tint: sleepDebtMetric.confidence.color
            ),
            WSignalRowModel(
                title: "Suggested bedtime",
                value: suggestedBedtime.flatMap { $0 }.map { Self.timeFormatter.string(from: $0) } ?? "Building",
                detail: need == nil ? "Needs a sleep-need value before suggesting bedtime." : "Uses your last measured wake time until a target wake setting exists.",
                symbol: "bed.double.circle"
            )
        ])
    }

    private var sourceCTA: some View {
        WCTARow(actions: [
            WCTAAction(
                title: "Pair wearable",
                subtitle: "Use decoded device sleep only when supported.",
                symbol: "sensor.tag.radiowaves.forward"
            ) {
                environment.scanForWearable()
            }
        ])
    }

    private var infoSheet: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: "Sleep", subtitle: "Notes")
                    Text("No fabricated efficiency or stages. Sleep need and debt are bounded wellness estimates that require measured sleep history.")
                        .font(WTypography.body)
                        .foregroundStyle(WColors.secondary)
                    Spacer()
                }
                .padding(WSpacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showInfo = false }
                }
            }
        }
    }

    private func durationText(_ value: Double?) -> String? {
        guard let value else { return nil }
        let hours = Int(value / 60)
        let minutes = Int(value.truncatingRemainder(dividingBy: 60))
        return "\(hours)h \(minutes)m"
    }

    private var currentSleep: SleepSummary? {
        environment.todaySnapshot.sleepSummary
    }

    private var displayedSleepMinutes: Double? {
        currentSleep?.mainSleep?.asleepMinutes ?? environment.todaySnapshot.sleepMinutes
    }

    private var sleepDurationDetail: String {
        if let main = currentSleep?.mainSleep {
            return "\(main.source.label), \(timeRange(main.start, main.end))"
        }
        if environment.todaySnapshot.sleepMinutes != nil {
            return "\(environment.todaySnapshot.source?.label ?? "Daily summary") sleep restored without session timing."
        }
        return "Waiting for wearable sleep."
    }

    private var sleepSourceDetail: String {
        guard let sleep = currentSleep else {
            if environment.todaySnapshot.sleepMinutes != nil {
                return "Summary-level sleep restored; stages require decoded wearable sessions."
            }
            return "Wearable direct first; Apple Health remains export-only."
        }
        return "\(sleep.sessions.count) sleep session(s) selected."
    }

    private var hasMeasuredSleep: Bool {
        currentSleep?.hasSleep == true || environment.todaySnapshot.sleepMinutes != nil
    }

    private var hasMeasuredStages: Bool {
        let totals = currentSleep?.stageTotals ?? [:]
        return [.awake, .rem, .core, .deep].contains { (totals[$0] ?? 0) > 0 }
    }

    private var hasSleepHistory: Bool {
        environment.recentSummaries.filter {
            $0.sleepSummary?.mainSleep != nil || $0.sleepMinutes != nil
        }.count >= 2
    }

    private var hoursVsNeededText: String {
        guard let sleep = displayedSleepMinutes,
              let need = displayedSleepNeedMinutes,
              need > 0 else {
            return "Building"
        }
        return "\(Int((min(max(sleep / need, 0), 1.25) * 100).rounded()))%"
    }

    private var displayedSleepNeedMinutes: Double? {
        environment.todaySnapshot.sleepNeedMinutes ?? durationMinutes(from: sleepNeedMetric.value)
    }

    private var hasSleepAnalysisMetrics: Bool {
        hasMeasuredSleep
            || sleepPerformanceMetric.value != nil
            || restorativeMetric.value != nil
            || stressMetric.value != nil
    }

    private var hasSleepPlannerMetrics: Bool {
        displayedSleepNeedMinutes != nil
            || sleepDebtMetric.value != nil
    }

    private func durationMinutes(from value: String?) -> Double? {
        guard let value else { return nil }
        let parts = value.split(separator: " ")
        var total = 0
        var matched = false
        for part in parts {
            if part.hasSuffix("h"), let hours = Double(part.dropLast()) {
                total += Int((hours * 60).rounded())
                matched = true
            } else if part.hasSuffix("m"), let minutes = Double(part.dropLast()) {
                total += Int(minutes.rounded())
                matched = true
            }
        }
        return matched ? Double(total) : nil
    }

    private var sleepMessage: String {
        guard let sleep = currentSleep else {
            if let minutes = environment.todaySnapshot.sleepMinutes {
                let source = environment.todaySnapshot.source?.label ?? "Daily summary"
                return "\(durationText(minutes) ?? "Sleep") restored from \(source). Stages require decoded wearable sessions."
            }
            return "Capture decoded wearable sleep before Whoordan shows sleep history."
        }
        let source = sleep.source?.label ?? "Source labeled"
        if let napMinutes = sleep.napMinutes, napMinutes > 0 {
            return "\(source) sleep selected with \(durationText(napMinutes) ?? "0m") of naps tracked separately."
        }
        if sleep.source == .whoordanEstimate || sleep.confidence == .low {
            return "\(source) sleep selected. Stages are BLE-derived estimates when available."
        }
        return "\(source) sleep selected. Stages appear when a source provides them."
    }

    private var metricSnapshots: [WhoordanMetricSnapshot] {
        WhoordanMetricCatalog.metrics(
            summary: environment.todaySnapshot,
            deviceState: environment.deviceState,
            baselineProfile: environment.skinTemperatureBaselineProfile,
            bodyProfile: environment.bodyProfile,
            recentSummaries: environment.recentSummaries,
            now: Date()
        )
    }

    private var sleepPerformanceMetric: WhoordanMetricSnapshot {
        metric(.sleepPerformance, title: "Sleep performance", symbol: "bed.double")
    }

    private var sleepNeedMetric: WhoordanMetricSnapshot {
        metric(.sleepNeed, title: "Sleep need", symbol: "clock.badge.questionmark")
    }

    private var sleepDebtMetric: WhoordanMetricSnapshot {
        metric(.sleepDebt, title: "Sleep debt", symbol: "hourglass")
    }

    private var restorativeMetric: WhoordanMetricSnapshot {
        metric(.restorativeSleepPercent, title: "Restorative sleep", symbol: "sparkles")
    }

    private var stressMetric: WhoordanMetricSnapshot {
        metric(.stress, title: "Stress", symbol: "brain.head.profile")
    }

    private func metric(_ id: WhoordanMetricID, title: String, symbol: String) -> WhoordanMetricSnapshot {
        metricSnapshots.first { $0.id == id } ?? WhoordanMetricSnapshot(
            id: id,
            title: title,
            value: nil,
            unit: nil,
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until source exists",
            accuracyDetail: nil,
            requirements: [],
            calibrationSummary: nil,
            lastUpdated: nil,
            unavailableReason: "Needs a usable source before this metric can be shown.",
            context: "Metric catalog did not return this item.",
            symbol: symbol
        )
    }

    private func stageDetail(for sleep: SleepSummary?) -> String {
        if sleep?.source == .whoordanEstimate || sleep?.confidence == .low {
            return "Estimated from BLE HR/IMU context; not measured sleep staging."
        }
        return "Measured by \(sleep?.source?.label ?? "source")."
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        "\(Self.timeFormatter.string(from: start))-\(Self.timeFormatter.string(from: end))"
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func consistencyMinutes(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let angles = values.map { (($0.truncatingRemainder(dividingBy: 1_440) + 1_440).truncatingRemainder(dividingBy: 1_440)) / 1_440 * 2 * Double.pi }
        let sinMean = angles.map(sin).reduce(0, +) / Double(angles.count)
        let cosMean = angles.map(cos).reduce(0, +) / Double(angles.count)
        let resultant = min(max(hypot(sinMean, cosMean), 0), 1)
        guard resultant > Double.ulpOfOne else { return 720 }
        let circularStdRadians = sqrt(max(-2 * log(resultant), 0))
        return circularStdRadians * 1_440 / (2 * Double.pi)
    }

    private func minutesSinceStartOfDay(_ date: Date) -> Double {
        let calendar = Calendar.current
        return date.timeIntervalSince(calendar.startOfDay(for: date)) / 60
    }

    private func consistencyText(_ value: Double?) -> String {
        guard let value else { return "Needs history" }
        if value < 30 { return "Consistent" }
        if value < 75 { return "Variable" }
        return "Irregular"
    }

    private func symbol(for stage: SleepStage) -> String {
        switch stage {
        case .awake: return "eye"
        case .rem: return "brain.head.profile"
        case .core: return "moon"
        case .deep: return "moon.stars"
        case .inBed: return "bed.double"
        case .asleep, .unknown: return "square.stack.3d.up"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
