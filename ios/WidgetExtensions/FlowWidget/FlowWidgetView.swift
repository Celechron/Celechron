//
//  FlowWidgetView.swift
//  WidgetExtensions
//
//  Created by 施子捷 on 2024/5/13.
//

import WidgetKit
import SwiftUI

struct FlowWidgetView : View {
    var entry: FlowWidgetProvider.Entry

    @ViewBuilder
    var body: some View {
        if(entry.flows.isEmpty) {
            Text("今日无事可做")
                .font(.subheadline).bold()
        } else if(entry.flows.count == 1) {
            SingleFlowView(entry: entry)
        } else if(entry.flows.count == 2) {
            MultiFlowView(entry: entry)
        } else {
            Text("事情太多了")
                .font(.subheadline).bold()
        }
    }
}

struct SingleFlowView: View {
    let entry: FlowWidgetProvider.Entry
    
    var body: some View {
        let flow = entry.flows.first!
        let hasBegun = entry.date.compare(flow.startTime!) != ComparisonResult.orderedAscending;
        let referenceTime = hasBegun ? flow.endTime! : flow.startTime!;
        let timeDifference = Int(ceil(entry.date.distance(to: referenceTime) / 60));
        let progress = hasBegun ? entry.date.distance(to: flow.startTime!) / flow.endTime!.distance(to: flow.startTime!) : 1
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "location").font(.caption2.bold())
                Spacer().frame(width: 5)
                Text(flow.location ?? "无地点信息")
                    .font(.caption2.bold()).lineLimit(1)
            }
            
            HStack {
                Circle().frame(height: 12)
                    .font(.subheadline).foregroundColor(.blue)
                Spacer().frame(width: 6)
                Text(flow.name ?? "未命名日程")
                    .font(.subheadline.bold())
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%02d:%02d", arguments: [timeDifference / 60, timeDifference % 60]))
                    .font(.title.bold())
                Spacer().frame(width: 2)
                Text(hasBegun ? "后结束" : "后开始")
                    .font(.caption2)
            }
            Spacer().frame(height: 0)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundColor(.gray.opacity(0.5)).frame(height: 12)
                GeometryReader { metrics in
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: metrics.size.width * (progress < 0.08 ? 0.08 : progress))
                        .frame(height: 12).foregroundColor(.blue)
                }
            }
            
            HStack {
                Text(entry.remaining == 0 ? "今日已无更多事务" : String(format: "今日还有%d项事务", arguments: [entry.remaining]))
                    .font(.caption2).foregroundColor(.secondary).lineLimit(2)
            }
        }
    }
}

struct MultiFlowView: View {
    let entry: FlowWidgetProvider.Entry
    
    var body: some View {
        VStack {
            FlowCard(date: entry.date, flow: entry.flows[0]).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
            FlowCard(date: entry.date, flow: entry.flows[1]).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
        }
    }
    
    struct FlowCard: View {
        let date: Date
        let flow: Flow
        
        var body: some View {
            let hasBegun = date.compare(flow.startTime!) != ComparisonResult.orderedAscending;
            let referenceTime = hasBegun ? flow.endTime! : flow.startTime!;
            let timeDifference = Int(ceil(date.distance(to: referenceTime) / 60));
            let progress = hasBegun ? date.distance(to: flow.startTime!) / flow.endTime!.distance(to: flow.startTime!) : 1
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "location").font(.caption2.bold())
                    Spacer().frame(width: 4)
                    Text(flow.location ?? "无地点信息")
                        .font(.caption2.bold()).lineLimit(1)
                }
                
                HStack {
                    Image(systemName: "circle.fill").font(.caption2.bold())
                        .foregroundColor(.blue)
                    Spacer().frame(width: 4)
                    Text(flow.name ?? "未命名日程")
                        .font(.caption).bold()
                }
                
                Spacer().frame(height: 2)
                
                HStack {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .frame(height: 6).foregroundColor(.gray.opacity(0.5))
                        GeometryReader { metrics in
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: metrics.size.width * (progress < 0.08 ? 0.08 : progress))
                                .frame(height: 6).foregroundColor(.blue)
                        }
                    }.frame(maxHeight: 0)
                    Text(String(format: "%02d:%02d", arguments: [timeDifference / 60, timeDifference % 60]))
                        .font(.caption2.bold())
                    Spacer().frame(width: 1)
                    Text(hasBegun ? "终" : "始")
                        .font(.caption2.bold())
                }
                
            }
            .frame(maxHeight: .infinity).frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 6, leading: 6, bottom: 4, trailing: 6))
        }
    }
}

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    FlowWidget()
} timeline: {
    FlowEntry(refreshAt: Date(), toDisplay: [Flow(location: "紫金港西1-216", name: "信号与系统", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(1500))], stillToDoToday: 0)
}
