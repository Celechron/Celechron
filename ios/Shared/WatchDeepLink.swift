//
//  WatchDeepLink.swift
//  Shared
//
//  手表 App / 小组件共用的 deep link 定义
//

import Foundation

enum WatchDeepLink {
    static let scheme = "celechron"

    /// 日程页
    static let flow = URL(string: "celechron://flow")!
    /// 付款码页
    static let ecard = URL(string: "celechron://ecard")!

    enum Destination: String, Hashable {
        case flow
        case ecard
    }

    static func destination(from url: URL) -> Destination? {
        guard url.scheme == scheme else { return nil }
        // celechron://flow  → host = "flow"
        // celechron:///flow → path = "/flow"
        let host = url.host?.lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if host == Destination.flow.rawValue || path == Destination.flow.rawValue {
            return .flow
        }
        if host == Destination.ecard.rawValue || path == Destination.ecard.rawValue
            || host == "pay" || path == "pay"
        {
            return .ecard
        }
        return nil
    }

    /// 打开 Apple 地图导航到地点（步行优先）
    static func mapsURL(for location: String) -> URL? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "无地点" else { return nil }
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: trimmed),
            URLQueryItem(name: "dirflg", value: "w"), // 步行
        ]
        return components?.url
    }
}
