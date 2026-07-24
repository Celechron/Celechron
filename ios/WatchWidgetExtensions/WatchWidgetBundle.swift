//
//  WatchWidgetBundle.swift
//  WatchWidgetExtensions
//

import SwiftUI
import WidgetKit

@main
struct WatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchFlowWidget()
        WatchECardWidget()
    }
}
