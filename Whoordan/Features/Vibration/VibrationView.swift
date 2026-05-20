import SwiftUI

struct VibrationView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "Vibration", subtitle: "Wearable haptics")
                        WHeroModule(
                            eyebrow: connectionSummary,
                            title: "Standard wearable vibration",
                            value: nil,
                            message: "Preview and route the same verified wearable vibration for calls and alarms.",
                            symbol: "waveform.path.ecg",
                            confidence: environment.deviceState.connection == .realtime ? .medium : .unavailable
                        )
                        standardPreview
                        callVibrationControls
                        lastPreview
                        WFootnote(text: "Call routing limits are documented in Developer Tools. Normal cellular call control and Apple Clock alarm events remain platform-blocked.")
                    }
                    .padding(WSpacing.l)
                    .padding(.bottom, WSpacing.xxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var standardPreview: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text("Preview")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WCard {
                Button {
                    Task { await environment.preview(pattern: VibrationPattern.standardPattern(from: environment.vibrationPatterns)) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(VibrationPattern.standard.name)
                                .font(WTypography.body.weight(.semibold))
                                .foregroundStyle(WColors.text)
                            Text("Used for calls and alarms")
                                .font(WTypography.caption)
                                .foregroundStyle(WColors.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WColors.accent)
                    }
                    .padding(.vertical, WSpacing.xs)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview standard wearable vibration")
            }
        }
    }

    private var callVibrationControls: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text("Incoming calls")
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WCard {
                if environment.hasLoadedCallVibrationSettings {
                    VStack(alignment: .leading, spacing: WSpacing.m) {
                        Toggle("Vibrate wearable for iPhone calls", isOn: callVibrationEnabled)
                            .accessibilityIdentifier("call-vibration-toggle")
                        platformNotice("Double tap stops the wearable vibration only. iOS does not allow Whoordan to decline normal cellular calls.")
                        Text(environment.lastCallStateEventMessage)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        if !environment.lastCallVibrationRouting.safeMessage.isEmpty {
                            Text(environment.lastCallVibrationRouting.safeMessage)
                                .font(WTypography.caption)
                                .foregroundStyle(WColors.secondary)
                        }
                    }
                } else {
                    HStack(spacing: WSpacing.s) {
                        ProgressView()
                        Text("Loading vibration settings")
                            .font(WTypography.body.weight(.semibold))
                            .foregroundStyle(WColors.secondary)
                    }
                }
            }
        }
    }

    private var callVibrationEnabled: Binding<Bool> {
        Binding {
            environment.callVibrationSettings.enabled
        } set: { enabled in
            guard enabled != environment.callVibrationSettings.enabled else { return }
            var updated = environment.callVibrationSettings
            updated.enabled = enabled
            environment.saveCallVibrationSettings(updated)
        }
    }

    private var lastPreview: some View {
        WCard {
            VStack(alignment: .leading, spacing: WSpacing.xs) {
                Text("Last preview")
                    .font(WTypography.headline)
                    .foregroundStyle(WColors.text)
                Text(previewStatusText)
                    .font(WTypography.body.weight(.semibold))
                    .foregroundStyle(previewStatusColor)
                Text(environment.lastVibrationResult.message.isEmpty ? "No preview has been sent in this session." : environment.lastVibrationResult.message)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.secondary)
            }
        }
    }

    private var connectionSummary: String {
        environment.deviceState.connection == .realtime ? "Connected" : "Disconnected"
    }

    private var previewStatusText: String {
        switch environment.lastVibrationResult.status {
        case .started, .fired:
            return "Started"
        case .terminated:
            return "Terminated"
        case .notConnected, .deviceDisconnected:
            return "Wearable disconnected"
        case .approvalRequired:
            return "Approval required"
        case .unsupported:
            return "Unsupported"
        case .unsafe, .unsafePattern:
            return "Unsafe pattern"
        case .sending:
            return "Sending"
        case .failed:
            return "Failed"
        }
    }

    private var previewStatusColor: Color {
        switch environment.lastVibrationResult.status {
        case .started, .fired, .terminated:
            return WColors.success
        case .sending:
            return WColors.accent
        default:
            return WColors.warning
        }
    }

    @ViewBuilder
    private func platformNotice(_ text: String) -> some View {
        Label {
            Text(text)
                .font(WTypography.caption)
                .foregroundStyle(WColors.secondary)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(WColors.accent)
        }
    }

}
