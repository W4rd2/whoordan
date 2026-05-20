import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Recovery", subtitle: "Readiness")
                        hero
                        scoreSummary
                        if recoveryMetric.value == nil {
                            baselineRequirements
                            if environment.deviceState.shouldShowPairWearableCTA {
                                missingSignalsCTA
                            }
                        } else {
                            contributorHighlights
                            contributorList
                        }
                        WFootnote(text: "Not medical advice. Recovery is an original Whoordan wellness estimate and is not equivalent to any proprietary recovery score.")
                        Button {
                            showInfo = true
                        } label: {
                            Label("How recovery is interpreted", systemImage: "info.circle")
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
        WHeroModule(
            eyebrow: "Instrument",
            title: recoveryMetric.value == nil ? "Building baseline" : "Recovery score",
            value: recoveryMetric.value,
            message: recoveryMetric.value == nil
                ? recoveryMetric.unavailableReason ?? "Connect source-labeled heart, sleep, and respiratory signals before Whoordan scores readiness."
                : "Original Whoordan score from source-labeled contributors and personal baselines. Not medical advice.",
            symbol: "arrow.clockwise",
            confidence: recoveryMetric.confidence
        )
    }

    private var scoreSummary: some View {
        WSignalList(rows: [
            WSignalRowModel(
                title: "Score",
                value: recoveryMetric.value.map { "\($0)/100" } ?? "Building",
                detail: recoveryMetric.accuracySummary ?? "Original Whoordan recovery scale from available personal signals.",
                symbol: "number"
            ),
            WSignalRowModel(
                title: "Category",
                value: RecoveryExplainer.category(for: recoveryMetricNumericValue),
                detail: "Whoordan category for scanning. It is not a copied benchmark label.",
                symbol: "gauge.with.dots.needle.50percent",
                tint: recoveryMetric.value == nil ? WColors.secondary : WColors.accent
            ),
            WSignalRowModel(
                title: "Confidence",
                value: recoveryMetric.confidence.label,
                detail: recoveryMetric.calibrationSummary ?? "Missing data lowers confidence; Whoordan does not impute absent contributors.",
                symbol: "checkmark.seal",
                tint: recoveryMetric.confidence.color
            ),
            WSignalRowModel(
                title: "Source labels",
                value: primarySourceLabel,
                detail: "Wearable direct wins when decoded and reliable; Apple Health remains export-only.",
                symbol: "link"
            )
        ])
    }

    private var baselineRequirements: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text("Baseline readiness")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WSignalList(rows: baselineRows)
        }
    }

    private var contributorHighlights: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text("Top positive contributors")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WSignalList(rows: highlightRows(positive: true))

            Text("Top negative contributors")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WSignalList(rows: highlightRows(positive: false))
        }
    }

    private var contributorList: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text("Contributors")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WSignalList(rows: contributorRows + [missingDataRow])
        }
    }

    private var missingSignalsCTA: some View {
        WCTARow(actions: [
            WCTAAction(
                title: "Pair wearable",
                subtitle: "Use direct wearable signals after approval.",
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
                    WScreenHeader(title: "Recovery", subtitle: "Notes")
                    Text("Recovery is an original Whoordan wellness estimate from HRV relative to baseline, RHR relative to baseline, sleep sufficiency, respiratory fit, and skin-temperature deviation from a personal baseline when those source-labeled signals are available. It is not medical advice and does not diagnose, treat, prevent, or cure disease. It is not equivalent to any proprietary recovery score.")
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

    private var recoveryContributors: [RecoveryContributorScore] {
        let baselines = personalBaselines
        return RecoveryExplainer.contributors(inputs: RecoveryInputs(
            hrv: environment.todaySnapshot.hrv,
            hrvBaseline: baselines.hrv,
            restingHeartRate: environment.todaySnapshot.restingHeartRate,
            restingHeartRateBaseline: baselines.restingHeartRate,
            sleepMinutes: environment.todaySnapshot.sleepMinutes,
            sleepNeedMinutes: effectiveSleepNeedMinutes,
            respiratoryRate: environment.todaySnapshot.respiratoryRate,
            respiratoryRateBaseline: baselines.respiratoryRate,
            temperatureDelta: environment.todaySnapshot.bodyTemperatureDelta,
            oxygenSaturation: environment.todaySnapshot.oxygenSaturation
        ))
    }

    private var recoveryMetric: WhoordanMetricSnapshot {
        metricSnapshots.first { $0.id == .recovery }
        ?? WhoordanMetricSnapshot(
            id: .recovery,
            title: "Recovery",
            value: nil,
            unit: nil,
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until validated",
            accuracyDetail: nil,
            requirements: ["Current HRV", "Current resting HR", "Personal HRV/RHR baseline"],
            calibrationSummary: "Not enough validated input data yet.",
            lastUpdated: nil,
            unavailableReason: "Needs current HRV/RHR plus personal baseline history before showing recovery.",
            context: "Whoordan does not show recovery from fixed HRV/RHR population defaults.",
            symbol: "arrow.clockwise"
        )
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

    private var sleepNeedMetric: WhoordanMetricSnapshot? {
        metricSnapshots.first { $0.id == .sleepNeed }
    }

    private var effectiveSleepNeedMinutes: Double? {
        environment.todaySnapshot.sleepNeedMinutes ?? durationMinutes(from: sleepNeedMetric?.value)
    }

    private var recoveryMetricNumericValue: Double? {
        recoveryMetric.value.flatMap(Double.init)
    }

    private var personalBaselines: (hrv: Double?, restingHeartRate: Double?, respiratoryRate: Double?) {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: environment.todaySnapshot.date)
        let prior = environment.recentSummaries.filter { calendar.startOfDay(for: $0.date) < currentDay }
        let hrvValues = prior.compactMap(\.hrv)
        let restingValues = prior.compactMap(\.restingHeartRate)
        let respiratoryValues = prior.compactMap(\.respiratoryRate)
        return (
            hrvValues.count >= 5 ? median(hrvValues.suffix(28)) : nil,
            restingValues.count >= 5 ? median(restingValues.suffix(28)) : nil,
            respiratoryValues.count >= 5 ? median(respiratoryValues.suffix(28)) : nil
        )
    }

    private var contributorRows: [WSignalRowModel] {
        recoveryContributors.map { contributor in
            WSignalRowModel(
                title: contributor.kind.title,
                value: valueText(for: contributor),
                detail: detailText(for: contributor),
                symbol: contributor.kind.symbol,
                tint: tint(for: contributor)
            )
        }
    }

    private var missingDataRow: WSignalRowModel {
        let missingCount = recoveryContributors.filter(\.isMissing).count
        let total = recoveryContributors.count
        return WSignalRowModel(
            title: "Missing-data confidence",
            value: "\(total - missingCount)/\(total) signals",
            detail: "Confidence drops when contributors are missing. No missing signal is filled in or guessed.",
            symbol: "exclamationmark.triangle",
            tint: missingCount == 0 ? WColors.success : WColors.warning
        )
    }

    private var primarySourceLabel: String {
        environment.todaySnapshot.source?.label
            ?? environment.todaySnapshot.sleepSummary?.source?.label
            ?? environment.todaySnapshot.movement.source?.label
            ?? "Setup"
    }

    private var baselineRows: [WSignalRowModel] {
        let baselines = personalBaselines
        return [
            WSignalRowModel(
                title: "HRV relative to baseline",
                value: environment.todaySnapshot.hrv == nil || baselines.hrv == nil ? "Needed" : "Ready",
                detail: "Requires current measured HRV and at least five prior HRV baseline days; never computed from BPM alone.",
                symbol: "waveform.path.ecg",
                tint: environment.todaySnapshot.hrv == nil || baselines.hrv == nil ? WColors.warning : WColors.success
            ),
            WSignalRowModel(
                title: "RHR relative to baseline",
                value: environment.todaySnapshot.restingHeartRate == nil || baselines.restingHeartRate == nil ? "Needed" : "Ready",
                detail: "Requires current resting heart rate and at least five prior RHR baseline days.",
                symbol: "heart",
                tint: environment.todaySnapshot.restingHeartRate == nil || baselines.restingHeartRate == nil ? WColors.warning : WColors.success
            ),
            WSignalRowModel(
                title: "Sleep sufficiency",
                value: environment.todaySnapshot.sleepMinutes == nil || effectiveSleepNeedMinutes == nil ? "Needed" : "Ready",
                detail: "Measured sleep duration compared with a source-labeled sleep-need estimate.",
                symbol: "moon",
                tint: environment.todaySnapshot.sleepMinutes == nil || effectiveSleepNeedMinutes == nil ? WColors.warning : WColors.success
            ),
            WSignalRowModel(
                title: "Respiratory fit",
                value: environment.todaySnapshot.respiratoryRate == nil || baselines.respiratoryRate == nil ? "Optional" : "Ready",
                detail: "Used only when a measured respiratory rate and personal respiratory baseline exist.",
                symbol: "lungs",
                tint: environment.todaySnapshot.respiratoryRate == nil || baselines.respiratoryRate == nil ? WColors.secondary : WColors.success
            ),
            WSignalRowModel(
                title: "Skin temp baseline",
                value: skinTemperatureBaselineValue,
                detail: skinTemperatureBaselineDetail,
                symbol: "thermometer.medium",
                tint: environment.skinTemperatureBaselineProfile.isAutomatic ? WColors.success : WColors.warning
            )
        ]
    }

    private func highlightRows(positive: Bool) -> [WSignalRowModel] {
        let selected = recoveryContributors
            .compactMap { contributor -> (RecoveryContributorScore, Double)? in
                guard let impact = contributor.impact else { return nil }
                return (contributor, impact)
            }
            .filter { positive ? $0.1 > 3 : $0.1 < -3 }
            .sorted { positive ? $0.1 > $1.1 : $0.1 < $1.1 }
            .prefix(2)

        let rows = selected.map { contributor, impact in
            WSignalRowModel(
                title: contributor.kind.shortTitle,
                value: impactText(impact),
                detail: detailText(for: contributor),
                symbol: positive ? "plus.circle" : "minus.circle",
                tint: positive ? WColors.success : WColors.warning
            )
        }
        if rows.isEmpty {
            return [
                WSignalRowModel(
                    title: positive ? "No strong positive yet" : "No strong negative yet",
                    value: "Needs data",
                    detail: positive
                        ? "Collect more source-labeled signals to identify what is supporting recovery."
                        : "No available contributor is clearly pulling the score down right now.",
                    symbol: positive ? "plus.circle" : "minus.circle",
                    tint: WColors.secondary
                )
            ]
        }
        return rows
    }

    private func valueText(for contributor: RecoveryContributorScore) -> String {
        guard let value = contributor.value else { return "Missing" }
        switch contributor.kind {
        case .hrv:
            return "\(Int(value.rounded())) ms"
        case .restingHeartRate:
            return "\(Int(value.rounded())) bpm"
        case .sleepSufficiency:
            return durationText(value)
        case .respiratoryFit:
            return "\(String(format: "%.1f", value)) br/min"
        case .temperatureDeviation:
            return "\(signed(value)) C"
        case .oxygenSaturation:
            return "\(Int(value.rounded()))%"
        }
    }

    private func detailText(for contributor: RecoveryContributorScore) -> String {
        let source = sourceLabel(for: contributor.kind, hasValue: contributor.value != nil)
        let weight = "\(Int((contributor.weight * 100).rounded()))%"
        guard let value = contributor.value else {
            return "Missing; no value is imputed. Source \(source). Weight \(weight)."
        }
        switch contributor.kind {
        case .hrv:
            let ratio = ratioText(value: value, baseline: contributor.baseline)
            return "HRV relative to baseline \(ratio). Source \(source). Weight \(weight)."
        case .restingHeartRate:
            let ratio = ratioText(value: value, baseline: contributor.baseline)
            return "RHR relative to baseline \(ratio). Lower than baseline supports recovery. Source \(source). Weight \(weight)."
        case .sleepSufficiency:
            let ratio = ratioText(value: value, baseline: contributor.baseline)
            return "Sleep sufficiency \(ratio) of estimated need. Source \(source). Weight \(weight)."
        case .respiratoryFit:
            let deviation = contributor.baseline.map { abs(value - $0) }
            let deviationText = deviation.map { "\(String(format: "%.1f", $0)) from baseline" } ?? "needs baseline"
            return "Respiratory fit \(deviationText). Source \(source). Weight \(weight)."
        case .temperatureDeviation:
            return "Skin-temperature deviation \(signed(value)) C from personal baseline. Source \(source). Weight \(weight)."
        case .oxygenSaturation:
            return "SpO2 context from a measured or source-labeled input. Source \(source). Weight \(weight)."
        }
    }

    private func sourceLabel(for kind: RecoveryContributorKind, hasValue: Bool) -> String {
        guard hasValue else { return "Not measured" }
        switch kind {
        case .sleepSufficiency:
            return environment.todaySnapshot.sleepSummary?.source?.label
                ?? environment.todaySnapshot.source?.label
                ?? "Source labeled"
        default:
            return environment.todaySnapshot.source?.label
                ?? "Source labeled"
        }
    }

    private func tint(for contributor: RecoveryContributorScore) -> Color {
        guard let impact = contributor.impact else { return WColors.warning }
        if impact > 3 { return WColors.success }
        if impact < -3 { return WColors.warning }
        return WColors.secondary
    }

    private func impactText(_ impact: Double) -> String {
        let rounded = Int(impact.rounded())
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func ratioText(value: Double, baseline: Double?) -> String {
        guard let baseline, baseline > 0 else { return "needs baseline" }
        return "\(Int(((value / baseline) * 100).rounded()))% of baseline"
    }

    private func median<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }

    private func durationText(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        let remainder = Int(minutes.truncatingRemainder(dividingBy: 60))
        return "\(hours)h \(remainder)m"
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

    private var skinTemperatureBaselineValue: String {
        let profile = environment.skinTemperatureBaselineProfile
        if profile.isAutomatic { return "Ready" }
        return "\(min(profile.eligibleDayCount, profile.requiredDayCount))/\(profile.requiredDayCount) days"
    }

    private var skinTemperatureBaselineDetail: String {
        let profile = environment.skinTemperatureBaselineProfile
        if profile.isAutomatic {
            return "Private five-day personal baseline is set; only deviation is shown."
        }
        if profile.hasTemporaryBaseline {
            return "Temporary baseline is active until five eligible sleep-temperature days are ready."
        }
        return "Needs five sleep/night wrist-temperature days; no universal normal is used."
    }

    private func signed(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }
}
