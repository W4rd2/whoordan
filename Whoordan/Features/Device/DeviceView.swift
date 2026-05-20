import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct DeviceView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Device", subtitle: "Wearable connection")
                        WHeroModule(
                            eyebrow: deviceEyebrow,
                            title: deviceTitle,
                            value: environment.deviceState.liveHeartRateBPM.map { "\($0) bpm" },
                            message: deviceMessage,
                            symbol: "sensor.tag.radiowaves.forward",
                            confidence: deviceConfidence
                        )

                        WCard {
                            VStack(alignment: .leading, spacing: WSpacing.m) {
                                HStack {
                                    Label("Wearable", systemImage: "dot.radiowaves.left.and.right")
                                        .font(WTypography.headline)
                                        .foregroundStyle(WColors.text)
                                    Spacer()
                                    WBadge(text: connectionLabel, color: connectionTint)
                                }
                                Text("Whoordan supports user-owned wearable data only when the device is connected, decoded, and reliable.")
                                    .font(WTypography.caption)
                                    .foregroundStyle(WColors.secondary)
                                WPrimaryButton(title: "Scan or reconnect", systemImage: "dot.radiowaves.left.and.right") {
                                    environment.scanForWearable()
                                }
                                if shouldShowAppSettingsButton {
                                    WSecondaryButton(title: "Open Whoordan Settings", systemImage: "gear") {
                                        openAppSettings()
                                    }
                                }
                            }
                        }

                        if !environment.deviceState.candidates.isEmpty {
                            WCard {
                                VStack(alignment: .leading, spacing: WSpacing.m) {
                                    Text("Wearable Discovery")
                                        .font(WTypography.headline)
                                        .foregroundStyle(WColors.text)
                                    candidateSection(
                                        "Compatible and connected",
                                        candidates: compatibleConnected,
                                        empty: "No compatible wearable is currently connected to this iPhone."
                                    )
                                    candidateSection(
                                        "Preferred owned device",
                                        candidates: preferredPending,
                                        empty: "No preferred owned wearable has been discovered yet."
                                    )
                                    candidateSection(
                                        "Compatible nearby",
                                        candidates: compatibleNearby,
                                        empty: "No nearby device is advertising the compatible service."
                                    )
                                    candidateSection(
                                        "Not paired or unknown",
                                        candidates: unknownNearby,
                                        empty: "No other nearby Bluetooth devices were found."
                                    )
                                }
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WSpacing.m) {
                            WMetricTile(title: "Live HR", value: environment.deviceState.liveHeartRateBPM.map { "\($0) bpm" } ?? "Waiting", detail: environment.deviceState.liveHeartRateSource ?? "Connect wearable", symbol: "heart")
                            WMetricTile(title: "Battery", value: batteryValue, detail: batteryDetail, symbol: batterySymbol)
                            WMetricTile(title: "Raw temp", value: environment.deviceState.skinTemperatureC.map { String(format: "%.1f C", $0) } ?? "Waiting", detail: "Raw contact temp, not baseline delta", symbol: "thermometer.medium")
                            WMetricTile(title: "Last sync", value: lastPacketValue, detail: "No raw payloads shown here", symbol: "arrow.triangle.2.circlepath")
                            WMetricTile(title: "Wrist", value: environment.deviceState.isOnWrist.map { $0 ? "On" : "Off" } ?? "Waiting", detail: "Shown when event is decoded", symbol: "hand.raised")
                            WMetricTile(title: "Catch-up", value: environment.deviceState.syncDiagnostics.catchUpState.label, detail: environment.deviceState.syncDiagnostics.detail, symbol: "arrow.down.doc")
                        }

                        NavigationLink {
                            UnknownFramesView()
                        } label: {
                            HStack(spacing: WSpacing.m) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(WColors.accent)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unknown Frames")
                                        .font(WTypography.body.weight(.semibold))
                                        .foregroundStyle(WColors.text)
                                    Text("Watch local candidate and unmapped frame activity without exposing raw payloads.")
                                        .font(WTypography.caption)
                                        .foregroundStyle(WColors.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                WBadge(text: "\(environment.deviceState.unknownFrameObservations.count)", color: WColors.warning)
                            }
                            .padding(WSpacing.m)
                            .frame(maxWidth: .infinity, minHeight: WSpacing.minTap, alignment: .leading)
                            .contentShape(Rectangle())
                            .background(WColors.surface.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        WFootnote(text: "Developer packet diagnostics, capture controls, and protocol counters live in More > Developer Tools.")
                    }
                    .padding(WSpacing.l)
                }
            }
            .navigationTitle("Device")
        }
    }

    private var deviceEyebrow: String {
        environment.deviceState.connection == .realtime ? "Live" : "Device"
    }

    private var deviceTitle: String {
        switch environment.deviceState.connection {
        case .realtime:
            return "Wearable connected"
        case .historicalSync:
            return "Syncing wearable history"
        case .scanning:
            return "Looking for your wearable"
        case .connecting, .discoveringServices, .subscribing, .initializing:
            return "Connecting"
        case .approvalRequired:
            return "Approval required"
        case .idle, .disconnected, .error:
            return "Connect your wearable"
        }
    }

    private var deviceMessage: String {
        if let error = environment.deviceState.lastError {
            return error
        }
        if environment.deviceState.connection == .realtime {
            return environment.deviceState.syncDiagnostics.detail
        }
        if environment.deviceState.connection == .historicalSync {
            return "Saving wearable history locally before acknowledging batches."
        }
        return "Pair the wearable for live heart rate, haptics, alarms, and future source-labeled device data."
    }

    private var deviceConfidence: ConfidenceLevel {
        environment.deviceState.connection == .realtime ? .medium : .unavailable
    }

    private var connectionLabel: String {
        switch environment.deviceState.connection {
        case .realtime: return "Live"
        case .historicalSync: return "Syncing"
        case .scanning, .connecting, .discoveringServices, .subscribing, .initializing: return "Connecting"
        case .approvalRequired: return "Locked"
        case .idle, .disconnected, .error: return "Offline"
        }
    }

    private var connectionTint: Color {
        switch environment.deviceState.connection {
        case .realtime, .historicalSync:
            return WColors.success
        case .scanning, .connecting, .discoveringServices, .subscribing, .initializing:
            return WColors.accent
        case .approvalRequired, .idle, .disconnected, .error:
            return WColors.warning
        }
    }

    private var shouldShowAppSettingsButton: Bool {
        guard let lastError = environment.deviceState.lastError else { return false }
        return lastError.localizedCaseInsensitiveContains("Bluetooth permission is off")
            || lastError.localizedCaseInsensitiveContains("Bluetooth access is restricted")
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }

    private var lastPacketValue: String {
        guard let lastPacketAt = environment.deviceState.lastPacketAt else { return "Waiting" }
        return Self.timeFormatter.string(from: lastPacketAt)
    }

    private var batteryValue: String {
        if let battery = environment.deviceState.batteryPercent {
            return "\(battery)%"
        }
        return environment.deviceState.isCharging == true ? "Charging" : "Waiting"
    }

    private var batteryDetail: String {
        switch (environment.deviceState.isCharging, environment.deviceState.batteryPercent) {
        case (true, .some):
            return "Charging"
        case (true, .none):
            return "Charging; waiting for percent"
        case (false, .some):
            return "Not charging"
        case (false, .none):
            return "Not charging; waiting for percent"
        case (nil, .some):
            return "Charging status waiting"
        case (nil, .none):
            return "Shown when the device reports it"
        }
    }

    private var batterySymbol: String {
        environment.deviceState.isCharging == true ? "battery.100percent.bolt" : "battery.75percent"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var compatibleConnected: [WearableDeviceCandidate] {
        environment.deviceState.candidates.filter { $0.matchesExpectedService && $0.isConnectedToPhone }
    }

    private var preferredPending: [WearableDeviceCandidate] {
        environment.deviceState.candidates.filter { $0.isPreferredOwnedDevice && !$0.matchesExpectedService }
    }

    private var compatibleNearby: [WearableDeviceCandidate] {
        environment.deviceState.candidates.filter { $0.matchesExpectedService && !$0.isConnectedToPhone && !$0.isPreferredOwnedDevice }
    }

    private var unknownNearby: [WearableDeviceCandidate] {
        environment.deviceState.candidates.filter { !$0.matchesExpectedService && !$0.isPreferredOwnedDevice }
    }

    @ViewBuilder
    private func candidateSection(_ title: String, candidates: [WearableDeviceCandidate], empty: String) -> some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            Text(title)
                .font(WTypography.caption)
                .foregroundStyle(WColors.secondary)
            if candidates.isEmpty {
                Text(empty)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.secondary)
            } else {
                ForEach(candidates) { candidate in
                    Button {
                        environment.connectToWearable(candidate)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: WSpacing.xs) {
                                Text(candidate.displayName)
                                    .foregroundStyle(WColors.text)
                                Text(candidate.statusLabel)
                                    .font(WTypography.caption)
                                    .foregroundStyle(WColors.secondary)
                            }
                            Spacer()
                            Text(candidate.rssi == 0 ? "--" : "\(candidate.rssi)")
                                .font(WTypography.caption)
                                .foregroundStyle(WColors.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: WSpacing.minTap, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Connect \(candidate.displayName)")
                    .accessibilityHint(candidate.statusLabel)
                }
            }
        }
    }
}

