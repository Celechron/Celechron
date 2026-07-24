//
//  WatchFlowWidget.swift
//  WatchWidgetExtensions
//
//  表盘复杂功能「日程」：入口型；各 accessory 族布局见 WatchAccessoryView
//

import SwiftUI
import WidgetKit

struct WatchFlowEntry: TimelineEntry {
    let date: Date
}

struct WatchFlowProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchFlowEntry {
        WatchFlowEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchFlowEntry) -> Void) {
        completion(WatchFlowEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchFlowEntry>) -> Void) {
        // 静态入口型复杂功能，无需频繁刷新
        completion(
            Timeline(
                entries: [WatchFlowEntry(date: Date())],
                policy: .after(Date(timeIntervalSinceNow: 86_400))
            )
        )
    }
}

struct WatchFlowWidget: Widget {
    let kind: String = "FlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchFlowProvider()) { entry in
            WatchFlowWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetURL(WatchAccessoryKind.flow.deepLink)
        }
        .configurationDisplayName("日程")
        .description("打开日程")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct WatchFlowWidgetView: View {
    let entry: WatchFlowEntry

    var body: some View {
        WatchAccessoryView(kind: .flow)
    }
}

// MARK: - Previews（四种复杂功能族）

#Preview("日程 · 圆形", as: .accessoryCircular) {
    WatchFlowWidget()
} timeline: {
    WatchFlowEntry(date: Date())
}

#Preview("日程 · 矩形", as: .accessoryRectangular) {
    WatchFlowWidget()
} timeline: {
    WatchFlowEntry(date: Date())
}

#Preview("日程 · 行内", as: .accessoryInline) {
    WatchFlowWidget()
} timeline: {
    WatchFlowEntry(date: Date())
}

#Preview("日程 · 角位", as: .accessoryCorner) {
    WatchFlowWidget()
} timeline: {
    WatchFlowEntry(date: Date())
}
