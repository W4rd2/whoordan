import SwiftUI

enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "whoordan.themePreference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@main
struct WhoordanApp: App {
    @StateObject private var environment = AppEnvironment.live()
    @AppStorage(AppThemePreference.storageKey) private var themePreference = AppThemePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(environment)
                .preferredColorScheme(resolvedThemePreference.preferredColorScheme)
        }
    }

    private var resolvedThemePreference: AppThemePreference {
        AppThemePreference(rawValue: themePreference) ?? .system
    }
}
