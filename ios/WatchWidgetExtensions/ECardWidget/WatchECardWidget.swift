//
//  WatchECardWidget.swift
//  WatchWidgetExtensions
//
//  表盘复杂功能「付款码」：入口型；各 accessory 族布局见 WatchAccessoryView
//

import SwiftUI
import WidgetKit

struct WatchECardEntry: TimelineEntry {
    let date: Date
}

struct WatchECardProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchECardEntry {
        WatchECardEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchECardEntry) -> Void) {
        completion(WatchECardEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchECardEntry>) -> Void) {
        completion(
            Timeline(
                entries: [WatchECardEntry(date: Date())],
                policy: .after(Date(timeIntervalSinceNow: 86_400))
            )
        )
    }
}

struct WatchECardWidget: Widget {
    let kind: String = "ECardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchECardProvider()) { entry in
            WatchECardWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetURL(WatchAccessoryKind.ecard.deepLink)
        }
        .configurationDisplayName("付款码")
        .description("打开付款码")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct WatchECardWidgetView: View {
    let entry: WatchECardEntry

    var body: some View {
        WatchAccessoryView(kind: .ecard)
    }
}

// MARK: - Previews（四种复杂功能族）

#Preview("付款码 · 圆形", as: .accessoryCircular) {
    WatchECardWidget()
} timeline: {
    WatchECardEntry(date: Date())
}

#Preview("付款码 · 矩形", as: .accessoryRectangular) {
    WatchECardWidget()
} timeline: {
    WatchECardEntry(date: Date())
}

#Preview("付款码 · 行内", as: .accessoryInline) {
    WatchECardWidget()
} timeline: {
    WatchECardEntry(date: Date())
}

#Preview("付款码 · 角位", as: .accessoryCorner) {
    WatchECardWidget()
} timeline: {
    WatchECardEntry(date: Date())
}
