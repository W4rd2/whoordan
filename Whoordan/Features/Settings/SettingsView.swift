import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: WSpacing.l) {
                        WScreenHeader(title: "More", subtitle: "Tools and settings")
                        deviceOverview
                        primaryTools
                        secondaryTools
                        developerTools
                    }
                    .padding(WSpacing.l)
                    .padding(.bottom, WSpacing.xxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var deviceOverview: some View {
        NavigationLink {
            DeviceView()
        } label: {
            WCard {
                HStack(alignment: .center, spacing: WSpacing.m) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(WColors.accent)
                        .frame(width: 44, height: 44)
                        .background(WColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: WSpacing.xs) {
                        Text(deviceTitle)
                            .font(WTypography.headline)
                            .foregroundStyle(WColors.text)
                        Text(deviceSubtitle)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(WColors.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: WSpacing.minTap, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Device")
    }

    private var primaryTools: some View {
        toolGroup(
            title: "Wearable",
            items: [
                MoreTool(title: "Device", subtitle: "Connection, battery, and live signal status", symbol: "sensor.tag.radiowaves.forward", destination: AnyView(DeviceView())),
                MoreTool(title: "Vibration", subtitle: "Preview and route wearable vibration", symbol: "waveform.path.ecg", destination: AnyView(VibrationView())),
                MoreTool(title: "Alarms", subtitle: "Wearable alarm vibration and snooze", symbol: "alarm", destination: AnyView(AlarmView()))
            ]
        )
    }

    private var secondaryTools: some View {
        toolGroup(
            title: "Health",
            items: [
                MoreTool(title: "Health Monitor", subtitle: "Metric readiness, confidence, and source provenance", symbol: "chart.bar.doc.horizontal", destination: AnyView(HealthMonitorView())),
                MoreTool(title: "Body Signals", subtitle: "Heart and body metrics when measured", symbol: "heart", destination: AnyView(BodySignalsView())),
                MoreTool(title: "Heart", subtitle: "Live, resting, HRV, SpO2, and zone context", symbol: "heart.text.square", destination: AnyView(HeartView())),
                MoreTool(title: "Strain", subtitle: "Directional activity load and calorie context", symbol: "figure.run", destination: AnyView(StrainDetailView())),
                MoreTool(title: "Stress", subtitle: "Blocked until a validated wellness model exists", symbol: "brain.head.profile", destination: AnyView(StressView())),
                MoreTool(title: "Workouts", subtitle: "Workout context", symbol: "figure.run", destination: AnyView(WorkoutsView())),
                MoreTool(title: "Journal", subtitle: "Private habit notes", symbol: "book.closed", destination: AnyView(JournalView())),
                MoreTool(title: "Trends", subtitle: "Long-term signal direction", symbol: "chart.line.uptrend.xyaxis", destination: AnyView(TrendsView())),
                MoreTool(title: "Strength", subtitle: "Manual strength context", symbol: "dumbbell", destination: AnyView(StrengthView())),
                MoreTool(title: "Settings", subtitle: "Privacy, Apple Health, sync, and account", symbol: "gearshape", destination: AnyView(SettingsView()))
            ]
        )
    }

    private var developerTools: some View {
        toolGroup(
            title: "Developer",
            items: [
                MoreTool(title: "Developer Tools", subtitle: "Capture mode, packet diagnostics, and validation status", symbol: "wrench.and.screwdriver", destination: AnyView(DeveloperToolsView())),
                MoreTool(title: "Unknown Frames", subtitle: "Local candidate and unmapped wearable frame observations", symbol: "waveform.path.ecg", destination: AnyView(UnknownFramesView()))
            ]
        )
    }

    private func toolGroup(title: String, items: [MoreTool]) -> some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            Text(title)
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            WCard {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        NavigationLink {
                            item.destination
                        } label: {
                            HStack(spacing: WSpacing.m) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(WColors.accent)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(WTypography.body.weight(.semibold))
                                        .foregroundStyle(WColors.text)
                                    Text(item.subtitle)
                                        .font(WTypography.caption)
                                        .foregroundStyle(WColors.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WColors.tertiary)
                            }
                            .padding(.vertical, WSpacing.s)
                            .frame(maxWidth: .infinity, minHeight: WSpacing.minTap, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel(item.title)
                        .accessibilityHint(item.subtitle)
                        .buttonStyle(.plain)
                        if item.id != items.last?.id {
                            Divider()
                                .overlay(WColors.border)
                        }
                    }
                }
            }
        }
    }

    private var deviceTitle: String {
        switch environment.deviceState.connection {
        case .realtime:
            return environment.deviceState.liveHeartRateBPM.map { "Live HR \($0) bpm" } ?? "Wearable live"
        case .historicalSync, .initializing, .subscribing, .discoveringServices, .connecting:
            return "Wearable connecting"
        case .scanning:
            return "Scanning"
        case .approvalRequired:
            return "Approval required"
        case .idle, .disconnected, .error:
            return "Wearable not connected"
        }
    }

    private var deviceSubtitle: String {
        if environment.deviceState.isCharging == true, let battery = environment.deviceState.batteryPercent {
            return "Charging, battery \(battery)%. Last packet \(lastPacketText)."
        }
        if environment.deviceState.isCharging == true {
            return "Charging. Last packet \(lastPacketText)."
        }
        if let battery = environment.deviceState.batteryPercent {
            return "Battery \(battery)%. Last packet \(lastPacketText)."
        }
        return "Open Device to pair or check the last sync."
    }

    private var lastPacketText: String {
        guard let lastPacketAt = environment.deviceState.lastPacketAt else { return "not seen yet" }
        return Self.timeFormatter.string(from: lastPacketAt)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private struct MoreTool: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let destination: AnyView
}

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(AppThemePreference.storageKey) private var themePreference = AppThemePreference.system.rawValue
    @State private var confirmsLocalErase = false
    @State private var confirmsAccountDeletion = false

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                List {
                    Section("Appearance") {
                        Picker("Theme", selection: $themePreference) {
                            ForEach(AppThemePreference.allCases) { preference in
                                Text(preference.title).tag(preference.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint("Changes Whoordan between system, light, and dark appearance.")

                        Text("System follows this iPhone's appearance setting.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        Text("Theme preference syncs with your approved Whoordan account.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Permissions") {
                        Button {
                            environment.requestBluetoothAccess()
                        } label: {
                            Label("Bluetooth and wearable", systemImage: "dot.radiowaves.left.and.right")
                        }
                        Text(bluetoothPermissionText)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)

                        Label("Apple Health export", systemImage: "heart.text.square")
                        Text("Apple Health: \(environment.healthKitResult.status.rawValue). \(environment.healthKitResult.message)")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)

                        Button {
                            Task { await environment.requestNotificationPermission() }
                        } label: {
                            Label("Notifications", systemImage: "bell.badge")
                        }
                        Text("Notifications: \(environment.notificationPermissionResult.status.label). \(environment.notificationPermissionResult.message)")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)

                        Text("Whoordan automatically requests Bluetooth, Apple Health export, and notifications on first approved launch. Health and wearable data stay local unless cloud sync is explicitly enabled.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Privacy Mode") {
                        Toggle("Local mode", isOn: Binding(
                            get: { true },
                            set: { value in
                                environment.updateConsent {
                                    $0.localModeEnabled = true
                                }
                            }
                        ))
                        .allowsHitTesting(false)
                        Toggle("Cloud sync", isOn: Binding(
                            get: { environment.consentState.cloudSyncEnabled },
                            set: { value in
                                environment.setCloudSyncEnabled(value)
                            }
                        ))
                        Text(
                            "Local storage is always on. Turning on Cloud sync restores and syncs approved "
                                + "account settings, baselines, daily summaries, and health samples."
                        )
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Body Profile") {
                        NavigationLink {
                            BodyProfileSettingsView()
                        } label: {
                            Label("Birth date, sex, height, weight", systemImage: "person.crop.circle.badge.checkmark")
                        }
                        Text(environment.bodyProfile.profileCompletionSummary)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        Text("Used for wellness estimates and saved to your approved account for device-to-device setup. Health samples still require separate cloud health sync consent.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Apple Health") {
                        Text("Status: \(environment.healthKitResult.status.rawValue)")
                            .foregroundStyle(WColors.secondary)
                        Text(environment.healthKitResult.message)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        Text("Exported samples this session: \(environment.healthKitExportedSampleCount)")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Cloud Health Sync") {
                        Text("Consent: \(environment.consentState.canUploadHealthData ? "On" : "Off")")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        Text(environment.healthSyncResult.message)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Account Sync") {
                        Text(environment.accountSyncResult.message)
                            .font(WTypography.caption)
                            .foregroundStyle(environment.accountSyncResult.status == .failed ? WColors.warning : WColors.secondary)
                    }
                    Section("Account") {
                        Button("Refresh Approval") {
                            Task { try? await environment.refreshApproval() }
                        }
                        Button("Prepare Local Data Export") {
                            Task { await environment.prepareLocalDataExport() }
                        }
                        if let exportURL = environment.localDataExportURL {
                            ShareLink(item: exportURL) {
                                Label("Share Prepared Export", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button("Erase Local Data and Sign Out", role: .destructive) {
                            confirmsLocalErase = true
                        }
                        Button("Request Account Deletion", role: .destructive) {
                            confirmsAccountDeletion = true
                        }
                        Text(environment.privacyActionMessage)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                        Text("Account deletion requests use your signed-in session and are processed server-side.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                    Section("Legal") {
                        Text("Whoordan is for personal wellness and fitness context. It does not diagnose, treat, prevent, or cure disease.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .onChange(of: themePreference) { _, _ in
                    Task { await environment.syncAccountSettingsNow() }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Erase local data?",
                isPresented: $confirmsLocalErase,
                titleVisibility: .visible
            ) {
                Button("Erase Local Data and Sign Out", role: .destructive) {
                    Task { await environment.eraseLocalDataAndSignOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes Whoordan data stored on this iPhone. It does not delete cloud account records.")
            }
            .confirmationDialog(
                "Request account deletion?",
                isPresented: $confirmsAccountDeletion,
                titleVisibility: .visible
            ) {
                Button("Request Account Deletion", role: .destructive) {
                    Task { await environment.requestAccountDeletion() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This asks W4rd2 to delete your Whoordan account and associated cloud data.")
            }
        }
    }

    private var bluetoothPermissionText: String {
        if let error = environment.deviceState.lastError {
            return "Bluetooth: \(error)"
        }
        switch environment.deviceState.connection {
        case .realtime:
            return "Bluetooth: wearable connected to Whoordan."
        case .scanning, .connecting, .discoveringServices, .subscribing, .initializing, .historicalSync:
            return "Bluetooth: request started; follow any iOS prompt and keep the wearable nearby."
        case .approvalRequired:
            return "Bluetooth: available after account approval."
        case .idle:
            return "Bluetooth: not requested in this session."
        case .disconnected:
            return "Bluetooth: not connected to Whoordan."
        case .error:
            return "Bluetooth: check iOS Settings and scan again."
        }
    }
}

struct BodyProfileSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var birthDate: Date?
    @State private var biologicalSex: BiologicalSex = .notSet
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var maxHeartRateText = ""
    @State private var saveMessage: String?

    var body: some View {
        ZStack {
            WScreenBackground()
            List {
                Section("Required for Energy") {
                    birthDateInput
                    Picker("Biological sex", selection: $biologicalSex) {
                        ForEach(BiologicalSex.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    TextField("Height (cm)", text: $heightText)
                        .keyboardType(.decimalPad)
                    TextField("Weight (kg)", text: $weightText)
                        .keyboardType(.decimalPad)
                }

                Section("Heart Zones") {
                    TextField("Max heart rate (optional bpm)", text: $maxHeartRateText)
                        .keyboardType(.decimalPad)
                    Text("If max HR is blank, Whoordan can use age-estimated max HR for beta zone context.")
                        .font(WTypography.caption)
                        .foregroundStyle(WColors.secondary)
                }

                Section {
                    Button {
                        saveProfile()
                    } label: {
                        Label("Save body profile", systemImage: "checkmark.circle")
                    }
                    if let saveMessage {
                        Text(saveMessage)
                            .font(WTypography.caption)
                            .foregroundStyle(saveMessage == "Saved to account." ? WColors.success : WColors.warning)
                    }
                } footer: {
                    Text("These inputs sync to your approved Whoordan account for setup continuity and are used for wellness estimates only. Whoordan does not use them for diagnosis or treatment guidance.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Body Profile")
        .onAppear(perform: loadProfile)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var birthDateInput: some View {
        if birthDate == nil {
            Button {
                birthDate = defaultBirthDate
            } label: {
                Label("Add birth date", systemImage: "calendar.badge.plus")
            }
            Text(legacyAgeText ?? "Used to calculate age automatically as time passes.")
                .font(WTypography.caption)
                .foregroundStyle(WColors.secondary)
        } else {
            DatePicker(
                "Birth date",
                selection: birthDateBinding,
                in: birthDateRange,
                displayedComponents: .date
            )
            if let calculatedAgeText {
                Text(calculatedAgeText)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.secondary)
            }
            Button(role: .destructive) {
                birthDate = nil
            } label: {
                Label("Remove birth date", systemImage: "calendar.badge.minus")
            }
        }
    }

    private func loadProfile() {
        let profile = environment.bodyProfile
        birthDate = profile.birthDate
        biologicalSex = profile.biologicalSex
        heightText = text(for: profile.heightCentimeters)
        weightText = text(for: profile.weightKilograms)
        maxHeartRateText = text(for: profile.configuredMaxHeartRate)
        saveMessage = nil
    }

    private func saveProfile() {
        let profile = BodyProfile(
            birthDate: birthDate,
            ageYears: birthDate == nil ? environment.bodyProfile.ageYears : nil,
            biologicalSex: biologicalSex,
            heightCentimeters: doubleValue(heightText),
            weightKilograms: doubleValue(weightText),
            configuredMaxHeartRate: doubleValue(maxHeartRateText)
        )
        if let validationError = profile.validationError() {
            saveMessage = validationError
            return
        }
        environment.updateBodyProfile(profile)
        saveMessage = "Saved to account."
    }

    private func doubleValue(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func text(for value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { birthDate ?? defaultBirthDate },
            set: { birthDate = $0 }
        )
    }

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let latest = calendar.date(byAdding: .year, value: -BodyProfile.validAgeYears.lowerBound, to: Date()) ?? Date()
        let earliest = calendar.date(byAdding: .year, value: -BodyProfile.validAgeYears.upperBound, to: Date()) ?? latest
        return earliest...latest
    }

    private var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    private var calculatedAgeText: String? {
        guard let birthDate else { return nil }
        let profile = BodyProfile(birthDate: birthDate)
        guard let age = profile.resolvedAgeYears() else { return nil }
        return "Age updates automatically: \(age)."
    }

    private var legacyAgeText: String? {
        guard let age = environment.bodyProfile.ageYears else { return nil }
        return "Using saved age \(age) until you add a birth date."
    }
}

struct AlarmView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var draftLabel = "Alarm"
    @State private var draftTime = Date()
    @State private var draftRepeatDays: Set<Int> = []
    @State private var draftSnoozeEnabled = true
    @State private var draftSnoozeMinutes = 9
    @State private var draftMaxSnoozes = 3
    @State private var editingAlarmID: UUID?

    var body: some View {
        ZStack {
            WScreenBackground()
            List {
                if let active = environment.activeAlarm {
                    Section("Active alarm") {
                        VStack(alignment: .leading, spacing: WSpacing.xs) {
                            Text(active.label)
                                .font(WTypography.body.weight(.semibold))
                            Text("Status: \(active.deliveryStatus.rawValue)")
                                .font(WTypography.caption)
                                .foregroundStyle(WColors.secondary)
                        }
                        HStack {
                            Button("Snooze") {
                                Task { _ = await environment.snoozeAlarm(id: active.id) }
                            }
                            .disabled(!active.snoozeEnabled)
                            Button("Dismiss", role: .destructive) {
                                Task { _ = await environment.dismissAlarm(id: active.id) }
                            }
                        }
                    }
                }

                Section("Alarms") {
                    if environment.alarms.isEmpty {
                        Text("Saved alarms will appear here.")
                            .foregroundStyle(WColors.secondary)
                    } else {
                        ForEach(environment.alarms) { alarm in
                            alarmRow(alarm)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                environment.deleteAlarm(id: environment.alarms[index].id)
                            }
                        }
                    }
                }

                Section(editingAlarmID == nil ? "Create alarm" : "Edit alarm") {
                    TextField("Label", text: $draftLabel)
                    DatePicker("Time", selection: $draftTime, displayedComponents: .hourAndMinute)
                    repeatDaysControl
                    Toggle("Snooze", isOn: $draftSnoozeEnabled)
                    Stepper("Snooze \(draftSnoozeMinutes) min", value: $draftSnoozeMinutes, in: 1...60)
                        .disabled(!draftSnoozeEnabled)
                    Stepper("Max snoozes \(draftMaxSnoozes)", value: $draftMaxSnoozes, in: 0...10)
                        .disabled(!draftSnoozeEnabled)
                    Button(editingAlarmID == nil ? "Save Alarm" : "Update Alarm") {
                        saveDraft()
                    }
                    Button("Reset Draft", role: .cancel) {
                        resetDraft()
                    }
                }

                Section("Delivery") {
                    Text("Whoordan schedules a local iOS notification as the fallback reminder. Wearable vibration is attempted when the app can run and the connected device supports haptics.")
                        .font(WTypography.caption)
                        .foregroundStyle(WColors.secondary)
                    Text(deliveryStatusText)
                        .font(WTypography.caption)
                        .foregroundStyle(WColors.secondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Alarms")
    }

    private func alarmRow(_ alarm: Alarm) -> some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: WSpacing.xs) {
                    Text(alarm.displayTime)
                        .font(WTypography.title)
                    Text(alarm.label)
                        .font(WTypography.body)
                }
                Spacer()
                Toggle("Enabled", isOn: Binding(
                    get: { alarm.enabled },
                    set: { value in
                        var updated = alarm
                        updated.enabled = value
                        environment.saveAlarm(updated)
                    }
                ))
                .labelsHidden()
            }
            Text(alarmDetail(alarm))
                .font(WTypography.caption)
                .foregroundStyle(WColors.secondary)
            HStack {
                Button("Edit") { load(alarm) }
                Button("Preview") {
                    Task { await environment.preview(pattern: VibrationPattern.standardPattern(from: environment.vibrationPatterns)) }
                }
                Button("Delete", role: .destructive) {
                    environment.deleteAlarm(id: alarm.id)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, WSpacing.xs)
    }

    private var repeatDaysControl: some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            Text("Repeat days")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: WSpacing.xs) {
                ForEach(Self.weekdays, id: \.weekday) { day in
                    Button(day.short) {
                        if draftRepeatDays.contains(day.weekday) {
                            draftRepeatDays.remove(day.weekday)
                        } else {
                            draftRepeatDays.insert(day.weekday)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(draftRepeatDays.contains(day.weekday) ? WColors.accent : WColors.secondary)
                }
            }
            Text(draftRepeatDays.isEmpty ? "One-time next occurrence" : "Repeats on selected days")
                .font(WTypography.caption)
                .foregroundStyle(WColors.secondary)
        }
    }

    private func saveDraft() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: draftTime)
        let existing = editingAlarmID.flatMap { id in environment.alarms.first(where: { $0.id == id }) }
        let alarm = Alarm(
            id: editingAlarmID ?? UUID(),
            label: draftLabel,
            enabled: existing?.enabled ?? true,
            hour: components.hour ?? 7,
            minute: components.minute ?? 0,
            repeatDays: Array(draftRepeatDays).sorted(),
            vibrationPatternID: VibrationPattern.standardID,
            snoozeEnabled: draftSnoozeEnabled,
            snoozeMinutes: draftSnoozeMinutes,
            maxSnoozes: draftMaxSnoozes,
            createdAt: existing?.createdAt ?? Date(),
            syncStatus: existing?.syncStatus ?? .notQueued
        )
        environment.saveAlarm(alarm)
        resetDraft()
    }

    private func load(_ alarm: Alarm) {
        draftLabel = alarm.label
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        draftTime = Calendar.current.date(from: components) ?? Date()
        draftRepeatDays = Set(alarm.repeatDays)
        draftSnoozeEnabled = alarm.snoozeEnabled
        draftSnoozeMinutes = alarm.snoozeMinutes
        draftMaxSnoozes = alarm.maxSnoozes
        editingAlarmID = alarm.id
    }

    private func resetDraft() {
        draftLabel = "Alarm"
        draftTime = Date()
        draftRepeatDays = []
        draftSnoozeEnabled = true
        draftSnoozeMinutes = 9
        draftMaxSnoozes = 3
        editingAlarmID = nil
    }

    private func alarmDetail(_ alarm: Alarm) -> String {
        let next = alarm.nextTriggerAt.map { Self.dateFormatter.string(from: $0) } ?? "Not scheduled"
        let repeatText = alarm.repeatDays.isEmpty
            ? "One-time"
            : alarm.repeatDays.compactMap { weekday in Self.weekdays.first(where: { $0.weekday == weekday })?.short }.joined(separator: ", ")
        return "\(repeatText). Next: \(next)."
    }

    private var deliveryStatusText: String {
        switch environment.lastAlarmSchedulingResult.status {
        case .scheduled:
            return "Local notification scheduled."
        case .canceled:
            return "No active local alarm notification."
        case .approvalRequired:
            return "Approval is required before alarms."
        case .unsupported:
            return environment.lastAlarmSchedulingResult.message
        case .failed:
            return "Alarm scheduling failed. Try again."
        }
    }

    private static let weekdays: [(weekday: Int, short: String)] = [
        (1, "Sun"),
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat")
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct MovementView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            WScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: "Activity", subtitle: "Steps, distance, and active energy")
                    WHeroModule(
                        eyebrow: environment.todaySnapshot.movement.source?.label ?? "Setup",
                        title: movementTitle,
                        value: movementHeroValue,
                        message: movementMessage,
                        symbol: "shoeprints.fill",
                        confidence: environment.todaySnapshot.movement.confidence
                    )
                    if environment.todaySnapshot.movement.steps == nil,
                       environment.deviceState.shouldShowPairWearableCTA {
                        WCTARow(actions: [activitySetupAction])
                    }
                    stepGoalControl
                    if hasMovementData {
                        WSignalList(rows: movementRows)
                    }
                    WSignalList(rows: trendRows)
                    WSignalList(rows: dailyRows)
                    WFootnote(text: "Wearable steps appear only after a reliable step/activity record is decoded. Apple Health is export-only in this build.")
                }
                .padding(WSpacing.l)
                .padding(.bottom, WSpacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var stepGoalControl: some View {
        WCard {
            Stepper(
                value: Binding(
                    get: { environment.todaySnapshot.movement.goal },
                    set: { environment.updateStepGoal($0) }
                ),
                in: 1_000...40_000,
                step: 500
            ) {
                VStack(alignment: .leading, spacing: WSpacing.xs) {
                    Text("Step goal")
                        .font(WTypography.body.weight(.semibold))
                        .foregroundStyle(WColors.text)
                    Text("\(environment.todaySnapshot.movement.goal.formatted()) steps")
                        .font(WTypography.caption)
                        .foregroundStyle(WColors.secondary)
                }
            }
        }
    }

    private var movementRows: [WSignalRowModel] {
        let movement = environment.todaySnapshot.movement
        return [
            WSignalRowModel(
                title: "Goal progress",
                value: movement.goalProgress.map { "\(Int(($0 * 100).rounded()))%" } ?? "Building",
                detail: movement.steps == nil ? "Connect a reliable wearable step source." : "\(movement.goal.formatted()) step goal",
                symbol: "target"
            ),
            WSignalRowModel(
                title: "Active energy",
                value: workoutCaloriesMetric.displayValueWithUnit,
                detail: workoutCaloriesMetric.signalDetail,
                symbol: "flame",
                tint: workoutCaloriesMetric.confidence.color
            ),
            WSignalRowModel(
                title: "Distance",
                value: movement.walkingRunningDistanceMeters.map { distanceText($0) } ?? "Not reported",
                detail: "Walking and running distance only.",
                symbol: "map"
            ),
            WSignalRowModel(
                title: "Last updated",
                value: movement.lastUpdated.map { Self.timeFormatter.string(from: $0) } ?? "Not yet",
                detail: movement.source?.label ?? "Connect a compatible wearable.",
                symbol: "clock"
            )
        ]
    }

    private var trendRows: [WSignalRowModel] {
        let summaries = environment.recentSummaries
        let steps = summaries.compactMap(\.movement.steps)
        let average = steps.isEmpty ? nil : Int((Double(steps.reduce(0, +)) / Double(steps.count)).rounded())
        let best = steps.max()
        return [
            WSignalRowModel(
                title: "7-day average",
                value: steps.count < 2 ? "Not enough data" : average.map { $0.formatted() } ?? "Not enough data",
                detail: steps.count < 2 ? "Needs at least two days with decoded steps." : "\(steps.count) days with steps.",
                symbol: "chart.bar"
            ),
            WSignalRowModel(
                title: "Best day",
                value: best.map { $0.formatted() } ?? "Not enough data",
                detail: steps.isEmpty ? "No decoded step days stored yet." : "From locally stored source-labeled or BLE-derived steps.",
                symbol: "trophy"
            ),
            WSignalRowModel(
                title: "Trend",
                value: movementTrendText,
                detail: "Compares the latest step day with the prior measured days.",
                symbol: "chart.line.uptrend.xyaxis"
            )
        ]
    }

    private var dailyRows: [WSignalRowModel] {
        let formatter = Self.dayFormatter
        let rows = environment.recentSummaries.suffix(7).map { summary in
            WSignalRowModel(
                title: formatter.string(from: summary.date),
                value: summary.movement.steps.map { $0.formatted() } ?? "Building",
                detail: summary.movement.source?.label ?? "Setup",
                symbol: "shoeprints.fill"
            )
        }
        return rows.isEmpty
            ? [
                WSignalRowModel(
                    title: "Daily steps",
                    value: "Building",
                    detail: "Connect a compatible wearable with reliable steps.",
                    symbol: "calendar"
                )
            ]
            : rows
    }

    private var movementTitle: String {
        let movement = environment.todaySnapshot.movement
        guard let steps = movement.steps else {
            if movement.activeEnergyKilocalories != nil || movement.walkingRunningDistanceMeters != nil || movement.movementMinutes != nil {
                return "Activity recorded"
            }
            return "Set up activity"
        }
        let percent = Int(((environment.todaySnapshot.movement.goalProgress ?? 0) * 100).rounded())
        return "\(steps.formatted()) steps, \(percent)% of goal"
    }

    private var movementHeroValue: String? {
        let movement = environment.todaySnapshot.movement
        if let steps = movement.steps {
            return steps.formatted()
        }
        if let energy = movement.activeEnergyKilocalories {
            return "\(Int(energy.rounded())) kcal"
        }
        if let distance = movement.walkingRunningDistanceMeters {
            return distanceText(distance)
        }
        if let minutes = movement.movementMinutes {
            return "\(Int(minutes.rounded())) min"
        }
        return nil
    }

    private var movementMessage: String {
        let movement = environment.todaySnapshot.movement
        if movement.steps == nil {
            if hasMovementData {
                return "Showing available activity signals while reliable decoded steps are still building."
            }
            return "Wearable step support will appear only after reliable packets are decoded."
        }
        if movement.source == .whoordanEstimate {
            return "Steps are calculated from R10 IMU peaks and remain low confidence until local step labels exist."
        }
        return "Movement is source-labeled and used as a strain contributor when heart-rate intensity is available."
    }

    private var hasMovementData: Bool {
        let movement = environment.todaySnapshot.movement
        return movement.steps != nil
            || movement.activeEnergyKilocalories != nil
            || movement.walkingRunningDistanceMeters != nil
            || movement.movementMinutes != nil
            || movement.lastUpdated != nil
            || workoutCaloriesMetric.value != nil
    }

    private var movementTrendText: String {
        let values = environment.recentSummaries.compactMap(\.movement.steps)
        guard values.count >= 2, let latest = values.last else { return "Not enough data" }
        let prior = values.dropLast()
        let priorAverage = Double(prior.reduce(0, +)) / Double(prior.count)
        let delta = Double(latest) - priorAverage
        if abs(delta) < 500 { return "Stable" }
        return delta > 0 ? "Up" : "Down"
    }

    private var workoutCaloriesMetric: WhoordanMetricSnapshot {
        metric(.workoutCalories, title: "Workout calories", symbol: "flame")
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

    private var activitySetupAction: WCTAAction {
        WCTAAction(
            title: "Pair wearable",
            subtitle: "Use decoded wearable activity only after a reliable source appears.",
            symbol: "sensor.tag.radiowaves.forward"
        ) {
            environment.scanForWearable()
        }
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1_000 {
            return String(format: "%.1f km", meters / 1_000)
        }
        return "\(Int(meters.rounded())) m"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

struct WorkoutsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        FeatureStatusView(
            title: "Workouts",
            subtitle: "Training context",
            symbol: "figure.run",
            heroTitle: workoutCaloriesMetric.value == nil ? "No workout today" : "Workout context available",
            heroValue: workoutCaloriesMetric.value == nil ? environment.todaySnapshot.movement.movementMinutes.map { "\(Int($0.rounded()))m" } : workoutCaloriesMetric.displayValueWithUnit,
            message: "Whoordan automatically exports HealthKit-supported, source-labeled samples to Apple Health after permission is granted. App-only scores remain inside Whoordan when Apple Health has no matching type.",
            actions: [],
            rows: [
                WSignalRowModel(title: "Duration", value: environment.todaySnapshot.movement.movementMinutes.map { "\(Int($0.rounded()))m" } ?? "Add when available", detail: "Workout samples or active-energy estimate.", symbol: "timer"),
                WSignalRowModel(title: "Active energy", value: workoutCaloriesMetric.displayValueWithUnit, detail: workoutCaloriesMetric.signalDetail, symbol: "flame", tint: workoutCaloriesMetric.confidence.color),
                WSignalRowModel(title: "Distance", value: environment.todaySnapshot.movement.walkingRunningDistanceMeters.map { "\(Int($0.rounded())) m" } ?? "Not reported", detail: "Only when source-labeled.", symbol: "map")
            ]
        )
    }

    private var workoutCaloriesMetric: WhoordanMetricSnapshot {
        WhoordanMetricCatalog.metrics(
            summary: environment.todaySnapshot,
            deviceState: environment.deviceState,
            baselineProfile: environment.skinTemperatureBaselineProfile,
            bodyProfile: environment.bodyProfile,
            recentSummaries: environment.recentSummaries,
            now: Date()
        ).first { $0.id == .workoutCalories } ?? WhoordanMetricSnapshot(
            id: .workoutCalories,
            title: "Workout calories",
            value: nil,
            unit: "kcal",
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until workout energy exists",
            accuracyDetail: nil,
            requirements: [],
            calibrationSummary: nil,
            lastUpdated: nil,
            unavailableReason: "Needs source-labeled workout energy or movement-derived activity.",
            context: "Metric catalog did not return workout calories.",
            symbol: "flame"
        )
    }
}

struct StrengthView: View {
    var body: some View {
        FeatureStatusView(
            title: "Strength",
            subtitle: "Manual lifting context",
            symbol: "dumbbell",
            heroTitle: "Strength logging is scaffolded",
            heroValue: nil,
            message: "Exercises, sets, reps, weight, and muscular-load estimates need a dedicated logging model before they can affect strain.",
            actions: [],
            rows: [
                WSignalRowModel(title: "Exercises", value: "Planned", detail: "No hardcoded workouts.", symbol: "list.bullet"),
                WSignalRowModel(title: "Muscular load", value: "Needs model", detail: "Will be labeled as an estimate when implemented.", symbol: "chart.bar")
            ]
        )
    }
}

struct BodySignalsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        FeatureStatusView(
            title: "Body Signals",
            subtitle: "Measured heart and respiratory context",
            symbol: "waveform.path.ecg",
            heroTitle: environment.todaySnapshot.restingHeartRate == nil ? "Connect a signal source" : "Signals available",
            heroValue: environment.todaySnapshot.restingHeartRate.map { "\(Int($0.rounded())) bpm" },
            message: "RHR, HRV, respiratory rate, SpO2, and temperature deviation are displayed only when measured or safely decoded.",
            actions: bodySignalActions,
            rows: bodySignalRows
        )
    }

    private var bodySignalActions: [WCTAAction] {
        guard environment.deviceState.shouldShowPairWearableCTA else { return [] }
        return [
            WCTAAction(
                title: "Pair wearable",
                subtitle: "Use direct measured signals after approval.",
                symbol: "sensor.tag.radiowaves.forward"
            ) {
                environment.scanForWearable()
            }
        ]
    }

    private var bodySignalRows: [WSignalRowModel] {
        [
                WSignalRowModel(title: "Resting heart rate", value: environment.todaySnapshot.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "Connect source", detail: "Measured or source-labeled only.", symbol: "heart"),
                WSignalRowModel(title: "HRV", value: environment.todaySnapshot.hrv.map { "\(Int($0.rounded())) ms" } ?? "Connect HRV source", detail: "Never computed from BPM alone.", symbol: "waveform.path.ecg"),
                WSignalRowModel(title: "Respiratory rate", value: environment.todaySnapshot.respiratoryRate.map { "\(Int($0.rounded())) br/min" } ?? "Connect source", detail: "Requires validated source.", symbol: "lungs"),
                WSignalRowModel(title: "SpO2", value: spo2Metric.displayValueWithUnit, detail: spo2Metric.signalDetail, symbol: "drop", tint: spo2Metric.confidence.color),
                skinTemperatureRow
        ]
    }

    private var spo2Metric: WhoordanMetricSnapshot {
        WhoordanMetricCatalog.metrics(
            summary: environment.todaySnapshot,
            deviceState: environment.deviceState,
            baselineProfile: environment.skinTemperatureBaselineProfile,
            bodyProfile: environment.bodyProfile,
            recentSummaries: environment.recentSummaries,
            now: Date()
        ).first { $0.id == .spo2 } ?? WhoordanMetricSnapshot(
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

    private var skinTemperatureRow: WSignalRowModel {
        if environment.skinTemperatureBaselineProfile.hasActiveBaseline,
           let delta = environment.todaySnapshot.bodyTemperatureDelta {
            return WSignalRowModel(
                title: "Skin temp deviation",
                value: "\(String(format: "%+.1f", delta)) C",
                detail: environment.skinTemperatureBaselineProfile.isAutomatic
                    ? "Calculated from raw wrist/contact temperature and a private personal baseline."
                    : "Calculated from raw wrist/contact temperature and a temporary baseline.",
                symbol: "thermometer.medium",
                tint: abs(delta) >= 1.0 ? WColors.warning : WColors.success
            )
        }
        if let raw = environment.todaySnapshot.rawWristTemperatureC {
            let profile = environment.skinTemperatureBaselineProfile
            let progress = "\(min(profile.eligibleDayCount, profile.requiredDayCount))/\(profile.requiredDayCount) days"
            return WSignalRowModel(
                title: "Raw wrist/contact temp",
                value: String(format: "%.1f C", raw),
                detail: "Direct R10 raw contact temperature; not a baseline delta. Baseline \(progress).",
                symbol: "thermometer.medium",
                tint: WColors.accent
            )
        }
        let profile = environment.skinTemperatureBaselineProfile
        let progress = "\(min(profile.eligibleDayCount, profile.requiredDayCount))/\(profile.requiredDayCount) days"
        return WSignalRowModel(
            title: "Skin temp baseline",
            value: profile.isAutomatic ? "Ready" : progress,
            detail: profile.isAutomatic
                ? "Automatic baseline is kept private; only deviation is shown."
                : "Collect five sleep/night wrist-temperature days or set a temporary baseline from Today.",
            symbol: "thermometer.medium",
            tint: profile.isAutomatic ? WColors.success : WColors.warning
        )
    }
}

struct HealthMonitorView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            WScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: "Health Monitor", subtitle: "Sources and confidence")
                    WSignalList(rows: overviewRows)
                    metricGroup(title: "Heart and temperature", ids: [.heartRate, .restingHeartRate, .hrv, .rawWristTemperature, .skinTemperatureDelta])
                    metricGroup(title: "Sleep and recovery", ids: [.sleepDuration, .sleepPerformance, .recovery, .sleepStages, .restorativeSleepPercent])
                    metricGroup(title: "Calculated and limited signals", ids: [.stress, .respiratoryRate, .spo2, .vo2Max])
                    WFootnote(text: "Health Monitor labels what is direct, calculated, estimated, source-labeled, or unavailable. Blocked diagnostics do not become health metrics.")
                }
                .padding(WSpacing.l)
                .padding(.bottom, WSpacing.xxl)
            }
        }
        .navigationTitle("Health Monitor")
    }

    private func metricGroup(title: String, ids: [WhoordanMetricID]) -> some View {
        let groupMetrics = ids.compactMap { id in metrics.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: WSpacing.s) {
            Text(title)
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WSpacing.s) {
                ForEach(groupMetrics) { metric in
                    NavigationLink {
                        MetricDetailView(metric: metric)
                    } label: {
                        WMetricCard(metric: metric)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var overviewRows: [WSignalRowModel] {
        [
            WSignalRowModel(title: "Local-first", value: environment.consentState.localModeEnabled ? "On" : "Default", detail: "Health data stays local unless cloud sync is enabled.", symbol: "iphone"),
            WSignalRowModel(title: "Cloud health sync", value: environment.consentState.canUploadHealthData ? "On" : "Off", detail: "Account sign-in is separate from cloud health sync.", symbol: "icloud"),
            WSignalRowModel(title: "Device", value: environment.deviceState.connection.rawValue, detail: "Direct wearable values appear only when decoded.", symbol: "sensor.tag.radiowaves.forward")
        ]
    }

    private var metrics: [WhoordanMetricSnapshot] {
        WhoordanMetricCatalog.metrics(
            summary: environment.todaySnapshot,
            deviceState: environment.deviceState,
            baselineProfile: environment.skinTemperatureBaselineProfile,
            bodyProfile: environment.bodyProfile,
            recentSummaries: environment.recentSummaries,
            now: Date()
        )
    }
}

struct StrainDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        FeatureStatusView(
            title: "Strain",
            subtitle: "Directional activity load",
            symbol: "figure.run",
            heroTitle: environment.todaySnapshot.strain == nil ? "Strain is building" : "Directional strain available",
            heroValue: environment.todaySnapshot.strain.map { String(format: "%.1f", $0.value) },
            message: "Day strain and activity strain are directional wellness estimates. They need validated heart-rate windows, activity duration, and source-labeled movement before they should steer hard decisions.",
            actions: [],
            rows: strainRows
        )
    }

    private var strainRows: [WSignalRowModel] {
        metricRows(ids: [.dayStrain, .activityStrain, .workoutCalories, .dailyCalories])
    }

    private func metricRows(ids: [WhoordanMetricID]) -> [WSignalRowModel] {
        let snapshots = WhoordanMetricCatalog.metrics(
            summary: environment.todaySnapshot,
            deviceState: environment.deviceState,
            baselineProfile: environment.skinTemperatureBaselineProfile,
            bodyProfile: environment.bodyProfile,
            recentSummaries: environment.recentSummaries,
            now: Date()
        )
        return ids.compactMap { id in
            guard let metric = snapshots.first(where: { $0.id == id }) else { return nil }
            return WSignalRowModel(
                title: metric.title,
                value: [metric.value, metric.unit].compactMap { $0 }.joined(separator: " ").ifEmpty("Unavailable"),
                detail: metricRowDetail(metric),
                symbol: metric.symbol,
                tint: metric.confidence.color
            )
        }
    }

    private func metricRowDetail(_ metric: WhoordanMetricSnapshot) -> String {
        let accuracy = metric.accuracySummary.map { " Accuracy: \($0)." } ?? ""
        let requirement = metric.requirements.first.map { " Requires: \($0)." } ?? ""
        return "\(metric.source.label), \(metric.confidence.label).\(accuracy)\(requirement) \(metric.unavailableReason ?? metric.context)"
    }
}

struct StressView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        FeatureStatusView(
            title: "Stress",
            subtitle: "Wellness load",
            symbol: "brain.head.profile",
            heroTitle: stressMetric.value == nil ? "Stress needs more signals" : "Stress load estimate",
            heroValue: stressHeroValue,
            message: stressMetric.value == nil
                ? "Whoordan waits for enough source-labeled body signals before showing a wellness-load score."
                : "This is a wellness estimate from available signals, not a diagnosis or treatment recommendation.",
            actions: [],
            rows: stressRows
        )
    }

    private var stressRows: [WSignalRowModel] {
        [
            WSignalRowModel(
                title: "Current status",
                value: [stressMetric.value, stressMetric.unit].compactMap { $0 }.joined(separator: " ").ifEmpty("Building"),
                detail: stressMetricDetail,
                symbol: stressMetric.value == nil ? "lock" : stressMetric.symbol,
                tint: stressMetric.value == nil ? WColors.warning : stressMetric.confidence.color
            ),
            WSignalRowModel(title: "Needed inputs", value: "HRV/RHR/load", detail: "Use baseline-relative signals and rest/sleep gating before any score appears.", symbol: "waveform.path.ecg", tint: WColors.warning),
            WSignalRowModel(title: "Product guardrail", value: "Wellness only", detail: "No diagnosis, treatment, or mental-health claim.", symbol: "checkmark.seal", tint: WColors.success)
        ]
    }

    private var stressHeroValue: String? {
        let value = [stressMetric.value, stressMetric.unit].compactMap { $0 }.joined(separator: " ")
        return value.isEmpty ? nil : value
    }

    private var stressMetricDetail: String {
        let accuracy = stressMetric.accuracySummary.map { " Accuracy: \($0)." } ?? ""
        let requirement = stressMetric.requirements.first.map { " Requires: \($0)." } ?? ""
        return "\(stressMetric.confidence.label).\(accuracy)\(requirement) \(stressMetric.unavailableReason ?? stressMetric.context)"
    }

    private var stressMetric: WhoordanMetricSnapshot {
        WhoordanMetricCatalog.metrics(
            summary: environment.todaySnapshot,
            deviceState: environment.deviceState,
            baselineProfile: environment.skinTemperatureBaselineProfile,
            bodyProfile: environment.bodyProfile,
            recentSummaries: environment.recentSummaries,
            now: Date()
        )
        .first { $0.id == .stress }
        ?? WhoordanMetricSnapshot(
            id: .stress,
            title: "Stress",
            value: nil,
            unit: nil,
            source: .unavailable,
            confidence: .blocked,
            readiness: .laterBlocked,
            accuracySummary: "Blocked until validated",
            accuracyDetail: nil,
            requirements: ["Personal HRV/RHR baselines", "Two or more current baseline-relative body signals"],
            calibrationSummary: "Not enough validated input data yet.",
            lastUpdated: nil,
            unavailableReason: "Blocked until validated.",
            context: "No stress score yet.",
            symbol: "brain.head.profile"
        )
    }
}

struct TrendsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        FeatureStatusView(
            title: "Trends",
            subtitle: "Long-term signal direction",
            symbol: "chart.line.uptrend.xyaxis",
            heroTitle: heroTitle,
            heroValue: nil,
            message: "Trends need multiple source-labeled or BLE-derived days. Whoordan shows direction and confidence, not diagnosis.",
            actions: [],
            rows: trendRows
        )
    }

    private var heroTitle: String {
        trendRows.contains { $0.value != "Not enough data" }
            ? "Trend baseline is ready"
            : "Not enough data"
    }

    private var trendRows: [WSignalRowModel] {
        [
            trendRow(
                title: "Recovery",
                values: environment.recentSummaries.compactMap { $0.recovery?.value },
                notEnoughDetail: "Requires at least two daily recovery scores.",
                symbol: "arrow.clockwise"
            ),
            trendRow(
                title: "Sleep",
                values: environment.recentSummaries.compactMap(\.sleepMinutes),
                notEnoughDetail: "Requires at least two decoded sleep sessions.",
                symbol: "moon"
            ),
            trendRow(
                title: "Movement",
                values: environment.recentSummaries.compactMap { $0.movement.steps.map(Double.init) },
                notEnoughDetail: "Requires at least two step or activity days.",
                symbol: "shoeprints.fill"
            )
        ]
    }

    private func trendRow(
        title: String,
        values: [Double],
        notEnoughDetail: String,
        symbol: String
    ) -> WSignalRowModel {
        guard values.count >= 2, let latest = values.last else {
            return WSignalRowModel(
                title: title,
                value: "Not enough data",
                detail: notEnoughDetail,
                symbol: symbol
            )
        }
        let priorAverage = values.dropLast().reduce(0, +) / Double(values.count - 1)
        let delta = latest - priorAverage
        let value: String
        if abs(delta) < 0.05 {
            value = "Stable"
        } else {
            value = delta > 0 ? "Up" : "Down"
        }
        return WSignalRowModel(
            title: title,
            value: value,
            detail: "\(values.count) days in the local trend window.",
            symbol: symbol
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private struct FeatureStatusView: View {
    let title: String
    let subtitle: String
    let symbol: String
    let heroTitle: String
    let heroValue: String?
    let message: String
    let actions: [WCTAAction]
    let rows: [WSignalRowModel]

    var body: some View {
        ZStack {
            WScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: WSpacing.l) {
                    WScreenHeader(title: title, subtitle: subtitle)
                    WHeroModule(
                        eyebrow: "Status",
                        title: heroTitle,
                        value: heroValue,
                        message: message,
                        symbol: symbol,
                        confidence: heroValue == nil ? .unavailable : .medium
                    )
                    if !actions.isEmpty {
                        WCTARow(actions: actions)
                    }
                    WSignalList(rows: rows)
                    WFootnote(text: "Whoordan uses source-labeled wellness data only. Estimates are labeled and are not medical guidance.")
                }
                .padding(WSpacing.l)
                .padding(.bottom, WSpacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
