import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @State private var didStartInitialRestore = false

    var body: some View {
        Group {
            switch environment.route {
            case .sessionRestore:
                RestoreSessionView()
            case .signedOut:
                AuthView()
            case .approvalLocked(let state):
                ApprovalLockedView(state: state)
            case .approved:
                MainTabView()
            }
        }
        .onAppear {
            guard !didStartInitialRestore else { return }
            didStartInitialRestore = true
            Task { await environment.restore() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            environment.handleScenePhaseChange(AppLifecyclePhase(scenePhase: newPhase))
            if newPhase == .active {
                Task {
                    environment.retryBluetoothPermissionProbe()
                    await environment.refreshApprovalInBackground()
                    environment.startApprovedServicesIfAllowed()
                    await environment.refreshNotificationPermission()
                    await environment.triggerDueAlarms()
                    await environment.checkForAppUpdate()
                }
            }
        }
        .sheet(item: Binding(
            get: { environment.availableUpdate },
            set: { newValue in
                if newValue == nil {
                    environment.dismissAvailableUpdate()
                }
            }
        )) { update in
            UpdateAvailableSheet(update: update)
                .environmentObject(environment)
        }
    }
}

private extension AppLifecyclePhase {
    init(scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            self = .active
        case .inactive:
            self = .inactive
        case .background:
            self = .background
        @unknown default:
            self = .inactive
        }
    }
}

private struct RestoreSessionView: View {
    var body: some View {
        ZStack {
            WScreenBackground()
            VStack(spacing: WSpacing.l) {
                Image("WhoordanW")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                ProgressView()
                    .tint(WColors.accent)
                    .accessibilityLabel("Restoring session")
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "circle.grid.2x2") }
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "arrow.clockwise") }
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon") }
            MovementView()
                .tabItem { Label("Activity", systemImage: "figure.walk") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .tint(WColors.accent)
        .toolbarBackground(WColors.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(colorScheme, for: .tabBar)
        .task(id: environment.hasLoadedApprovedLocalState) {
            await environment.requestStartupPermissionsIfNeeded()
        }
        .alert("Cloud health sync", isPresented: $environment.isCloudSyncConsentPromptPresented) {
            Button("Enable cloud sync") {
                environment.enableCloudHealthSyncFromPrompt()
            }
            Button("Keep local", role: .cancel) {
                environment.keepHealthDataLocalFromPrompt()
            }
        } message: {
            Text("Whoordan can back up locally stored health samples to your account. Leave this off to keep health data on this iPhone only.")
        }
    }
}

private struct UpdateAvailableSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    let update: WhoordanUpdate

    var body: some View {
        ZStack {
            WScreenBackground()
            VStack(alignment: .leading, spacing: WSpacing.l) {
                WBadge(text: "Update available", color: WColors.accent)
                Text("Whoordan \(update.version) (\(update.build))")
                    .font(WTypography.title)
                    .foregroundStyle(WColors.text)
                Text(update.releaseNotes)
                    .font(WTypography.body)
                    .foregroundStyle(WColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: WSpacing.s) {
                    WPrimaryButton(title: "Update", systemImage: "arrow.down.circle") {
                        environment.openAvailableUpdate()
                    }
                    WSecondaryButton(title: "Later", systemImage: "clock") {
                        environment.dismissAvailableUpdate()
                    }
                }
            }
            .padding(WSpacing.xl)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
