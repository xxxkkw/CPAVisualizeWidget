import SwiftUI
import WidgetKit

private enum WidgetChartLayout {
    static let horizontalInset: CGFloat = 7
    static let verticalInset: CGFloat = 28

    static func yPosition(for yRatio: Double, height: CGFloat) -> CGFloat {
        let clampedRatio = min(max(CGFloat(yRatio), 0), 1)
        let inset = effectiveVerticalInset(for: height)
        let drawableHeight = max(height - (inset * 2), 1)
        return height - inset - (clampedRatio * drawableHeight)
    }

    static func areaBaseline(in height: CGFloat) -> CGFloat {
        let inset = effectiveVerticalInset(for: height)
        return max(height - inset, inset)
    }

    private static func effectiveVerticalInset(for height: CGFloat) -> CGFloat {
        min(verticalInset, max(height * 0.32, 10))
    }
}

struct UsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: UsageWidgetEntry

    private var snapshot: UsageSnapshot {
        entry.snapshot ?? .preview
    }

    private var primarySummary: UsageSummary {
        snapshot.today
    }

    private var tokenTrend: [Double] {
        snapshot.dailyTokens.map(\.value)
    }

    private var chartTrend: [Double] {
        smoothedChartValues(tokenTrend, maximumPointCount: family == .systemMedium ? 24 : 14)
    }

    private var isAccentedRendering: Bool {
        widgetRenderingMode == .accented
    }

    private var isVibrantRendering: Bool {
        widgetRenderingMode == .vibrant
    }

    private var contentHorizontalInset: CGFloat {
        family == .systemMedium ? 18 : 22
    }

    private var contentVerticalInset: CGFloat {
        family == .systemMedium ? 15 : 17
    }

    private var primaryTextColor: Color {
        if isAccentedRendering {
            return Color.white.opacity(0.94)
        }
        if isVibrantRendering {
            return Color.primary.opacity(0.96)
        }
        return Color.white.opacity(0.94)
    }

    private var secondaryTextColor: Color {
        if isAccentedRendering {
            return Color.white.opacity(0.68)
        }
        if isVibrantRendering {
            return Color.primary.opacity(0.58)
        }
        return Color.white.opacity(0.70)
    }

    private var chartLineColor: Color {
        if isAccentedRendering {
            return Color.white.opacity(0.82)
        }
        if isVibrantRendering {
            return Color.primary.opacity(0.64)
        }
        return Color.white.opacity(0.94)
    }

    private var chartAreaColor: Color {
        if isAccentedRendering {
            return Color.white.opacity(0.10)
        }
        if isVibrantRendering {
            return Color.primary.opacity(0.06)
        }
        return Color(red: 0.18, green: 0.48, blue: 0.86).opacity(0.22)
    }

    private var guideColor: Color {
        if isAccentedRendering {
            return Color.white.opacity(0.12)
        }
        if isVibrantRendering {
            return Color.primary.opacity(0.08)
        }
        return Color.white.opacity(0.16)
    }

    var body: some View {
        widgetContent
            .padding(.horizontal, contentHorizontalInset)
            .padding(.vertical, contentVerticalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                widgetContainerBackground
            }
            .contentShape(ContainerRelativeShape())
    }

    private var widgetContainerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.045, blue: 0.095),
                    Color(red: 0.025, green: 0.105, blue: 0.185),
                    Color(red: 0.010, green: 0.030, blue: 0.070)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(red: 0.055, green: 0.42, blue: 0.66).opacity(0.42), .clear],
                center: .leading,
                startRadius: 18,
                endRadius: 260
            )
            .scaleEffect(x: 1.25, y: 0.82, anchor: .leading)
            .offset(x: -70, y: 28)
            .blur(radius: 20)

            RadialGradient(
                colors: [Color(red: 0.11, green: 0.38, blue: 0.68).opacity(0.48), .clear],
                center: .bottomTrailing,
                startRadius: 12,
                endRadius: 250
            )
            .scaleEffect(x: 1.35, y: 0.80, anchor: .bottomTrailing)
            .offset(x: 42, y: 18)
            .blur(radius: 24)

            LinearGradient(
                colors: [
                    .clear,
                    Color(red: 0.08, green: 0.30, blue: 0.58).opacity(0.20),
                    Color(red: 0.05, green: 0.18, blue: 0.36).opacity(0.18),
                    .clear
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            .blur(radius: 14)

            LinearGradient(
                colors: [Color.white.opacity(0.08), .clear, Color.black.opacity(0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ContainerRelativeShape()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch entry.displayMode {
        case .empty:
            emptyState
        case .live, .preview:
            if family == .systemMedium {
                mediumContent
            } else {
                smallContent
            }
        }
    }

    private var mediumContent: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                totalTokensBlock(fontSize: 31, labelFontSize: 14, minimumFractionDigits: 2)
                metricsGrid(labelFontSize: 14, valueFontSize: 16, spacing: 8)
            }
            .padding(.leading, 1)
            .padding(.top, 3)
            .frame(width: 140, alignment: .leading)

            chartPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            totalTokensBlock(fontSize: 31, labelFontSize: 12.5, minimumFractionDigits: 1)

            Text("缓存 \(formattedAmount(primarySummary.cachedTokens, minimumFractionDigits: 1))   推理 \(formattedAmount(primarySummary.reasoningTokens, minimumFractionDigits: 1))")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            chartPanel
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)

            Text("暂无快照")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryTextColor)

            Text("先在宿主 App 里同步一次 Usage Keeper 数据。")
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func totalTokensBlock(fontSize: CGFloat, labelFontSize: CGFloat, minimumFractionDigits: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            iconLabel("Token总数", symbolName: "chart.bar.xaxis", fontSize: labelFontSize)

            Text(formattedAmount(primarySummary.totalTokens, minimumFractionDigits: minimumFractionDigits))
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .widgetAccentable(isAccentedRendering)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
    }

    private func metricsGrid(labelFontSize: CGFloat, valueFontSize: CGFloat, spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            metricRow(label: "缓存", symbolName: "externaldrive.fill", value: formattedAmount(primarySummary.cachedTokens, minimumFractionDigits: 2), labelFontSize: labelFontSize, valueFontSize: valueFontSize)
            metricRow(label: "推理", symbolName: "sparkles", value: formattedAmount(primarySummary.reasoningTokens, minimumFractionDigits: 2), labelFontSize: labelFontSize, valueFontSize: valueFontSize)
            if primarySummary.costAvailable {
                metricRow(label: "费用", symbolName: "dollarsign.circle.fill", value: "$\(decimalString(primarySummary.totalCost, minimumFractionDigits: 2))", labelFontSize: labelFontSize, valueFontSize: valueFontSize)
            }
        }
    }

    private func metricRow(label: String, symbolName: String, value: String, labelFontSize: CGFloat, valueFontSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            iconLabel(label, symbolName: symbolName, fontSize: labelFontSize)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func iconLabel(_ label: String, symbolName: String, fontSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: max(fontSize - 1, 10), weight: .semibold))
                .foregroundStyle(Color(red: 0.35, green: 0.61, blue: 0.88))
                .frame(width: fontSize + 4, alignment: .center)
                .widgetAccentable(isAccentedRendering)

            Text(label)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var chartPanel: some View {
        VStack(spacing: 4) {
            chartPlot
                .frame(maxHeight: .infinity)

            chartAxisLabelsRow
                .frame(height: 14)
        }
    }

    private var chartPlot: some View {
        GeometryReader { proxy in
            let plotSize = CGSize(
                width: max(proxy.size.width - (WidgetChartLayout.horizontalInset * 2), 1),
                height: max(proxy.size.height, 1)
            )
            let values = chartTrend
            let points = normalizedPoints(for: values, in: plotSize)

            ZStack(alignment: .topLeading) {
                chartGuides(in: plotSize)
                    .frame(width: plotSize.width, height: plotSize.height)

                if values.count > 1 {
                    SmoothAreaShape(points: values)
                        .fill(chartAreaColor)
                        .widgetAccentable(isAccentedRendering)
                        .frame(width: plotSize.width, height: plotSize.height)

                    SmoothLineShape(points: values)
                        .stroke(
                            chartLineColor,
                            style: StrokeStyle(lineWidth: isAccentedRendering ? 2.2 : 2.0, lineCap: .round, lineJoin: .round)
                        )
                        .widgetAccentable(isAccentedRendering)
                        .frame(width: plotSize.width, height: plotSize.height)
                } else {
                    Capsule()
                        .fill(guideColor)
                        .frame(width: plotSize.width, height: 2)
                        .position(x: plotSize.width * 0.5, y: plotSize.height * 0.5)
                }

                if let lastPoint = points.last {
                    Circle()
                        .fill(chartLineColor)
                        .widgetAccentable(isAccentedRendering)
                        .frame(width: isAccentedRendering ? 5.5 : 5, height: isAccentedRendering ? 5.5 : 5)
                        .position(x: lastPoint.x, y: lastPoint.y)
                }
            }
            .frame(width: plotSize.width, height: plotSize.height)
            .clipped()
            .padding(.horizontal, WidgetChartLayout.horizontalInset)
        }
    }

    private var chartAxisLabelsRow: some View {
        HStack {
            ForEach(Array(chartAxisLabels.enumerated()), id: \.offset) { item in
                Text(item.element)
                    .font(.system(size: 9.2, weight: .medium))
                    .foregroundStyle(secondaryTextColor.opacity(0.88))
                    .lineLimit(1)

                if item.offset < chartAxisLabels.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, WidgetChartLayout.horizontalInset)
    }

    private var chartAxisLabels: [String] {
        let labels = snapshot.dailyTokens.map(\.date)
        guard !labels.isEmpty else {
            return ["--", "--", "--"]
        }

        if labels.count <= 3 {
            return labels.map(axisLabelText)
        }

        let middleIndex = labels.count / 2
        return [labels[0], labels[middleIndex], labels[labels.count - 1]].map(axisLabelText)
    }

    private func chartGuides(in size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(1 ..< 6, id: \.self) { index in
                let xPosition = size.width * CGFloat(index) / 6

                Path { path in
                    path.move(to: CGPoint(x: xPosition, y: 0))
                    path.addLine(to: CGPoint(x: xPosition, y: size.height))
                }
                .stroke(guideColor, lineWidth: 0.8)
            }

            Path { path in
                let y = size.height * 0.5
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            .stroke(guideColor.opacity(isAccentedRendering ? 0.42 : 0.32), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    private func axisLabelText(_ rawValue: String) -> String {
        let parts = rawValue.split(whereSeparator: { $0 == "T" || $0 == " " })

        for part in parts.reversed() {
            guard part.contains(":") else {
                continue
            }

            let hourCandidate = part.split(separator: ":").first.map(String.init) ?? ""
            if let hour = Int(hourCandidate) {
                return String(format: "%02d时", hour)
            }
        }

        if let hour = Int(rawValue) {
            return String(format: "%02d时", hour)
        }

        return rawValue
    }

    private func formattedAmount(_ value: Int64, minimumFractionDigits: Int) -> String {
        let absoluteValue = Double(abs(value))
        let sign = value < 0 ? "-" : ""

        let formattedValue: String
        let suffix: String

        switch absoluteValue {
        case 1_000_000_000...:
            formattedValue = decimalString(absoluteValue / 1_000_000_000, minimumFractionDigits: minimumFractionDigits)
            suffix = "B"
        case 1_000_000...:
            formattedValue = decimalString(absoluteValue / 1_000_000, minimumFractionDigits: minimumFractionDigits)
            suffix = "M"
        case 1_000...:
            formattedValue = decimalString(absoluteValue / 1_000, minimumFractionDigits: minimumFractionDigits)
            suffix = "K"
        default:
            formattedValue = decimalString(absoluteValue, minimumFractionDigits: 0)
            suffix = ""
        }

        return sign + formattedValue + suffix
    }

    private func integerString(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func decimalString(_ value: Double, minimumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func smoothedChartValues(_ values: [Double], maximumPointCount: Int) -> [Double] {
        guard values.count > 2 else {
            return values
        }

        let sampledValues = bucketedValues(values, maximumPointCount: maximumPointCount)
        guard sampledValues.count > 2 else {
            return sampledValues
        }

        return sampledValues.enumerated().map { index, value in
            if index == 0 || index == sampledValues.count - 1 {
                return value
            }

            return (sampledValues[index - 1] + (value * 8) + sampledValues[index + 1]) / 10
        }
    }

    private func bucketedValues(_ values: [Double], maximumPointCount: Int) -> [Double] {
        guard values.count > maximumPointCount, maximumPointCount > 1 else {
            return values
        }

        let bucketCount = min(maximumPointCount, values.count)
        return (0 ..< bucketCount).map { bucketIndex in
            let start = Int((Double(bucketIndex) * Double(values.count)) / Double(bucketCount))
            let rawEnd = Int((Double(bucketIndex + 1) * Double(values.count)) / Double(bucketCount))
            let end = min(max(rawEnd, start + 1), values.count)
            let bucketValues = values[start ..< end]
            return bucketValues.reduce(0, +) / Double(bucketValues.count)
        }
    }

    private func normalizedPoints(for values: [Double], in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else {
            return []
        }

        if values.count == 1 {
            return [CGPoint(x: size.width * 0.5, y: size.height * 0.5)]
        }

        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0
        let valueRange = max(maxValue - minValue, 1)
        let stepX = size.width / CGFloat(max(values.count - 1, 1))

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let yRatio = (value - minValue) / valueRange
            let y = WidgetChartLayout.yPosition(for: yRatio, height: size.height)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct SmoothLineShape: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        let cgPoints = normalizedPoints(in: rect)
        guard cgPoints.count > 1 else {
            return Path()
        }

        return Path { path in
            path.move(to: cgPoints[0])

            if cgPoints.count == 2 {
                path.addLine(to: cgPoints[1])
                return
            }

            let tension: CGFloat = 0.22
            for index in 0 ..< (cgPoints.count - 1) {
                let p0 = index > 0 ? cgPoints[index - 1] : cgPoints[index]
                let p1 = cgPoints[index]
                let p2 = cgPoints[index + 1]
                let p3 = index + 2 < cgPoints.count ? cgPoints[index + 2] : p2
                let control1 = CGPoint(
                    x: p1.x + ((p2.x - p0.x) * tension),
                    y: p1.y + ((p2.y - p0.y) * tension)
                )
                let control2 = CGPoint(
                    x: p2.x - ((p3.x - p1.x) * tension),
                    y: p2.y - ((p3.y - p1.y) * tension)
                )

                path.addCurve(
                    to: p2,
                    control1: clampedPoint(control1, in: rect),
                    control2: clampedPoint(control2, in: rect)
                )
            }
        }
    }

    private func normalizedPoints(in rect: CGRect) -> [CGPoint] {
        guard points.count > 1 else {
            return []
        }

        let maxValue = points.max() ?? 0
        let minValue = points.min() ?? 0
        let valueRange = max(maxValue - minValue, 1)
        let stepX = rect.width / CGFloat(max(points.count - 1, 1))

        return points.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let yRatio = (value - minValue) / valueRange
            let y = WidgetChartLayout.yPosition(for: yRatio, height: rect.height)
            return CGPoint(x: x, y: y)
        }
    }

    private func clampedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }
}

private struct SmoothAreaShape: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        let line = SmoothLineShape(points: points).path(in: rect)
        let cgPoints = normalizedPoints(in: rect)
        guard let first = cgPoints.first, let last = cgPoints.last else {
            return line
        }

        let baseline = WidgetChartLayout.areaBaseline(in: rect.height)

        var filled = line
        filled.addLine(to: CGPoint(x: last.x, y: baseline))
        filled.addLine(to: CGPoint(x: first.x, y: baseline))
        filled.closeSubpath()
        return filled
    }

    private func normalizedPoints(in rect: CGRect) -> [CGPoint] {
        guard points.count > 1 else {
            return []
        }

        let maxValue = points.max() ?? 0
        let minValue = points.min() ?? 0
        let valueRange = max(maxValue - minValue, 1)
        let stepX = rect.width / CGFloat(max(points.count - 1, 1))

        return points.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let yRatio = (value - minValue) / valueRange
            let y = WidgetChartLayout.yPosition(for: yRatio, height: rect.height)
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview("System Medium", as: .systemMedium) {
    CPAUsageWidget()
} timeline: {
    UsageWidgetEntry(date: .now, snapshot: .preview, displayMode: .preview, isStale: false)
}

#Preview("System Small", as: .systemSmall) {
    CPAUsageWidget()
} timeline: {
    UsageWidgetEntry(date: .now, snapshot: .preview, displayMode: .live, isStale: false)
}

#Preview("System Empty Medium", as: .systemMedium) {
    CPAUsageWidget()
} timeline: {
    UsageWidgetEntry(date: .now, snapshot: nil, displayMode: .empty, isStale: false)
}

#Preview("System Empty Small", as: .systemSmall) {
    CPAUsageWidget()
} timeline: {
    UsageWidgetEntry(date: .now, snapshot: nil, displayMode: .empty, isStale: false)
}