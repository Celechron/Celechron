//
//  WidgetExtensionsLiveActivity.swift
//  WidgetExtensions
//
//  Created by 施子捷 on 2024/5/1.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct WidgetExtensionsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct WidgetExtensionsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WidgetExtensionsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension WidgetExtensionsAttributes {
    fileprivate static var preview: WidgetExtensionsAttributes {
        WidgetExtensionsAttributes(name: "World")
    }
}

extension WidgetExtensionsAttributes.ContentState {
    fileprivate static var smiley: WidgetExtensionsAttributes.ContentState {
        WidgetExtensionsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: WidgetExtensionsAttributes.ContentState {
         WidgetExtensionsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: WidgetExtensionsAttributes.preview) {
   WidgetExtensionsLiveActivity()
} contentStates: {
    WidgetExtensionsAttributes.ContentState.smiley
    WidgetExtensionsAttributes.ContentState.starEyes
}
