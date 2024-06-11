//
//  GradeWidget.swift
//  WidgetExtensions
//
//  Created by 施子捷 on 2024/6/4.
//

import WidgetKit
import SwiftUI

struct GradeEntry: TimelineEntry {
    let date: Date
    let flows: [Flow]
    let remaining: Int
    
    init(refreshAt date: Date, toDisplay flows: [Flow], stillToDoToday remaining: Int) {
        self.date = date
        self.flows = flows
        self.remaining = remaining
    }
    
    init(refreshAt date: Date, location: String?, name: String?, startTime: Date?, endTime: Date?) {
        self.date = date
        self.flows = [Flow(location: location, name: name, startTime: startTime, endTime: endTime)]
        self.remaining = 0
    }
}

struct GradeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GradeEntry {
        GradeEntry(refreshAt: Date(), location: nil, name: nil, startTime: Date(timeIntervalSinceNow: 3600), endTime: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GradeEntry) -> Void) {
        completion(GradeEntry(refreshAt: Date(), location: nil, name: nil, startTime: Date(timeIntervalSinceNow: 3600), endTime: nil))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // 读取UserDefaults中的flowList项
        #if DEBUG
        let userDefaults = UserDefaults(suiteName: "group.top.celechron.celechron.debug")
        #else
        let userDefaults = UserDefaults(suiteName: "group.top.celechron.celechron")
        #endif
        let data = userDefaults?.data(forKey: "flowList") ?? Data()
        let flowList = try? JSONDecoder().decode([PeriodDto?].self, from: data)
        
        let currentTime = Date().addingTimeInterval(-TimeInterval((Int(Date().timeIntervalSince1970) % 60))) // 当前时刻
        var onGoingFlows: [Flow] = []  // 正在进行的事项
        var upComingFlows: [Flow] = [] // 即将发生的事项
        flowList?.forEach({ e in
            if(e == nil) { return }
            let timeToStart = TimeInterval(e!.startTime) - currentTime.timeIntervalSince1970
            let timeToEnd = TimeInterval(e!.endTime) - currentTime.timeIntervalSince1970
            if(timeToEnd > 0) {
                if(timeToStart <= 0) { onGoingFlows.append(Flow(from: e!)) }
                else if(timeToStart <= 172800) { upComingFlows.append(Flow(from: e!)) }
            }
        })
        upComingFlows.sort { a, b in a.startTime! < b.startTime! }
        
        var entries: [GradeEntry] = []
        for minuteOffset in 0 ..< 1440 {
            let refreshTime = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentTime)!
            // 移除已经结束的事项
            onGoingFlows.removeAll {
                e in e.endTime! <= refreshTime
            }
            if(onGoingFlows.isEmpty && upComingFlows.isEmpty) {
                // 无事可做
                entries.append(GradeEntry(refreshAt: Date(), toDisplay: [], stillToDoToday: 0))
                break
            }
            
            let refreshTimePlus30Min = refreshTime.addingTimeInterval(1800)
            var nearestFlows: [Flow] = [];
            
            nearestFlows.append(contentsOf: onGoingFlows)
            var justHappenedIndex: Int = -1
            if(
                (onGoingFlows.isEmpty &&
                 (Calendar.current.isDate(upComingFlows.first!.startTime!, inSameDayAs: refreshTime)
                  || upComingFlows.first!.startTime! <= refreshTime.addingTimeInterval(36000))
                )
                || (!upComingFlows.isEmpty && upComingFlows.first!.startTime! <= refreshTimePlus30Min)) {
                nearestFlows.append(upComingFlows.first!)
                justHappenedIndex = 0
            }
            for i in stride(from: 1, to: upComingFlows.count, by: 1) {
                if(upComingFlows[i].startTime! <= refreshTimePlus30Min) {
                    nearestFlows.append(upComingFlows[i])
                    justHappenedIndex = i
                } else {
                    break
                }
            }
            if(justHappenedIndex >= 0) {
                onGoingFlows.append(contentsOf: upComingFlows[0...justHappenedIndex])
                upComingFlows.removeSubrange(0...justHappenedIndex)
            }
            
            let remaining = upComingFlows.firstIndex(where: { e in !Calendar.current.isDate(e.startTime!, inSameDayAs: refreshTime)}) ?? upComingFlows.count
            entries.append(GradeEntry(refreshAt: refreshTime, toDisplay: nearestFlows, stillToDoToday: remaining))
        }
        completion(Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 86400))))
    }
}

struct GradeWidget: Widget {
    let kind: String = "GradeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GradeWidgetProvider()) { entry in
            GradeWidgetView(entry: entry)
                .widgetBackground(Color(UIColor.tertiarySystemFill))
        }.supportedFamilies([.systemSmall])
    }
}
