import SwiftUI

struct WScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                WColors.backgroundRaised,
                WColors.background,
                Color(red: 0.018, green: 0.022, blue: 0.023)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct WPressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

struct WCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var background: Color

    init(
        padding: CGFloat = WSpacing.l,
        background: Color = WColors.surface.opacity(0.94),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.background = background
    }

    var body: some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WColors.border.opacity(0.78), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    }
}

struct WPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(WTypography.body.weight(.semibold))
                .foregroundStyle(Color(red: 0.02, green: 0.035, blue: 0.032))
                .frame(maxWidth: .infinity, minHeight: WSpacing.minTap)
                .padding(.horizontal, WSpacing.m)
                .background(WColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(WPressedScaleButtonStyle())
    }
}

struct WSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(WTypography.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(maxWidth: .infinity, minHeight: WSpacing.minTap)
                .padding(.horizontal, WSpacing.m)
        }
        .buttonStyle(WPressedScaleButtonStyle())
        .foregroundStyle(WColors.text)
        .background(WColors.elevatedAlt)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WColors.strongBorder, lineWidth: 0.6)
        )
    }
}

struct WBadge: View {
    let text: String
    var color: Color = WColors.accent

    var body: some View {
        Text(text)
            .font(WTypography.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, WSpacing.m)
            .padding(.vertical, WSpacing.xs)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 0.6))
            .accessibilityLabel(text)
    }
}

