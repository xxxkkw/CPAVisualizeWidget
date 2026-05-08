import SwiftUI
import WidgetKit

struct CPAUsageWidget: Widget {
    let kind: String = CPAVisualizeConfiguration.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            UsageWidgetView(entry: entry)
        }
        .configurationDisplayName("CPA Usage")
        .description("在桌面上查看今日 Token、缓存、推理和请求趋势。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
