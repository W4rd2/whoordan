import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showBaselineInfo = false
    @State private var customSkinBaselineText = ""
    @State private var skinBaselineError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Today", date: Date.now)
                        statusStrip
                        hero
                        summaryGrid
                        if needsPrimarySetup {
                            ctaRow
                        }
                        todaySignalBoard
                        if hasBodySignals { bodySignals }
                        metricDashboard
                        WFootnote(text: "Whoordan uses wellness signals only. Medical interpretation stays out of the dashboard.")
                    }
                    .padding(.horizontal, WSpacing.l)
                    .padding(.top, WSpacing.xl)
                    .padding(.bottom, WSpacing.xxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBaselineInfo) {
                baselineSheet
            }
        }
    }

    private var statusStrip: some View {
        WStatusStrip(items: [
            .init(title: "Access", value: environment.isApproved ? "Approved" : "Locked", symbol: "checkmark.seal", tint: WColors.success),
            .init(title: "Mode", value: environment.consentState.cloudSyncEnabled ? "Cloud" : "Local", symbol: environment.consentState.cloudSyncEnabled ? "icloud" : "iphone"),
            .init(title: "Source", value: sourceStatus, symbol: "waveform.path.ecg"),
            .init(title: "Sync", value: syncStatusText, symbol: "arrow.triangle.2.circlepath")
        ])
    }

    private var hero: some View {
        WHeroModule(
            eyebrow: recoveryMetric.value == nil ? "Baseline" : "Recovery",
            title: recoveryMetric.value == nil ? "Building your baseline" : "Today is ready",
            value: recoveryMetric.value,
            message: recoveryMetric.value == nil
                ? "Connect a trusted source and collect a few days of signals before Whoordan scores the day."
                : "Score is based on validated inputs and labeled accuracy.",
            symbol: "waveform.path.ecg.rectangle",
            confidence: recoveryMetric.confidence
        )
    }

    private var ctaRow: some View {
        WCTARow(actions: [primarySetupAction])
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WSpacing.s) {
            WCompactMetricTile(
                title: "Recovery",
                value: recoveryMetric.value ?? "Building",
                caption: recoveryMetric.confidence.label,
                symbol: "arrow.clockwise"
            )
            WCompactMetricTile(
                title: "Sleep",
                value: durationText(environment.todaySnapshot.sleepMinutes),
                caption: sleepCaption,
                symbol: "moon"
            )
            WCompactMetricTile(
                title: "Strain",
                value: dayStrainMetric.value ?? "Building",
                caption: dayStrainMetric.value == nil ? "Building activity context" : dayStrainMetric.confidence.label,
                symbol: "figure.run"
            )
            WCompactMetricTile(
                title: "Steps",
                value: stepsText,
                caption: stepsCaption,
                symbol: "shoeprints.fill"
            )
            WCompactMetricTile(
                title: "Heart",
                value: heartSummary,
                caption: heartMetric.value == nil ? "Connect a heart source" : heartMetric.source.label,
                symbol: "heart"
            )
            WCompactMetricTile(
                title: "Workouts",
                value: environment.todaySnapshot.movement.movementMinutes.map { "\(Int($0.rounded()))m" } ?? "Optional",
                caption: environment.todaySnapshot.movement.movementMinutes == nil ? "Add when available" : "Measured activity",
                symbol: "figure.strengthtraining.traditional"
            )
        }
    }

    private var todaySignalBoard: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            WSectionHeader(title: "Signal board", subtitle: "Open a metric family for deeper context and source-labeled details.")
            LazyVGrid(columns: [GridItem(.flexible())], spacing: WSpacing.s) {
                NavigationLink {
                    SleepView()
                } label: {
                    WSignalBoardCard(
                        title: "Sleep",
                        value: durationText(environment.todaySnapshot.sleepMinutes),
                        context: sleepCardContext,
                        symbol: "moon",
                        chips: sleepCardChips,
                        confidence: environment.todaySnapshot.sleepSummary?.confidence
                            ?? (environment.todaySnapshot.sleepMinutes == nil ? .unavailable : environment.todaySnapshot.confidence)
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    RecoveryView()
                } label: {
                    WSignalBoardCard(
                        title: "Recovery",
                        value: recoveryMetric.value ?? "Building",
                        context: recoveryCardContext,
                        symbol: "arrow.clockwise",
                        chips: recoveryCardChips,
                        confidence: recoveryMetric.confidence
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    StrainDetailView()
                } label: {
                    WSignalBoardCard(
                        title: "Load",
                        value: dayStrainMetric.value ?? "Building",
                        context: dayStrainMetric.signalDetail,
                        symbol: "figure.run",
                        chips: strainCardChips,
                        confidence: dayStrainMetric.confidence
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    TrendsView()
                } label: {
                    WSignalBoardCard(
                        title: "Trends",
                        value: trendCardValue,
                        context: trendCardContext,
                        symbol: "chart.line.uptrend.xyaxis",
                        chips: trendCardChips,
                        confidence: trendCardConfidence
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var metricDashboard: some View {
        let snapshots = metricSnapshots
        return VStack(alignment: .leading, spacing: WSpacing.m) {
            WSectionHeader(
                title: "Data quality",
                subtitle: "Tap a metric for source, confidence, update time, and why it is limited or blocked."
            )
            metricSection(title: "Show now", readiness: .showNow, metrics: snapshots.filter { $0.readiness == .showNow })
            metricSection(title: "Beta / estimated", readiness: .betaEstimated, metrics: snapshots.filter { $0.readiness == .betaEstimated })
            metricSection(title: "Later / blocked", readiness: .laterBlocked, metrics: snapshots.filter { $0.readiness == .laterBlocked })
        }
    }

    private func metricSection(
        title: String,
        readiness: WhoordanMetricReadiness,
        metrics: [WhoordanMetricSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            HStack {
                Text(title)
                    .font(WTypography.body.weight(.semibold))
                    .foregroundStyle(WColors.text)
                Spacer()
                WBadge(text: "\(metrics.count)", color: readiness.color)
            }
            LazyVGrid(columns: metricGridColumns, spacing: WSpacing.s) {
                ForEach(metrics) { metric in
                    NavigationLink {
                        MetricDetailView(metric: metric)
                    } label: {
                        WMetricCard(metric: metric)
                    }
                    .buttonStyle(.plain)
                }
            }
            if metrics.isEmpty {
                emptyMetricSection(readiness: readiness)
            }
        }
    }

    private func emptyMetricSection(readiness: WhoordanMetricReadiness) -> some View {
        WCard(padding: WSpacing.m, background: WColors.surface.opacity(0.72)) {
            Label(emptyMetricSectionMessage(for: readiness), systemImage: readiness.emptyStateSymbol)
                .font(WTypography.caption.weight(.medium))
                .foregroundStyle(WColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyMetricSectionMessage(for readiness: WhoordanMetricReadiness) -> String {
        switch readiness {
        case .showNow:
            return "No ready metrics yet. Connect a live or source-labeled signal."
        case .betaEstimated:
            return "No beta estimates in this snapshot. Overnight HR and stillness windows will appear here when they meet the minimum coverage gate."
        case .laterBlocked:
            return "No blocked metrics in this snapshot."
        }
    }

    private var metricGridColumns: [GridItem] {
        [GridItem(.flexible(minimum: 260), spacing: WSpacing.s, alignment: .top)]
    }

    private var bodySignals: some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            WSectionHeader(
                title: "Body signals",
                subtitle: "Live body inputs that are ready now, separate from the long data-quality audit."
            )
            WSignalList(rows: bodySignalRows)
            if environment.skinTemperatureBaselineProfile.canEditTemporaryBaseline,
               environment.todaySnapshot.rawWristTemperatureC != nil {
                WCTARow(actions: [
                    WCTAAction(
                        title: "Set skin baseline",
                        subtitle: "Use a temporary personal baseline while five sleep-temperature days collect.",
                        symbol: "thermometer.variable"
                    ) {
                        prepareSkinBaselineDraft()
                        showBaselineInfo = true
                    }
                ])
            }
        }
    }

    private var baselineSheet: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Build baseline", subtitle: "Signals needed")
                        WSignalList(rows: [
                            WSignalRowModel(title: "Heart", value: "Connect source", detail: "RHR and HRV need measured data.", symbol: "heart"),
                            WSignalRowModel(title: "Sleep", value: "Add sleep", detail: "Stages appear only when source-labeled.", symbol: "moon"),
                            WSignalRowModel(title: "Activity", value: "Collect steps", detail: "Movement comes from a reliable wearable source.", symbol: "shoeprints.fill"),
                            WSignalRowModel(title: "Heart zones", value: "Set max HR", detail: "Fallback estimates are labeled and lower confidence.", symbol: "slider.horizontal.3"),
                            skinTemperatureBaselineRow
                        ])
                        skinBaselineEditor
                    }
                    .padding(WSpacing.l)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showBaselineInfo = false }
                }
            }
            .onAppear { prepareSkinBaselineDraft() }
        }
    }

    private var hasBodySignals: Bool {
        environment.todaySnapshot.restingHeartRate != nil
            || environment.todaySnapshot.hrv != nil
            || environment.todaySnapshot.respiratoryRate != nil
            || environment.todaySnapshot.oxygenSaturation != nil
            || environment.todaySnapshot.rawWristTemperatureC != nil
            || (hasActiveSkinTemperatureBaseline && environment.todaySnapshot.bodyTemperatureDelta != nil)
    }

    private var bodySignalRows: [WSignalRowModel] {
        var rows: [WSignalRowModel] = []
        if let resting = environment.todaySnapshot.restingHeartRate {
            rows.append(WSignalRowModel(title: "Resting heart rate", value: "\(Int(resting.rounded())) bpm", detail: "Measured or source-labeled only.", symbol: "heart"))
        }
        if let hrv = environment.todaySnapshot.hrv {
            rows.append(WSignalRowModel(title: "HRV", value: "\(Int(hrv.rounded())) ms", detail: "Not estimated from BPM.", symbol: "waveform.path.ecg"))
        }
        if let respiratory = environment.todaySnapshot.respiratoryRate {
            rows.append(WSignalRowModel(title: "Respiratory rate", value: "\(Int(respiratory.rounded())) br/min", detail: "Requires measured or validated source.", symbol: "lungs"))
        }
        if let oxygen = environment.todaySnapshot.oxygenSaturation {
            rows.append(WSignalRowModel(
                title: "SpO2",
                value: "\(Int(oxygen.rounded()))%",
                detail: spo2Metric.signalDetail,
                symbol: "drop",
                tint: spo2Metric.confidence.color
            ))
        }
        if environment.todaySnapshot.rawWristTemperatureC != nil
            || (hasActiveSkinTemperatureBaseline && environment.todaySnapshot.bodyTemperatureDelta != nil) {
            rows.append(skinTemperatureSignalRow)
        }
        return rows
    }

    private var skinTemperatureSignalRow: WSignalRowModel {
        let profile = environment.skinTemperatureBaselineProfile
        if profile.hasActiveBaseline,
           let delta = environment.todaySnapshot.bodyTemperatureDelta {
            return WSignalRowModel(
                title: "Skin temp deviation",
                value: "\(signed(delta)) C",
                detail: profile.isAutomatic
                    ? "Calculated from raw wrist/contact temperature and your private personal baseline."
                    : "Calculated from raw wrist/contact temperature and your temporary baseline.",
                symbol: "thermometer.medium",
                tint: abs(delta) >= 1.0 ? WColors.warning : WColors.success
            )
        }
        if let raw = environment.todaySnapshot.rawWristTemperatureC {
            return WSignalRowModel(
                title: "Raw wrist/contact temp",
                value: String(format: "%.1f C", raw),
                detail: "Direct R10 raw contact temperature. Not a baseline delta. Baseline \(skinBaselineProgressText).",
                symbol: "thermometer.medium",
                tint: WColors.accent
            )
        }
        return WSignalRowModel(
            title: "Skin temp baseline",
            value: skinBaselineProgressText,
            detail: "Collect five sleep/night wrist-temperature days, or set a temporary baseline for now.",
            symbol: "thermometer.medium",
            tint: WColors.warning
        )
    }

    private var hasActiveSkinTemperatureBaseline: Bool {
        environment.skinTemperatureBaselineProfile.hasActiveBaseline
    }

    private var skinTemperatureBaselineRow: WSignalRowModel {
        let profile = environment.skinTemperatureBaselineProfile
        if profile.isAutomatic {
            return WSignalRowModel(
                title: "Skin temperature",
                value: "Ready",
                detail: "Automatic personal baseline is set and kept private.",
                symbol: "thermometer.medium",
                tint: WColors.success
            )
        }
        return WSignalRowModel(
            title: "Skin temperature",
            value: skinBaselineProgressText,
            detail: profile.hasTemporaryBaseline
                ? "Temporary baseline is active until automatic calibration finishes."
                : "Needs five sleep/night wrist-temperature days; temporary baseline is optional.",
            symbol: "thermometer.medium",
            tint: profile.hasTemporaryBaseline ? WColors.accent : WColors.warning
        )
    }

    private var skinBaselineEditor: some View {
        let profile = environment.skinTemperatureBaselineProfile
        return Group {
            if profile.canEditTemporaryBaseline {
                WCard {
                    VStack(alignment: .leading, spacing: WSpacing.m) {
                        Text("Temporary skin baseline")
                            .font(WTypography.headline)
                            .foregroundStyle(WColors.text)
                        Text("Use your normal sleep skin temperature in C. Whoordan replaces this with a private automatic baseline after five eligible days.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        TextField("Example 34.5", text: $customSkinBaselineText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        if let skinBaselineError {
                            Text(skinBaselineError)
                                .font(WTypography.caption)
                                .foregroundStyle(WColors.warning)
                        }
                        HStack {
                            Button {
                                saveTemporarySkinBaseline()
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(WColors.accent)

                            Button {
                                customSkinBaselineText = ""
                                skinBaselineError = nil
                                environment.updateTemporarySkinTemperatureBaselineC(nil)
                            } label: {
                                Label("Clear", systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var needsPrimarySetup: Bool {
        recoveryMetric.value == nil
            || environment.todaySnapshot.sleepMinutes == nil
            || environment.todaySnapshot.movement.steps == nil
            || environment.deviceState.shouldShowPairWearableCTA
    }

    private var primarySetupAction: WCTAAction {
        if environment.deviceState.shouldShowPairWearableCTA {
            return WCTAAction(
                title: "Pair wearable",
                subtitle: "Connect your wearable for live heart rate and device status.",
                symbol: "sensor.tag.radiowaves.forward"
            ) {
                environment.scanForWearable()
            }
        }
        return WCTAAction(
            title: "Build baseline",
            subtitle: "See the signals Whoordan needs before showing confident scores.",
            symbol: "chart.line.uptrend.xyaxis"
        ) {
            prepareSkinBaselineDraft()
            showBaselineInfo = true
        }
    }

    private var skinBaselineProgressText: String {
        let profile = environment.skinTemperatureBaselineProfile
        return "\(min(profile.eligibleDayCount, profile.requiredDayCount))/\(profile.requiredDayCount) days"
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

    private var recoveryMetric: WhoordanMetricSnapshot {
        metricSnapshots.first { $0.id == .recovery } ?? WhoordanMetricSnapshot(
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

    private var dayStrainMetric: WhoordanMetricSnapshot {
        metricSnapshots.first { $0.id == .dayStrain } ?? WhoordanMetricSnapshot(
            id: .dayStrain,
            title: "Day strain",
            value: nil,
            unit: "/21",
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until HR/activity exists",
            accuracyDetail: nil,
            requirements: ["Validated HR/activity windows, or source-labeled/BLE-derived movement inputs"],
            calibrationSummary: nil,
            lastUpdated: nil,
            unavailableReason: "Needs HR/activity windows or source-labeled/BLE-derived movement inputs.",
            context: "Metric catalog did not return day strain.",
            symbol: "figure.run"
        )
    }

    private var heartMetric: WhoordanMetricSnapshot {
        metricSnapshots.first { $0.id == .heartRate } ?? WhoordanMetricSnapshot(
            id: .heartRate,
            title: "Heart rate",
            value: nil,
            unit: "bpm",
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until source exists",
            accuracyDetail: nil,
            requirements: [],
            calibrationSummary: nil,
            lastUpdated: nil,
            unavailableReason: "Needs live or source-labeled heart rate.",
            context: "Metric catalog did not return heart rate.",
            symbol: "heart"
        )
    }

    private var spo2Metric: WhoordanMetricSnapshot {
        metricSnapshots.first { $0.id == .spo2 } ?? WhoordanMetricSnapshot(
            id: .spo2,
            title: "SpO2",
            value: nil,
            unit: "%",
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until source exists",
            accuracyDetail: nil,
            requirements: [],
            calibrationSummary: nil,
            lastUpdated: nil,
            unavailableReason: "Needs measured or safely decoded oxygen saturation.",
            context: "Metric catalog did not return SpO2.",
            symbol: "drop"
        )
    }

    private var sourceStatus: String {
        if environment.deviceState.liveHeartRateBPM != nil {
            return "Wearable"
        }
        if let source = environment.todaySnapshot.source {
            return source.label
        }
        if let source = environment.todaySnapshot.movement.source {
            return source.label
        }
        if environment.healthKitResult.status == .requested {
            return "Apple Health export"
        }
        return "Setup"
    }

    private var syncStatusText: String {
        switch environment.healthSyncResult.status {
        case .uploaded:
            return "Synced"
        case .blocked:
            return environment.consentState.localModeEnabled ? "Local" : "Paused"
        case .failed:
            return "Retry"
        case .nothingToSync:
            return "Local"
        }
    }

    private var heartSummary: String {
        heartMetric.value == nil ? "Setup" : heartMetric.displayValueWithUnit
    }

    private var sleepCardContext: String {
        if environment.todaySnapshot.sleepSummary?.hasSleep == true {
            return "Tap for time in bed, stages when source-labeled, efficiency, need, debt, and consistency."
        }
        if environment.todaySnapshot.sleepMinutes != nil {
            return "Tap for restored sleep duration, source, sleep need, and debt. Stages require decoded sessions."
        }
        return "Tap for the sleep inputs Whoordan needs before a full overnight analysis appears."
    }

    private var sleepCardChips: [String] {
        let sleep = environment.todaySnapshot.sleepSummary
        let main = sleep?.mainSleep
        return [
            environment.todaySnapshot.sleepMinutes.map { "Asleep \(durationText($0))" },
            main.map { "In bed \(durationText($0.inBedMinutes))" },
            main?.efficiencyPercent.map { "Efficiency \(Int($0.rounded()))%" },
            sleep?.restorativePercent.map { "Restorative \(Int($0.rounded()))%" },
            environment.todaySnapshot.sleepNeedMinutes.map { "Need \(durationText($0))" },
            environment.todaySnapshot.sleepDebtMinutes.map { "Debt \(durationText($0))" }
        ].compactMap { $0 }.nonEmptyOr(["Need", "Debt", "Stages"])
    }

    private var recoveryCardContext: String {
        if let accuracy = recoveryMetric.accuracySummary,
           recoveryMetric.value != nil {
            return "\(accuracy). Tap for HRV, resting HR, sleep sufficiency, breathing, and temperature contributors."
        }
        return recoveryMetric.unavailableReason ?? "Tap to see which overnight inputs are still missing."
    }

    private var recoveryCardChips: [String] {
        [
            environment.todaySnapshot.hrv.map { "HRV \(Int($0.rounded())) ms" },
            environment.todaySnapshot.restingHeartRate.map { "RHR \(Int($0.rounded())) bpm" },
            environment.todaySnapshot.respiratoryRate.map { "RR \(String(format: "%.1f", $0))" }
        ].compactMap { $0 }.nonEmptyOr(["HRV", "RHR", "Sleep"])
    }

    private var strainCardChips: [String] {
        [
            environment.todaySnapshot.movement.steps.map { "\($0.formatted()) steps" },
            environment.todaySnapshot.movement.activeEnergyKilocalories.map { "\(Int($0.rounded())) kcal" },
            environment.todaySnapshot.movement.movementMinutes.map { "\(Int($0.rounded())) min" }
        ].compactMap { $0 }.nonEmptyOr(["Zones", "Steps", "Energy"])
    }

    private var trendCardValue: String {
        readyTrendCategoryCount == 0 ? "Building" : "\(readyTrendCategoryCount)/3 ready"
    }

    private var trendCardContext: String {
        readyTrendCategoryCount == 0
            ? "Needs at least two measured days before direction appears."
            : "Open long-term signal direction for recovery, sleep, and movement."
    }

    private var trendCardChips: [String] {
        [
            trendChip(title: "Recovery", values: recoveryTrendValues),
            trendChip(title: "Sleep", values: sleepTrendValues),
            trendChip(title: "Steps", values: movementTrendValues)
        ]
    }

    private var trendCardConfidence: ConfidenceLevel {
        readyTrendCategoryCount == 0 ? .unavailable : .medium
    }

    private var readyTrendCategoryCount: Int {
        [
            recoveryTrendValues.count,
            sleepTrendValues.count,
            movementTrendValues.count
        ].filter { $0 >= 2 }.count
    }

    private var recoveryTrendValues: [Double] {
        environment.recentSummaries.compactMap { $0.recovery?.value }
    }

    private var sleepTrendValues: [Double] {
        environment.recentSummaries.compactMap(\.sleepMinutes)
    }

    private var movementTrendValues: [Double] {
        environment.recentSummaries.compactMap { $0.movement.steps.map(Double.init) }
    }

    private func trendChip(title: String, values: [Double]) -> String {
        values.count >= 2 ? "\(title) ready" : "\(title) building"
    }

    private var stepsText: String {
        guard let steps = environment.todaySnapshot.movement.steps else { return "Setup" }
        return steps.formatted()
    }

    private var stepsCaption: String {
        let movement = environment.todaySnapshot.movement
        guard movement.steps != nil else { return "Connect a step source" }
        let percent = Int(((movement.goalProgress ?? 0) * 100).rounded())
        let source = movement.source?.label ?? "Source labeled"
        return "\(percent)% of \(movement.goal.formatted()) goal - \(source)"
    }

    private var sleepCaption: String {
        guard let sleep = environment.todaySnapshot.sleepSummary else {
            return environment.todaySnapshot.sleepMinutes == nil ? "Connect a sleep source" : "Measured sleep"
        }
        let source = sleep.source?.label ?? "Source labeled"
        if let main = sleep.mainSleep, let efficiency = main.efficiencyPercent {
            return "\(Int(efficiency.rounded()))% efficiency - \(source)"
        }
        if let napMinutes = sleep.napMinutes, napMinutes > 0 {
            return "\(durationText(napMinutes)) naps - \(source)"
        }
        return source
    }

    private func scoreText(_ score: ScoreValue?) -> String {
        guard let score else { return "Building" }
        return "\(Int(score.value.rounded()))"
    }

    private func durationText(_ value: Double?) -> String {
        guard let value else { return "Setup" }
        let hours = Int(value / 60)
        let minutes = Int(value.truncatingRemainder(dividingBy: 60))
        return "\(hours)h \(minutes)m"
    }

    private func prepareSkinBaselineDraft() {
        if environment.skinTemperatureBaselineProfile.hasTemporaryBaseline,
           let baseline = environment.skinTemperatureBaselineProfile.activeBaselineC {
            customSkinBaselineText = String(format: "%.1f", baseline)
        } else {
            customSkinBaselineText = ""
        }
        skinBaselineError = nil
    }

    private func saveTemporarySkinBaseline() {
        let trimmed = customSkinBaselineText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            environment.updateTemporarySkinTemperatureBaselineC(nil)
            skinBaselineError = nil
            return
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized),
              SkinTemperatureBaselineProfile.validBaselineRangeC.contains(value) else {
            skinBaselineError = "Enter a realistic skin temperature baseline from 20 to 45 C."
            return
        }
        skinBaselineError = nil
        environment.updateTemporarySkinTemperatureBaselineC(value)
    }

    private func signed(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }
}

private extension Array where Element == String {
    func nonEmptyOr(_ fallback: [String]) -> [String] {
        isEmpty ? fallback : self
    }
}

private extension WhoordanMetricReadiness {
    var emptyStateSymbol: String {
        switch self {
        case .showNow:
            return "waveform.path.ecg"
        case .betaEstimated:
            return "moon.zzz"
        case .laterBlocked:
            return "lock"
        }
    }
}

private struct MetricMissingGuidance {
    let heroTitle: String
    let heroMessage: String
    let cardTitle: String
    let cardMessage: String
    let steps: [String]
    let symbol: String
    let tint: Color
    let replacesHero: Bool

    static func make(
        for metric: WhoordanMetricSnapshot,
        today: DailyHealthSummary
    ) -> MetricMissingGuidance? {
        let noCurrentSleep = today.sleepSummary?.mainSleep == nil && today.sleepMinutes == nil
        if isSleepFamily(metric.id), noCurrentSleep {
            return MetricMissingGuidance(
                heroTitle: sleepHeroTitle(for: metric.id),
                heroMessage: "Sleep-family metrics unlock after Whoordan has a main sleep from the wearable or a source-labeled import.",
                cardTitle: "What to check",
                cardMessage: "No sleep was detected for this day.",
                steps: [
                    "Wear the device through the night with steady sensor contact.",
                    "Keep the device charged and near the phone after waking so the morning sync can finish.",
                    "If sleep was captured somewhere else, restore or import that source-labeled sleep before expecting sleep, recovery, or sleep-need scores."
                ],
                symbol: "moon.zzz",
                tint: WColors.warning,
                replacesHero: true
            )
        }

        guard metric.value == nil || metric.readiness == .laterBlocked else {
            return nil
        }

        switch metric.id {
        case .recovery:
            return MetricMissingGuidance(
                heroTitle: "Recovery is waiting on overnight signals",
                heroMessage: "Recovery needs enough overnight context before Whoordan can score the day.",
                cardTitle: "What to check",
                cardMessage: "Missing recovery inputs usually come from sleep, HRV, resting HR, or respiratory-rate gaps.",
                steps: [
                    "Wear the device during the main sleep window.",
                    "Let HRV, resting HR, respiratory rate, and sleep finish syncing after waking.",
                    "Open Sleep first if the night was detected but recovery is still missing."
                ],
                symbol: "arrow.clockwise.heart",
                tint: WColors.warning,
                replacesHero: true
            )
        case .dayStrain, .activityStrain, .workoutCalories, .dailyCalories, .steps:
            return MetricMissingGuidance(
                heroTitle: "Activity data is still missing",
                heroMessage: "Whoordan needs movement, workout, energy, or heart-rate coverage before this activity metric is useful.",
                cardTitle: "What to check",
                cardMessage: "The app will fill this once source-labeled movement or BLE-derived activity exists.",
                steps: [
                    "Wear the device during activity and keep local capture enabled.",
                    "Sync near the phone after workouts or longer movement blocks.",
                    "Add profile details in More for calorie estimates that depend on body profile."
                ],
                symbol: "figure.walk",
                tint: WColors.cyan,
                replacesHero: true
            )
        case .heartRate, .averageHeartRate, .heartRateZones, .restingHeartRate, .hrv, .respiratoryRate, .spo2, .rawWristTemperature, .skinTemperatureDelta, .vo2Max:
            return MetricMissingGuidance(
                heroTitle: "Sensor signal is not ready",
                heroMessage: "Whoordan is waiting for a clean source reading before showing this metric.",
                cardTitle: "What to check",
                cardMessage: metric.unavailableReason ?? "The required source has not produced a usable sample yet.",
                steps: metric.requirements.nonEmptyOr([
                    "Confirm the wearable is connected and worn with steady contact.",
                    "Let the source sync again before opening the metric detail.",
                    "Keep missing or estimated values labeled until a validated source exists."
                ]),
                symbol: metric.symbol,
                tint: metric.confidence.color,
                replacesHero: true
            )
        default:
            return MetricMissingGuidance(
                heroTitle: "\(metric.title) is not ready",
                heroMessage: metric.unavailableReason ?? "Whoordan needs more source data before showing this metric.",
                cardTitle: "What to check",
                cardMessage: "The metric appears once its minimum inputs are present.",
                steps: metric.requirements.nonEmptyOr([
                    "Collect more source-labeled data for this metric.",
                    "Sync the wearable near the phone.",
                    "Keep the value hidden until the input quality is clear."
                ]),
                symbol: metric.symbol,
                tint: metric.confidence.color,
                replacesHero: true
            )
        }
    }

    private static func isSleepFamily(_ id: WhoordanMetricID) -> Bool {
        switch id {
        case .sleepDuration, .sleepPerformance, .sleepNeed, .sleepDebt, .sleepConsistency, .sleepStages, .restorativeSleepPercent, .restorativeSleepHours:
            return true
        default:
            return false
        }
    }

    private static func sleepHeroTitle(for id: WhoordanMetricID) -> String {
        switch id {
        case .sleepNeed:
            return "Sleep need is waiting for sleep"
        case .recovery:
            return "Recovery is waiting for sleep"
        default:
            return "No sleep detected yet"
        }
    }
}

struct MetricDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let metric: WhoordanMetricSnapshot
    @State private var timeline: MetricDetailTimeline?
    @State private var isTimelineLoading = false

    var body: some View {
        ZStack {
            WScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: metric.title, subtitle: metric.readiness.label)
                    if let missingGuidance, missingGuidance.replacesHero {
                        WMetricMissingHero(
                            title: missingGuidance.heroTitle,
                            message: missingGuidance.heroMessage,
                            systemImage: missingGuidance.symbol,
                            tint: missingGuidance.tint
                        )
                    } else {
                        WMetricDetailHero(metric: metric, timeline: timeline, isLoading: isTimelineLoading)
                    }
                    if let missingGuidance {
                        WMissingMetricGuidanceCard(
                            title: missingGuidance.cardTitle,
                            message: missingGuidance.cardMessage,
                            steps: missingGuidance.steps,
                            tint: missingGuidance.tint
                        )
                    }
                    WTrendChartCard(
                        title: chartTitle,
                        subtitle: chartSubtitle,
                        timeline: timeline,
                        isLoading: isTimelineLoading,
                        tint: metric.confidence.color
                    )
                    WInsightCallout(
                        title: "How to read this",
                        message: insightMessage,
                        tint: metric.readiness.color
                    )
                    WSignalList(rows: detailRows)
                    if !metric.requirements.isEmpty {
                        WCard {
                            VStack(alignment: .leading, spacing: WSpacing.s) {
                                Text("Requirements")
                                    .font(WTypography.headline)
                                    .foregroundStyle(WColors.text)
                                ForEach(metric.requirements, id: \.self) { requirement in
                                    Label(requirement, systemImage: "checkmark.circle")
                                        .font(WTypography.body)
                                        .foregroundStyle(WColors.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    if let unavailableReason = metric.unavailableReason, missingGuidance == nil {
                        WCard {
                            VStack(alignment: .leading, spacing: WSpacing.s) {
                                Text("Why unavailable")
                                    .font(WTypography.headline)
                                    .foregroundStyle(WColors.text)
                                Text(unavailableReason)
                                    .font(WTypography.body)
                                    .foregroundStyle(WColors.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    WFootnote(text: "Whoordan keeps health data local by default. Estimated and blocked metrics are labeled so the app does not overstate what the sensors or models currently prove.")
                }
                .padding(WSpacing.l)
                .padding(.bottom, WSpacing.xxl)
            }
        }
        .navigationTitle(metric.title)
        .task(id: metric.id) {
            await loadTimeline()
        }
    }

    private func loadTimeline() async {
        isTimelineLoading = true
        await Task.yield()
        defer { isTimelineLoading = false }
        timeline = await environment.loadMetricDetailTimeline(for: metric.id, days: 30, sampleLimit: 160)
    }

    private var missingGuidance: MetricMissingGuidance? {
        MetricMissingGuidance.make(for: metric, today: environment.todaySnapshot)
    }

    private var chartTitle: String {
        switch metric.id {
        case .sleepStages:
            return "Stage trend"
        case .sleepConsistency:
            return "Sleep window trend"
        case .heartRate, .averageHeartRate, .heartRateZones:
            return "Heart trend"
        case .steps:
            return "Activity trend"
        default:
            return "Local trend"
        }
    }

    private var chartSubtitle: String {
        if isTimelineLoading {
            return "Checking saved samples on this device."
        }
        if missingGuidance != nil {
            return "Trend appears after Whoordan has enough source data for this metric."
        }
        if timeline?.points.isEmpty == true {
            return "Trend appears after at least two local samples."
        }
        return "Recent local values saved on this device."
    }

    private var insightMessage: String {
        if let missingGuidance {
            return missingGuidance.heroMessage
        }
        if metric.value == nil {
            return metric.unavailableReason ?? "Whoordan waits for source-labeled data before drawing a confident view."
        }
        if timeline?.wasLimited == true {
            return "The chart samples the latest local records for speed. Source, confidence, and calibration are listed below."
        }
        return metric.accuracySummary ?? "Use this as wellness context alongside source and confidence labels."
    }

    private var detailRows: [WSignalRowModel] {
        var rows = [
            WSignalRowModel(title: "Source", value: metric.source.label, detail: sourceDetail, symbol: "sensor.tag.radiowaves.forward", tint: metric.confidence.color),
            WSignalRowModel(title: "Confidence", value: metric.confidence.label, detail: confidenceDetail, symbol: "checkmark.seal", tint: metric.confidence.color),
            WSignalRowModel(title: "Accuracy", value: metric.accuracySummary ?? "Not rated", detail: metric.accuracyDetail ?? "No validation label is available for this metric yet.", symbol: "target", tint: metric.confidence.color)
        ]
        if let calibration = metric.calibrationSummary {
            rows.append(WSignalRowModel(title: "Calibration", value: "Visible", detail: calibration, symbol: "slider.horizontal.3", tint: metric.readiness.color))
        }
        rows.append(contentsOf: [
            WSignalRowModel(title: "Last updated", value: metric.lastUpdated.map(Self.timeFormatter.string(from:)) ?? "Waiting", detail: "Shown only when the source has a usable timestamp.", symbol: "clock"),
            WSignalRowModel(title: "Readiness", value: metric.readiness.label, detail: readinessDetail, symbol: "chart.bar.doc.horizontal", tint: metric.readiness.color)
        ])
        return rows
    }

    private var sourceDetail: String {
        switch metric.source {
        case .direct:
            return "Direct device or source reading; no proprietary inference."
        case .legacyWearable:
            return "Trusted historical wearable data restored from local or cloud storage."
        case .calculated:
            return "Calculated from app-visible inputs with provenance shown."
        case .mlEstimated:
            return "Estimated and labeled; useful for trend context only."
        case .imported:
            return "Source-labeled from an external or restored source. Apple Health remains export-only."
        case .unavailable:
            return "No validated source is currently available."
        }
    }

    private var confidenceDetail: String {
        switch metric.confidence {
        case .high:
            return "App-ready when source quality stays clean."
        case .medium:
            return "Useful, but model or source assumptions remain visible."
        case .directional:
            return "Use for direction and comparison, not precise interpretation."
        case .low:
            return "Low trust; shown only with explicit caution."
        case .blocked:
            return "Kept out of production metrics until a validated source exists."
        case .unavailable:
            return "No current value."
        }
    }

    private var readinessDetail: String {
        switch metric.readiness {
        case .showNow:
            return "Ready to display with source and confidence labels."
        case .betaEstimated:
            return "Visible as beta or directional with limitations."
        case .laterBlocked:
            return "Tracked as a roadmap/debug item, not promoted as a health metric."
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