struct WScreenHeader: View {
    let title: String
    var date: Date?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WSpacing.xs) {
            if let date {
                Text(date, style: .date)
                    .font(WTypography.caption.weight(.medium))
                    .foregroundStyle(WColors.secondary)
            } else if let subtitle {
                Text(subtitle)
                    .font(WTypography.caption.weight(.medium))
                    .foregroundStyle(WColors.secondary)
            }
            Text(title)
                .font(WTypography.hero)
                .foregroundStyle(WColors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct WStatusStrip: View {
    let items: [StatusItem]

    struct StatusItem: Identifiable {
        let title: String
        let value: String
        let symbol: String
        var tint: Color = WColors.secondary

        var id: String { title }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WSpacing.s) {
            ForEach(items) { item in
                HStack(spacing: WSpacing.xs) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(WColors.tertiary)
                        Text(item.value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WColors.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .foregroundStyle(item.tint)
                .padding(.horizontal, WSpacing.s)
                .padding(.vertical, WSpacing.s)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [WColors.elevated.opacity(0.92), WColors.elevatedAlt.opacity(0.76)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(item.tint.opacity(0.18), lineWidth: 0.6)
                )
            }
        }
    }
}

struct WSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WSpacing.xs) {
            Text(title)
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            if let subtitle {
                Text(subtitle)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WHeroModule: View {
    let eyebrow: String
    let title: String
    let value: String?
    let message: String
    let symbol: String
    var confidence: ConfidenceLevel = .unavailable

    var body: some View {
        WCard(padding: WSpacing.xl, background: WColors.surfaceWarm.opacity(0.96)) {
            VStack(alignment: .leading, spacing: WSpacing.l) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: WSpacing.xs) {
                        Text(eyebrow.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WColors.secondary)
                        Text(title)
                            .font(WTypography.title)
                            .foregroundStyle(WColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: WSpacing.m)
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(confidence.color)
                        .frame(width: 48, height: 48)
                        .background(confidence.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let value {
                    HStack(alignment: .bottom, spacing: WSpacing.m) {
                        Text(value)
                            .font(WTypography.metric.monospacedDigit())
                            .foregroundStyle(WColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        WSignalBars(tint: confidence.color)
                            .frame(width: 64, height: 28)
                            .padding(.bottom, 8)
                    }
                }

                Text(message)
                    .font(WTypography.body)
                    .foregroundStyle(WColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                WBadge(text: confidence.label, color: confidence.color)
            }
        }
    }
}

struct WCTAButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: WSpacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(WColors.accent)
                    .frame(width: 28, height: 28)
                    .background(WColors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(WTypography.caption.weight(.semibold))
                        .foregroundStyle(WColors.text)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(WColors.tertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: WSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WColors.tertiary)
            }
            .padding(WSpacing.m)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(WColors.elevatedAlt.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WColors.border, lineWidth: 0.6)
            )
        }
        .buttonStyle(WPressedScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

struct WCTARow: View {
    let actions: [WCTAAction]

    var body: some View {
        VStack(spacing: WSpacing.s) {
            ForEach(actions) { action in
                WCTAButton(
                    title: action.title,
                    subtitle: action.subtitle,
                    systemImage: action.symbol,
                    action: action.action
                )
            }
        }
    }
}

struct WCTAAction: Identifiable {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var id: String { title }
}

struct WMetricTile: View {
    let title: String
    let value: String
    let detail: String
    var symbol: String = "waveform.path.ecg"

    var body: some View {
        WCard(padding: WSpacing.m, background: WColors.surface.opacity(0.92)) {
            VStack(alignment: .leading, spacing: WSpacing.s) {
                Label(title, systemImage: symbol)
                    .font(WTypography.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(WColors.secondary)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(WColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.tertiary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WMetricCard: View {
    let metric: WhoordanMetricSnapshot

    var body: some View {
        WCard(padding: WSpacing.l, background: WColors.surface.opacity(0.88)) {
            HStack(alignment: .top, spacing: WSpacing.m) {
                Image(systemName: metric.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(metric.confidence.color)
                    .frame(width: 36, height: 36)
                    .background(metric.confidence.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: WSpacing.s) {
                    HStack(alignment: .firstTextBaseline, spacing: WSpacing.s) {
                        Text(metric.title)
                            .font(WTypography.body.weight(.semibold))
                            .foregroundStyle(WColors.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: WSpacing.s)

                        Text(metricStatusText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(metric.readiness.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, WSpacing.s)
                            .padding(.vertical, WSpacing.xs)
                            .background(metric.readiness.color.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    HStack(alignment: .firstTextBaseline, spacing: WSpacing.xs) {
                        Text(metricDisplayValue)
                            .font(.system(.headline, design: .rounded).weight(.semibold).monospacedDigit())
                            .foregroundStyle(metric.value == nil ? WColors.secondary : WColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        if let unit = metric.unit, metric.value != nil {
                            Text(unit)
                                .font(WTypography.caption.weight(.semibold))
                                .foregroundStyle(WColors.tertiary)
                                .lineLimit(1)
                        }
                    }

                    VStack(alignment: .leading, spacing: WSpacing.xs) {
                        Text(metricSecondaryLine)
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.tertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let requirement = metric.requirements.first {
                            Text(requirement)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(WColors.tertiary.opacity(0.86))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }

                    WReadinessTrack(color: metric.confidence.color, readiness: metric.readiness)
                        .frame(height: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.accessibilitySummary)
    }

    private var metricDisplayValue: String {
        if let value = metric.value {
            return value
        }
        switch metric.confidence {
        case .blocked:
            return "Needs source"
        case .unavailable:
            return "Waiting"
        default:
            return "Not ready"
        }
    }

    private var metricSecondaryLine: String {
        let evidence = "\(metric.source.label) - \(metric.confidence.label)"
        if let accuracy = metric.accuracySummary {
            return "\(evidence) - \(accuracy)"
        }
        if let reason = metric.unavailableReason {
            return "\(evidence) - \(reason)"
        }
        return evidence
    }

    private var metricStatusText: String {
        switch metric.readiness {
        case .showNow:
            return "Ready"
        case .betaEstimated:
            return "Beta"
        case .laterBlocked:
            return "Later"
        }
    }
}

struct WSignalBars: View {
    var tint: Color = WColors.accent

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array([0.32, 0.62, 0.44, 0.82, 0.54].enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint.opacity(0.34 + value * 0.42))
                    .frame(width: 7, height: 28 * value)
            }
        }
        .accessibilityHidden(true)
    }
}

struct WReadinessTrack: View {
    let color: Color
    let readiness: WhoordanMetricReadiness

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= activeIndex ? color : WColors.muted)
                    .opacity(index <= activeIndex ? 0.9 : 0.42)
            }
        }
        .accessibilityHidden(true)
    }

    private var activeIndex: Int {
        switch readiness {
        case .showNow: return 2
        case .betaEstimated: return 1
        case .laterBlocked: return 0
        }
    }
}

struct WSignalBoardCard: View {
    let title: String
    let value: String
    let context: String
    let symbol: String
    let chips: [String]
    let confidence: ConfidenceLevel

    var body: some View {
        WCard(padding: WSpacing.l, background: WColors.surface.opacity(0.94)) {
            VStack(alignment: .leading, spacing: WSpacing.m) {
                HStack(alignment: .center, spacing: WSpacing.m) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(confidence.color)
                        .frame(width: 38, height: 38)
                        .background(confidence.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: WSpacing.xs) {
                        Text(title)
                            .font(WTypography.caption.weight(.semibold))
                            .foregroundStyle(WColors.secondary)
                        Text(value)
                            .font(WTypography.title.monospacedDigit())
                            .foregroundStyle(value == "Building" ? WColors.secondary : WColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: WSpacing.s)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WColors.tertiary)
                }

                Text(context)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: WSpacing.xs) {
                    ForEach(chips.prefix(3), id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WColors.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, WSpacing.s)
                            .padding(.vertical, WSpacing.xs)
                            .background(WColors.elevated.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(confidence.label)")
    }
}

struct WCompactMetricTile: View {
    let title: String
    let value: String
    let caption: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: WSpacing.s) {
            HStack(spacing: WSpacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(WColors.secondary)
                Text(title)
                    .font(WTypography.caption.weight(.semibold))
                    .foregroundStyle(WColors.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(WColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(WColors.tertiary)
                .lineLimit(2)
        }
        .padding(WSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [WColors.surface.opacity(0.92), WColors.elevatedAlt.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WColors.border, lineWidth: 0.6)
        )
    }
}

struct WSignalRow: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    var tint: Color = WColors.secondary

    var body: some View {
        HStack(alignment: .center, spacing: WSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WTypography.body.weight(.medium))
                    .foregroundStyle(WColors.text)
                Text(detail)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: WSpacing.s)
            Text(value)
                .font(WTypography.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(WColors.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, WSpacing.s)
    }
}

struct WSignalList: View {
    let rows: [WSignalRowModel]

    var body: some View {
        WCard(padding: WSpacing.l, background: WColors.surface.opacity(0.82)) {
            VStack(spacing: WSpacing.s) {
                ForEach(rows) { row in
                    WSignalRow(
                        title: row.title,
                        value: row.value,
                        detail: row.detail,
                        symbol: row.symbol,
                        tint: row.tint
                    )
                    if row.id != rows.last?.id {
                        Divider().overlay(WColors.border.opacity(0.5))
                    }
                }
            }
        }
    }
}

struct WSignalRowModel: Identifiable, Equatable {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    var tint: Color = WColors.secondary

    var id: String { title }

    static func == (lhs: WSignalRowModel, rhs: WSignalRowModel) -> Bool {
        lhs.id == rhs.id
    }
}

struct WFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(WColors.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, WSpacing.xs)
    }
}

struct WScoreRing: View {
    let score: Double?
    let label: String
    let confidence: ConfidenceLevel

    var body: some View {
        ZStack {
            Circle()
                .stroke(WColors.border, lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat((score ?? 0) / 100))
                .stroke(WColors.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: WSpacing.xs) {
                Text(score.map { "\(Int($0.rounded()))" } ?? "Build")
                    .font((score == nil ? WTypography.title : WTypography.metric).monospacedDigit())
                    .foregroundStyle(WColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(label)
                    .font(WTypography.caption.weight(.semibold))
                    .foregroundStyle(WColors.secondary)
                WBadge(text: confidence.label, color: confidence.color)
            }
        }
        .frame(width: 196, height: 196)
        .accessibilityLabel("\(label), \(score.map { "\(Int($0.rounded()))" } ?? "baseline building"), \(confidence.label)")
    }
}

struct WMetricDetailHero: View {
    let metric: WhoordanMetricSnapshot
    let timeline: MetricDetailTimeline?
    let isLoading: Bool

    var body: some View {
        WCard(padding: WSpacing.xl, background: WColors.surfaceWarm.opacity(0.98)) {
            VStack(alignment: .leading, spacing: WSpacing.l) {
                HStack(alignment: .top, spacing: WSpacing.m) {
                    VStack(alignment: .leading, spacing: WSpacing.s) {
                        Text(metric.readiness.label.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(metric.readiness.color)
                        HStack(alignment: .firstTextBaseline, spacing: WSpacing.s) {
                            Text(metric.value ?? "Waiting for data")
                                .font((metric.value == nil ? WTypography.title : WTypography.metric).monospacedDigit())
                                .foregroundStyle(metric.value == nil ? WColors.secondary : WColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            if let unit = metric.unit, metric.value != nil {
                                Text(unit)
                                    .font(WTypography.headline)
                                    .foregroundStyle(WColors.secondary)
                            }
                        }
                    }
                    Spacer(minLength: WSpacing.m)
                    Image(systemName: metric.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(metric.confidence.color)
                        .frame(width: 52, height: 52)
                        .background(metric.confidence.color.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(spacing: WSpacing.s) {
                    WBadge(text: metric.confidence.label, color: metric.confidence.color)
                    WBadge(text: trendLabel, color: trendColor)
                }

                Text(metric.context)
                    .font(WTypography.body)
                    .foregroundStyle(WColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trendLabel: String {
        if isLoading { return "Loading trend" }
        guard let points = timeline?.points, points.count >= 2,
              let first = points.first,
              let last = points.last else {
            return "Not enough data"
        }
        let delta = last.value - first.value
        if abs(delta) < 0.05 { return "Stable trend" }
        let prefix = delta > 0 ? "+" : ""
        return "\(prefix)\(Self.deltaFormatter.string(from: NSNumber(value: delta)) ?? "0") trend"
    }

    private var trendColor: Color {
        guard let points = timeline?.points, points.count >= 2,
              let first = points.first,
              let last = points.last else {
            return WColors.tertiary
        }
        let delta = last.value - first.value
        if abs(delta) < 0.05 { return WColors.secondary }
        return delta > 0 ? WColors.cyan : WColors.warning
    }

    private static let deltaFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

struct WMetricMissingHero: View {
    let title: String
    let message: String
    let systemImage: String
    var status: String = "Waiting for data"
    var tint: Color = WColors.warning

    var body: some View {
        WCard(padding: WSpacing.xl, background: WColors.surfaceWarm.opacity(0.98)) {
            VStack(alignment: .leading, spacing: WSpacing.l) {
                HStack(alignment: .top, spacing: WSpacing.m) {
                    VStack(alignment: .leading, spacing: WSpacing.s) {
                        Text(status.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tint)
                        Text(title)
                            .font(WTypography.title)
                            .foregroundStyle(WColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: WSpacing.m)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                        .frame(width: 52, height: 52)
                        .background(tint.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text(message)
                    .font(WTypography.body)
                    .foregroundStyle(WColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                WBadge(text: "No estimate shown", color: tint)
            }
        }
    }
}

struct WMissingMetricGuidanceCard: View {
    let title: String
    let message: String
    let steps: [String]
    var tint: Color = WColors.warning

    var body: some View {
        WCard(padding: WSpacing.l, background: WColors.surface.opacity(0.9)) {
            VStack(alignment: .leading, spacing: WSpacing.m) {
                WSectionHeader(title: title, subtitle: message)
                VStack(alignment: .leading, spacing: WSpacing.s) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: WSpacing.s) {
                            Image(systemName: "\(index + 1).circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(tint)
                                .frame(width: 22)
                            Text(step)
                                .font(WTypography.body)
                                .foregroundStyle(WColors.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

struct WTrendChartCard: View {
    let title: String
    let subtitle: String
    let timeline: MetricDetailTimeline?
    let isLoading: Bool
    var tint: Color = WColors.accent

    var body: some View {
        WCard(padding: WSpacing.l, background: WColors.surface.opacity(0.9)) {
            VStack(alignment: .leading, spacing: WSpacing.m) {
                HStack(alignment: .top) {
                    WSectionHeader(title: title, subtitle: subtitle)
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(tint)
                            .accessibilityLabel("Loading trend")
                    }
                    if timeline?.wasLimited == true {
                        WBadge(text: "Sampled", color: WColors.cyan)
                    }
                }

                if isLoading {
                    VStack(alignment: .leading, spacing: WSpacing.s) {
                        WChartSkeleton()
                            .frame(height: 176)
                        Text("Loading local trend samples")
                            .font(WTypography.caption.weight(.medium))
                            .foregroundStyle(WColors.secondary)
                    }
                    .frame(minHeight: 210, alignment: .topLeading)
                } else if let points = timeline?.points, points.count >= 2 {
                    WTrendLineChart(points: points, tint: tint)
                        .frame(height: 210)
                    HStack(spacing: WSpacing.m) {
                        WLegendItem(title: "Local series", color: tint)
                        WLegendItem(title: "Baseline band", color: WColors.muted)
                    }
                } else {
                    WEmptyState(
                        title: "Not enough data",
                        message: "This trend needs at least two stored samples.",
                        systemImage: "chart.xyaxis.line"
                    )
                    .frame(minHeight: 210)
                }
            }
        }
    }
}

struct WTrendLineChart: View {
    let points: [MetricDetailTimelinePoint]
    var tint: Color = WColors.accent

    var body: some View {
        GeometryReader { proxy in
            let values = points.map(\.value)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let spread = max(maxValue - minValue, 1)
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(WColors.border.opacity(0.7))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                    Rectangle()
                        .fill(WColors.border.opacity(0.7))
                        .frame(height: 1)
                }
                .padding(.vertical, WSpacing.s)

                Path { path in
                    for index in points.indices {
                        let x = xPosition(index: index, count: points.count, width: width)
                        let y = yPosition(
                            value: points[index].value,
                            minValue: minValue,
                            spread: spread,
                            height: height
                        )
                        if index == points.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: tint.opacity(0.24), radius: 8, x: 0, y: 4)

                if let last = points.last, let lastIndex = points.indices.last {
                    Circle()
                        .fill(WColors.text)
                        .frame(width: 8, height: 8)
                        .position(
                            x: xPosition(index: lastIndex, count: points.count, width: width),
                            y: yPosition(value: last.value, minValue: minValue, spread: spread, height: height)
                        )
                    Text(last.label)
                        .font(WTypography.caption.weight(.semibold))
                        .foregroundStyle(WColors.text)
                        .padding(.horizontal, WSpacing.s)
                        .padding(.vertical, WSpacing.xs)
                        .background(WColors.background.opacity(0.84))
                        .clipShape(Capsule())
                        .position(
                            x: min(max(xPosition(index: lastIndex, count: points.count, width: width) - 24, 42), width - 44),
                            y: max(yPosition(value: last.value, minValue: minValue, spread: spread, height: height) - 24, 18)
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Metric trend chart with \(points.count) local points")
    }

    private func xPosition(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(count - 1) * width
    }

    private func yPosition(value: Double, minValue: Double, spread: Double, height: CGFloat) -> CGFloat {
        let normalized = (value - minValue) / spread
        return height - (CGFloat(normalized) * (height - 28)) - 14
    }
}

struct WChartSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WSpacing.m) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(WColors.elevated.opacity(index == 1 ? 0.8 : 0.45))
                    .frame(height: index == 1 ? 64 : 22)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading chart")
    }
}

struct WLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: WSpacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 8)
            Text(title)
                .font(WTypography.caption.weight(.medium))
                .foregroundStyle(WColors.secondary)
        }
    }
}

struct WInsightCallout: View {
    let title: String
    let message: String
    var tint: Color = WColors.accent

    var body: some View {
        HStack(alignment: .top, spacing: WSpacing.m) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: WSpacing.xs) {
                Text(title)
                    .font(WTypography.body.weight(.semibold))
                    .foregroundStyle(WColors.text)
                Text(message)
                    .font(WTypography.caption)
                    .foregroundStyle(WColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WSpacing.l)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.6)
        )
    }
}

struct WEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: WSpacing.l) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(WColors.secondary)
            Text(title)
                .font(WTypography.headline)
                .foregroundStyle(WColors.text)
            Text(message)
                .font(WTypography.body)
                .foregroundStyle(WColors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(WSpacing.xl)
    }
}

struct WLockedState: View {
    let title: String
    let message: String
    let status: String
    let refresh: () -> Void
    let signOut: () -> Void
    var secondaryButtonTitle = "Sign Out"

    var body: some View {
        ZStack {
            WScreenBackground()
            VStack(spacing: WSpacing.xl) {
                Image("WhoordanW")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                WBadge(text: status.uppercased(), color: WColors.warning)
                VStack(spacing: WSpacing.m) {
                    Text(title)
                        .font(WTypography.title)
                        .foregroundStyle(WColors.text)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(WTypography.body)
                        .foregroundStyle(WColors.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: WSpacing.m) {
                    WPrimaryButton(title: "Refresh Status", systemImage: "arrow.clockwise", action: refresh)
                    Button(secondaryButtonTitle, role: .destructive, action: signOut)
                        .buttonStyle(.borderless)
                        .foregroundStyle(WColors.secondary)
                }
            }
            .padding(WSpacing.xl)
        }
    }
}

extension ConfidenceLevel {
    var color: Color {
        switch self {
        case .high: return WColors.success
        case .medium: return WColors.accent
        case .directional: return WColors.warning
        case .low: return WColors.warning
        case .blocked: return WColors.tertiary
        case .unavailable: return WColors.tertiary
        }
    }
}

extension WhoordanMetricReadiness {
    var color: Color {
        switch self {
        case .showNow: return WColors.success
        case .betaEstimated: return WColors.warning
        case .laterBlocked: return WColors.tertiary
        }
    }
}
