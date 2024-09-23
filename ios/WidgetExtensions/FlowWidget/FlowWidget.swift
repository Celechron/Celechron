//
//  WidgetExtensions.swift
//  WidgetExtensions
//
//  Created by 施子捷 on 2024/5/1.
//

import WidgetKit
import SwiftUI

enum PeriodTypeDto: Int, Codable {
  case classes = 0
  case test = 1
  case user = 2
  case flow = 3
}

struct PeriodDto: Codable {
  var uid: String
  var type: PeriodTypeDto
  var name: String? = nil
  var startTime: Int64
  var endTime: Int64
  var location: String? = nil
}

struct Flow {
    let location: String?
    let name: String?
    let startTime: Date?
    let endTime: Date?
    
    init(location: String?, name: String?, startTime: Date?, endTime: Date?) {
        self.location = location
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
    }
    
    init(from dto: PeriodDto) {
        self.location = dto.location
        self.name = dto.name
        self.startTime = Date(timeIntervalSince1970: TimeInterval(dto.startTime))
        self.endTime = Date(timeIntervalSince1970: TimeInterval(dto.endTime))
    }
}

struct FlowEntry: TimelineEntry {
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

struct FlowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlowEntry {
        FlowEntry(refreshAt: Date(), toDisplay: [Flow(location: "紫金港西1-216", name: "信号与系统", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(1500))], stillToDoToday: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlowEntry) -> Void) {
        completion(FlowEntry(refreshAt: Date(), toDisplay: [Flow(location: "紫金港西1-216", name: "信号与系统", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(1500))], stillToDoToday: 0))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlowEntry>) -> Void) {
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
        
        var entries: [FlowEntry] = []
        for minuteOffset in 0 ..< 90 {
            let refreshTime = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentTime)!
            // 移除已经结束的事项
            onGoingFlows.removeAll {
                e in e.endTime! <= refreshTime
            }
            if(onGoingFlows.isEmpty && upComingFlows.isEmpty) {
                // 无事可做
                entries.append(FlowEntry(refreshAt: refreshTime, toDisplay: [], stillToDoToday: 0))
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
            entries.append(FlowEntry(refreshAt: refreshTime, toDisplay: nearestFlows, stillToDoToday: remaining))
        }
        completion(Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 3600))))
    }
}

struct FlowWidget: Widget {
    let kind: String = "FlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowWidgetProvider()) { entry in
            FlowWidgetView(entry: entry)
                .widgetBackground(Color(UIColor.tertiarySystemFill))
        }.supportedFamilies([.systemSmall])
    }
}

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}


