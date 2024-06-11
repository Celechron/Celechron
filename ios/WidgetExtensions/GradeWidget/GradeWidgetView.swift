//
//  GradeWidgetView.swift
//  WidgetExtensions
//
//  Created by 施子捷 on 2024/6/4.
//

import WidgetKit
import SwiftUI

struct GradeWidgetView : View {
    var entry: GradeWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            HStack {
                Image(systemName: "graduationcap.fill").font(.subheadline.bold())
                Spacer().frame(width: 4)
                Text("已出分课程").font(.headline.bold())
                Spacer()
            }
            
            Spacer().frame(height: 16)
            
            HStack(alignment: .firstTextBaseline) {
                Text("9").font(.largeTitle.bold()).foregroundColor(.red)
                Spacer().frame(width: 4)
                Text("/ 15").font(.title2.bold())
            }
            
            Spacer().frame(height: 0)
            
            HStack(alignment: .bottom) {

                Text("更新时间: 16:18")
                    .font(.caption2).foregroundColor(.secondary).padding(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                Spacer()
                Image(systemName: "arrow.counterclockwise.circle.fill").font(.largeTitle).foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
            }
        }
    }
}


@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    GradeWidget()
} timeline: {
    GradeEntry(refreshAt: Date(), toDisplay: [Flow(location: "紫金港西1-216", name: "信号与系统", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(1500))], stillToDoToday: 0)
}

