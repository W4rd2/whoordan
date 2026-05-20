import SwiftUI

struct HeartView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showMaxHRInfo = false
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Heart", subtitle: "Signals")
                        sourceState
                        signalRows
                        ctaRow
                        Button {
                            showInfo = true
                        } label: {
                            Label("Heart signal notes", systemImage: "info.circle")
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
            .sheet(isPresented: $showMaxHRInfo) {
                NavigationStack {
                    BodyProfileSettingsView()
                }
            }
            .sheet(isPresented: $showInfo) {
                infoSheet
            }
        }
    }

    private var sourceState: some View {
        WHeroModule(
            eyebrow: "Source",
            title: heartSourceTitle,
            value: liveHeartValue,
            message: heartSourceMessage,
            symbol: "heart",
            confidence: heartConfidence
        )
    }

    private var signalRows: some View {
        WSignalList(rows: [
            metricRow(.restingHeartRate, title: "Resting heart rate", symbol: "heart"),
            metricRow(.hrv, symbol: "waveform.path.ecg"),
            metricRow(.spo2, symbol: "drop"),
            metricRow(.heartRateZones, title: "Zones", symbol: "gauge.with.dots.needle.50percent")
        ])
    }

    private var ctaRow: some View {
        WCTARow(actions: heartActions)
    }

    private var heartActions: [WCTAAction] {
        var actions: [WCTAAction] = []
        if environment.deviceState.shouldShowPairWearableCTA {
            actions.append(pairWearableAction)
        }
        actions.append(
            WCTAAction(
                title: "Set max heart rate",
                subtitle: "Required before zone summaries are useful.",
                symbol: "slider.horizontal.3"
            ) {
                showMaxHRInfo = true
            }
        )
        return actions
    }

    private var pairWearableAction: WCTAAction {
        WCTAAction(
            title: "Pair wearable",
            subtitle: "Use direct HR when the payload confirms it.",
            symbol: "sensor.tag.radiowaves.forward"
        ) {
            environment.scanForWearable()
        }
    }

    private var infoSheet: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: "Heart", subtitle: "Notes")
                    Text("Whoordan shows wellness context from measured heart signals. It does not diagnose cardiac conditions or provide medical monitoring.")
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

    private var heartSourceTitle: String {
        if heartMetric.value != nil, heartMetric.source == .direct {
            return "Wearable live signal"
        }
        if restingMetric.value != nil || hrvMetric.value != nil {
            return environment.todaySnapshot.source?.label ?? "External source connected"
        }
        return "No heart source yet"
    }

    private var heartSourceMessage: String {
        if environment.deviceState.liveHeartRateBPM != nil {
            return "Live HR is used only when the payload confirms a plausible direct value."
        }
        if environment.deviceState.hasConnectedWearable {
            return "Waiting for a decoded wearable heart signal."
        }
        return "Pair your approved wearable before Whoordan shows heart signals."
    }

    private var liveHeartValue: String? {
        if heartMetric.value != nil {
            return heartMetric.displayValueWithUnit
        }
        return restingMetric.value == nil ? nil : restingMetric.displayValueWithUnit
    }

    private var heartConfidence: ConfidenceLevel {
        heartMetric.value == nil ? restingMetric.confidence : heartMetric.confidence
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

    private var heartMetric: WhoordanMetricSnapshot {
        metric(.heartRate, title: "Heart rate", symbol: "heart")
    }

    private var restingMetric: WhoordanMetricSnapshot {
        metric(.restingHeartRate, title: "Resting heart rate", symbol: "heart")
    }

    private var hrvMetric: WhoordanMetricSnapshot {
        metric(.hrv, title: "HRV", symbol: "waveform.path.ecg")
    }

    private func metricRow(_ id: WhoordanMetricID, title: String? = nil, symbol: String) -> WSignalRowModel {
        let metric = metric(id, title: title ?? id.rawValue, symbol: symbol)
        return WSignalRowModel(
            title: title ?? metric.title,
            value: metric.displayValueWithUnit,
            detail: metric.signalDetail,
            symbol: symbol,
            tint: metric.confidence.color
        )
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
}