struct DeveloperToolsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var captureScenario: WearableCaptureScenario = .idle
    @State private var recordingName = ""

    var body: some View {
        ZStack {
            WScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: "Developer Tools", subtitle: "Diagnostics and validation")
                    captureMode
                    packetDiagnostics
                    hapticDiagnostics
                    featureMatrix
                }
                .padding(WSpacing.l)
                .padding(.bottom, WSpacing.xxl)
            }
        }
        .navigationTitle("Developer Tools")
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var captureMode: some View {
        WCard {
            VStack(alignment: .leading, spacing: WSpacing.s) {
                Text("Capture Mode")
                    .font(WTypography.headline)
                    .foregroundStyle(WColors.text)
                Text("Rolling JSONL: Always on")
                Text("Manual capture: \(environment.deviceState.rawCapture.isActive ? "Recording" : "Stopped")")
                Text("Scenario: \(environment.deviceState.rawCapture.scenario.label)")
                Text("Records: \(environment.deviceState.rawCapture.recordCount)")
                if let saved = environment.deviceState.rawCapture.lastSavedFileName {
                    Text("Saved: \(saved)")
                }
                if let direction = environment.deviceState.rawCapture.lastDirection {
                    Text("Last direction: \(direction.rawValue)")
                }
                if let packet = environment.deviceState.rawCapture.lastDecodedPacketType {
                    Text("Last packet: \(packet)")
                }
                if let error = environment.deviceState.rawCapture.lastError {
                    Text(error)
                        .foregroundStyle(WColors.warning)
                }
                Toggle("Local-only capture", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .disabled(true)
                    .accessibilityHint("Raw BLE capture stays on this device until you explicitly share an export.")
                Text("Local-only capture: rolling and manual raw BLE payload JSONL stays in the app documents debug export folder and is excluded from cloud sync, normal exports, and production logs.")
                Text("Files location: On My iPhone > Whoordan > whoordan-ble-debug")
                Text("Manual export: open Files or Finder and copy the JSONL files you need.")
                Text("Background capture is best-effort on iOS. CoreBluetooth restoration can resume some work, but scanning and processing may pause, coalesce, or stop while the app is suspended.")
                #if DEBUG
                Picker("Scenario", selection: $captureScenario) {
                    ForEach(WearableCaptureScenario.allCases) { scenario in
                        Text(scenario.label).tag(scenario)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: captureScenario) { _, scenario in
                    if environment.deviceState.rawCapture.isActive {
                        environment.updateWearableCaptureScenario(scenario)
                    }
                }
                TextField("Recording name", text: $recordingName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                VStack(spacing: WSpacing.s) {
                    WPrimaryButton(title: "Start Capture", systemImage: "record.circle") {
                        environment.startWearableCapture(scenario: captureScenario)
                    }
                    .disabled(environment.deviceState.rawCapture.isActive)
                    WPrimaryButton(title: "Stop and name", systemImage: "square.and.arrow.down") {
                        environment.finishWearableCapture(recordingName: recordingName)
                        if environment.deviceState.rawCapture.lastError == nil {
                            recordingName = ""
                        }
                    }
                    .disabled(!environment.deviceState.rawCapture.isActive || recordingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        environment.stopWearableCapture()
                    } label: {
                        Label("Discard recording", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!environment.deviceState.rawCapture.isActive)
                }
                #else
                Text("Developer capture controls are available only in debug builds.")
                #endif
            }
            .font(WTypography.caption)
            .foregroundStyle(WColors.secondary)
        }
    }

    private var packetDiagnostics: some View {
        WCard {
            VStack(alignment: .leading, spacing: WSpacing.s) {
                Text("Packet Diagnostics")
                    .font(WTypography.headline)
                    .foregroundStyle(WColors.text)
                Text("Connection: \(environment.deviceState.connection.rawValue)")
                Text("Advertising: \(environment.deviceState.advertisingName ?? "Unavailable")")
                Text("Fingerprint: \(environment.deviceState.deviceFingerprint ?? "Unavailable")")
                Text("Command: \(environment.deviceState.lastCommandResponse ?? "None")")
                Text("Range: \(environment.deviceState.dataRangeSummary ?? "Unavailable")")
                Text("Alarm: \(environment.deviceState.alarmSummary ?? "Unavailable")")
                Text("Sync: \(environment.deviceState.historicalSyncSummary ?? "Unavailable")")
                Text("Last ACK: \(environment.deviceState.payloadProcessing.lastBatchAckTokenFingerprint ?? "None")")
                Text("Processed: \(environment.deviceState.payloadProcessing.processedPayloadCount)")
                Text("IMU samples: \(environment.deviceState.payloadProcessing.imuSampleCount)")
                Text("PPG samples: \(environment.deviceState.payloadProcessing.ppgSampleCount)")
                Text("Health samples: \(environment.deviceState.payloadProcessing.safeHealthSampleCount)")
                Text("Direct metrics: \(environment.deviceState.liveAnalytics.directMetricCount)")
                Text("Candidate metrics: \(environment.deviceState.liveAnalytics.candidateMetricCount)")
                Text("Unknown frames: \(environment.deviceState.liveAnalytics.unknownFrameCount)")
                Text("Malformed frames: \(environment.deviceState.payloadProcessing.malformedFrameCount)")
                Text("Dropped fragments: \(environment.deviceState.payloadProcessing.droppedFragmentCount)")
                Text("Log: \(environment.deviceState.firmwareLogSummary ?? "None")")
                if let sample = environment.deviceState.lastNotificationSample {
                    Divider().overlay(WColors.border)
                    Text("Last BLE Sample")
                        .font(WTypography.body.weight(.semibold))
                        .foregroundStyle(WColors.text)
                    Text("Characteristic: \(sample.characteristicUUID)")
                    Text("Bytes: \(sample.byteCount)")
                    Text("Frames: \(sample.frameCount)")
                    Text("Packet: \(sample.packetType ?? "unknown")")
                    Text("Decode: \(sample.decodeStatus)")
                    Text("Payload bytes are intentionally hidden.")
                }
                if !environment.deviceState.discoveredUUIDs.isEmpty {
                    Divider().overlay(WColors.border)
                    Text("UUIDs: \(environment.deviceState.discoveredUUIDs.joined(separator: ", "))")
                }
            }
            .font(WTypography.caption)
            .foregroundStyle(WColors.secondary)
        }
    }

    private var hapticDiagnostics: some View {
        WCard {
            VStack(alignment: .leading, spacing: WSpacing.s) {
                Text("Haptic and Alarm Diagnostics")
                    .font(WTypography.headline)
                    .foregroundStyle(WColors.text)
                Text("Call vibration: \(environment.callVibrationSettings.enabled ? "Enabled" : "Disabled")")
                Text("Last call event: \(environment.lastCallStateEventMessage)")
                Text("Call route: \(environment.lastCallVibrationRouting.reason.rawValue)")
                Text("Call platform: \(environment.callVibrationSettings.platformStatus.label)")
                Text("Alarm count: \(environment.alarms.count)")
                Text("Active alarm: \(environment.activeAlarm?.deliveryStatus.rawValue ?? "None")")
                Text("Alarm scheduler: \(environment.lastAlarmSchedulingResult.status.rawValue)")
                Text("Double tap: \(environment.lastDoubleTapRouting.status.rawValue)")
                Text("Haptic status: \(environment.deviceState.payloadProcessing.lastHapticStatus ?? "No event confirmation")")
                Text("Normal cellular call control remains platform-blocked for third-party apps.")
            }
            .font(WTypography.caption)
            .foregroundStyle(WColors.secondary)
        }
    }

    private var featureMatrix: some View {
        WCard {
            VStack(alignment: .leading, spacing: WSpacing.s) {
                Text("Validation Status")
                    .font(WTypography.headline)
                    .foregroundStyle(WColors.text)
                WSignalList(rows: [
                    WSignalRowModel(title: "Heart rate", value: environment.deviceState.liveHeartRateBPM == nil ? "Needs live packet" : "Device visible", detail: "User-facing when parsed from the device or another source-labeled record.", symbol: "heart"),
                    WSignalRowModel(title: "Raw temperature", value: environment.deviceState.skinTemperatureC == nil ? "Needs R10 temp" : "Device visible", detail: "Shown as raw contact temperature only; baseline delta needs history.", symbol: "thermometer.medium"),
                    WSignalRowModel(title: "Sleep and steps", value: "Capture pending", detail: "Not fabricated from weak motion or HR-only evidence.", symbol: "moon"),
                    WSignalRowModel(title: "Haptics", value: environment.lastVibrationResult.status.rawValue, detail: "Physical pass requires real vibration or event confirmation.", symbol: "waveform.path.ecg")
                ])
            }
        }
    }
}

struct UnknownFramesView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            WScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: "Unknown Frames", subtitle: "Wearable diagnostics")
                    summaryGrid
                    frameTrends
                    observations
                    WFootnote(text: "This page shows sanitized frame classes, counts, and candidate labels only. Raw payload bytes stay hidden and no unconfirmed candidate is promoted into a health metric.")
                }
                .padding(WSpacing.l)
                .padding(.bottom, WSpacing.xxl)
            }
        }
        .navigationTitle("Unknown Frames")
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WSpacing.m) {
            WMetricTile(
                title: "Unknown",
                value: "\(environment.deviceState.liveAnalytics.unknownFrameCount)",
                detail: "Valid frames with no metric map",
                symbol: "questionmark.diamond"
            )
            WMetricTile(
                title: "Candidates",
                value: "\(environment.deviceState.liveAnalytics.candidateMetricCount)",
                detail: environment.deviceState.liveAnalytics.lastCandidateMetric ?? "None observed",
                symbol: "waveform.path.ecg"
            )
            WMetricTile(
                title: "Direct",
                value: "\(environment.deviceState.liveAnalytics.directMetricCount)",
                detail: environment.deviceState.liveAnalytics.lastDirectMetric ?? "No direct metric yet",
                symbol: "checkmark.seal"
            )
            WMetricTile(
                title: "Last packet",
                value: environment.deviceState.lastPacketAt.map { Self.timeFormatter.string(from: $0) } ?? "Waiting",
                detail: environment.deviceState.payloadProcessing.lastRecordType ?? "No record",
                symbol: "clock"
            )
        }
    }

    @ViewBuilder
    private var frameTrends: some View {
        if !environment.deviceState.unknownFrameTrends.isEmpty {
            WCard {
                VStack(alignment: .leading, spacing: WSpacing.s) {
                    Text("Frame Trends")
                        .font(WTypography.headline)
                        .foregroundStyle(WColors.text)
                    ForEach(environment.deviceState.unknownFrameTrends) { trend in
                        trendRow(trend)
                        if trend.id != environment.deviceState.unknownFrameTrends.last?.id {
                            Divider().overlay(WColors.border.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var observations: some View {
        if environment.deviceState.unknownFrameObservations.isEmpty {
            WCard {
                WEmptyState(
                    title: "No observations yet",
                    message: "Connect the wearable and keep the app open to watch unmapped or candidate frame classes as they arrive.",
                    systemImage: "waveform.path.ecg"
                )
            }
        } else {
            WCard {
                VStack(alignment: .leading, spacing: WSpacing.s) {
                    Text("Recent Observations")
                        .font(WTypography.headline)
                        .foregroundStyle(WColors.text)
                    ForEach(environment.deviceState.unknownFrameObservations) { observation in
                        observationRow(observation)
                        if observation.id != environment.deviceState.unknownFrameObservations.last?.id {
                            Divider().overlay(WColors.border.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func observationRow(_ observation: WearableFrameObservation) -> some View {
        HStack(alignment: .top, spacing: WSpacing.m) {
            Image(systemName: symbol(for: observation))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint(for: observation))
                .frame(width: 28, height: 28)
                .background(tint(for: observation).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: WSpacing.s) {
                    Text(observation.label)
                        .font(WTypography.body.weight(.semibold))
                        .foregroundStyle(WColors.text)
                    WBadge(text: observation.observationKind, color: tint(for: observation))
                }
                Text(observation.caveat)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail(for: observation))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(WColors.tertiary)
            }
            Spacer(minLength: WSpacing.s)
            Text(Self.timeFormatter.string(from: observation.observedAt))
                .font(WTypography.caption.monospacedDigit())
                .foregroundStyle(WColors.tertiary)
        }
        .padding(.vertical, WSpacing.s)
    }

    private func trendRow(_ trend: WearableFrameTrendStat) -> some View {
        HStack(alignment: .top, spacing: WSpacing.m) {
            Image(systemName: trend.observationKind == "candidate" ? "waveform.path.ecg" : "questionmark.diamond")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(trend.observationKind == "candidate" ? WColors.warning : WColors.tertiary)
                .frame(width: 28, height: 28)
                .background((trend.observationKind == "candidate" ? WColors.warning : WColors.tertiary).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: WSpacing.s) {
                    Text(trend.frameClass)
                        .font(WTypography.body.weight(.semibold))
                        .foregroundStyle(WColors.text)
                    WBadge(text: "\(trend.count)", color: trend.observationKind == "candidate" ? WColors.warning : WColors.tertiary)
                }
                Text(trend.label)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.secondary)
                Text(trend.lastCandidateValue ?? "\(trend.lastByteCount) bytes last seen")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(WColors.tertiary)
            }
            Spacer(minLength: WSpacing.s)
            Text(Self.timeFormatter.string(from: trend.lastObservedAt))
                .font(WTypography.caption.monospacedDigit())
                .foregroundStyle(WColors.tertiary)
        }
        .padding(.vertical, WSpacing.s)
    }

    private func detail(for observation: WearableFrameObservation) -> String {
        var parts = [
            observation.packetType,
            observation.recordType.map { "R\($0)" } ?? "event",
            "\(observation.byteCount) bytes"
        ]
        if let sampleCount = observation.sampleCount {
            parts.append("\(sampleCount) samples")
        }
        if let candidateValue = observation.candidateValue {
            parts.append(candidateValue)
        }
        return parts.joined(separator: " | ")
    }

    private func symbol(for observation: WearableFrameObservation) -> String {
        switch observation.observationKind {
        case "candidate":
            return "waveform.path.ecg"
        case "raw_debug":
            return "waveform.path"
        default:
            return "questionmark.diamond"
        }
    }

    private func tint(for observation: WearableFrameObservation) -> Color {
        switch observation.observationKind {
        case "candidate":
            return WColors.warning
        case "raw_debug":
            return WColors.accent
        default:
            return WColors.tertiary
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}
