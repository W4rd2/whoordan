import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum WColors {
    static let background = Color.whoordanAdaptive(light: (0.965, 0.972, 0.958), dark: (0.026, 0.032, 0.031))
    static let backgroundRaised = Color.whoordanAdaptive(light: (0.945, 0.958, 0.942), dark: (0.04, 0.048, 0.046))
    static let surface = Color.whoordanAdaptive(light: (0.988, 0.991, 0.982), dark: (0.085, 0.098, 0.096))
    static let surfaceWarm = Color.whoordanAdaptive(light: (0.972, 0.958, 0.922), dark: (0.118, 0.113, 0.098))
    static let elevated = Color.whoordanAdaptive(light: (0.94, 0.961, 0.944), dark: (0.128, 0.144, 0.142))
    static let elevatedAlt = Color.whoordanAdaptive(light: (0.925, 0.944, 0.961), dark: (0.105, 0.117, 0.132))
    static let border = Color.whoordanAdaptive(light: (0.11, 0.19, 0.16), dark: (0.82, 0.87, 0.82)).opacity(0.12)
    static let strongBorder = Color.whoordanAdaptive(light: (0.11, 0.19, 0.16), dark: (0.82, 0.87, 0.82)).opacity(0.22)
    static let text = Color.whoordanAdaptive(light: (0.105, 0.142, 0.125), dark: (0.948, 0.938, 0.895))
    static let secondary = Color.whoordanAdaptive(light: (0.34, 0.39, 0.36), dark: (0.69, 0.72, 0.70))
    static let tertiary = Color.whoordanAdaptive(light: (0.56, 0.60, 0.57), dark: (0.48, 0.52, 0.51))
    static let muted = Color.whoordanAdaptive(light: (0.72, 0.76, 0.72), dark: (0.32, 0.36, 0.35))
    static let accent = Color.whoordanAdaptive(light: (0.04, 0.54, 0.42), dark: (0.40, 0.82, 0.70))
    static let cyan = Color.whoordanAdaptive(light: (0.12, 0.44, 0.60), dark: (0.46, 0.68, 0.82))
    static let lavender = Color.whoordanAdaptive(light: (0.45, 0.36, 0.75), dark: (0.64, 0.58, 0.92))
    static let rose = Color.whoordanAdaptive(light: (0.78, 0.24, 0.38), dark: (0.92, 0.43, 0.56))
    static let warning = Color.whoordanAdaptive(light: (0.73, 0.43, 0.08), dark: (0.94, 0.66, 0.28))
    static let critical = Color.whoordanAdaptive(light: (0.78, 0.18, 0.18), dark: (0.94, 0.36, 0.36))
    static let success = Color.whoordanAdaptive(light: (0.18, 0.58, 0.25), dark: (0.47, 0.78, 0.50))
}

enum WSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let minTap: CGFloat = 44
}

enum WTypography {
    static let hero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.bold)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let metric = Font.system(size: 48, weight: .bold, design: .rounded)
    static let compactMetric = Font.system(.title3, design: .rounded).weight(.bold)
}

enum WMotion {
    static func standard(_ reducedMotion: Bool) -> Animation? {
        reducedMotion ? nil : .smooth(duration: 0.24)
    }
}

enum WTheme {
    static let background = WColors.background
}

private extension Color {
    static func whoordanAdaptive(
        light: (red: Double, green: Double, blue: Double),
        dark: (red: Double, green: Double, blue: Double)
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            let rgb = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(rgb.red),
                green: CGFloat(rgb.green),
                blue: CGFloat(rgb.blue),
                alpha: 1
            )
        })
        #else
        return Color(red: dark.red, green: dark.green, blue: dark.blue)
        #endif
    }
}
