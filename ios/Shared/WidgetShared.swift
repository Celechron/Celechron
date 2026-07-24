//
//  WidgetShared.swift
//  Shared models and helpers for iOS / watchOS widgets
//

import Foundation

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

/// 展示用日程模型；时间为非可选，坏数据在转换时丢弃。
struct Flow: Identifiable, Hashable {
    let uid: String
    let location: String?
    let name: String?
    let startTime: Date
    let endTime: Date

    var id: String { uid }

    init(uid: String, location: String?, name: String?, startTime: Date, endTime: Date) {
        self.uid = uid
        self.location = location
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
    }

    /// 无效时间区间返回 nil，避免强制解包崩溃。
    init?(from dto: PeriodDto) {
        let start = Date(timeIntervalSince1970: TimeInterval(dto.startTime))
        let end = Date(timeIntervalSince1970: TimeInterval(dto.endTime))
        guard end > start else { return nil }
        self.uid = dto.uid.isEmpty ? "\(dto.startTime)-\(dto.endTime)-\(dto.name ?? "")" : dto.uid
        self.location = dto.location
        self.name = dto.name
        self.startTime = start
        self.endTime = end
    }
}

enum WidgetAppGroup {
    static var suiteName: String {
        #if DEBUG
        return "group.top.celechron.celechron.debug"
        #else
        return "group.top.celechron.celechron"
        #endif
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static let flowListKey = "flowList"
    static let ecardBalanceKey = "ecardBalance"
    static let ecardUpdateTimeKey = "ecardUpdateTime"
    /// 是否已登录校园卡（不含 token；仅布尔/状态，供手表 UI 分流）
    static let ecardLoggedInKey = "ecardLoggedIn"
}

/// App Group / WatchConnectivity 写入后广播，手表页面 onReceive 刷新。
enum WatchDataSync {
    static let didUpdateNotification = Notification.Name("celechron.watchDataDidUpdate")

    static func notifyUpdated() {
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }
}

extension Date {
    /// 跟随系统 Locale 的 HH:mm（24 小时制数字时钟常用）
    func HHmm(withFormat format: String = "HH:mm") -> String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale.current))
    }

    /// 紧凑 24h：08:30
    func HHmm24() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

enum ECardBalanceFormatter {
    /// balance 单位为分；负值表示待刷新
    static func string(from balance: Int) -> String {
        if balance < 0 {
            return "待刷新"
        }
        let yuan = Double(balance) / 100.0
        let fraction = (balance % 10 == 0) ? 1 : 2
        let formatted = yuan.formatted(
            .number
                .precision(.fractionLength(fraction))
                .locale(Locale.current)
        )
        return "\(formatted)元"
    }

    /// 紧凑显示，适合圆形表盘：18.97 / 待刷新
    static func compact(from balance: Int) -> String {
        if balance < 0 {
            return "--"
        }
        if balance < 10000 {
            return String(
                format: "%d.%d%d",
                balance / 100,
                balance % 100 / 10,
                balance % 10
            )
        }
        return String(format: "%d", balance / 100)
    }
}

enum FlowTimelineBuilder {
    static func buildEntries(
        from flowList: [PeriodDto?]?,
        now: Date = Date()
    ) -> [FlowEntryData] {
        let currentTime = Date(
            timeIntervalSince1970: now.timeIntervalSince1970
                - TimeInterval(Int(now.timeIntervalSince1970) % 60)
        )

        var onGoingFlows: [Flow] = []
        var upComingFlows: [Flow] = []
        flowList?.forEach { e in
            guard let e, let flow = Flow(from: e) else { return }
            let timeToStart = flow.startTime.timeIntervalSince(currentTime)
            let timeToEnd = flow.endTime.timeIntervalSince(currentTime)
            if timeToEnd > 0 {
                if timeToStart <= 0 {
                    onGoingFlows.append(flow)
                } else if timeToStart <= 172800 {
                    upComingFlows.append(flow)
                }
            }
        }
        upComingFlows.sort { $0.startTime < $1.startTime }

        var entries: [FlowEntryData] = []
        for minuteOffset in 0 ..< 90 {
            guard let refreshTime = Calendar.current.date(
                byAdding: .minute, value: minuteOffset, to: currentTime
            ) else { continue }

            onGoingFlows.removeAll { $0.endTime <= refreshTime }
            if onGoingFlows.isEmpty && upComingFlows.isEmpty {
                entries.append(
                    FlowEntryData(refreshAt: refreshTime, toDisplay: [], stillToDoToday: 0)
                )
                break
            }

            let refreshTimePlus30Min = refreshTime.addingTimeInterval(1800)
            var nearestFlows: [Flow] = []
            nearestFlows.append(contentsOf: onGoingFlows)
            var justHappenedIndex: Int = -1

            if let firstUpcoming = upComingFlows.first {
                let shouldTakeFirst =
                    (onGoingFlows.isEmpty
                        && (Calendar.current.isDate(firstUpcoming.startTime, inSameDayAs: refreshTime)
                            || firstUpcoming.startTime <= refreshTime.addingTimeInterval(36000)))
                    || firstUpcoming.startTime <= refreshTimePlus30Min
                if shouldTakeFirst {
                    nearestFlows.append(firstUpcoming)
                    justHappenedIndex = 0
                }
            }

            if !upComingFlows.isEmpty {
                for i in stride(from: 1, to: upComingFlows.count, by: 1) {
                    if upComingFlows[i].startTime <= refreshTimePlus30Min {
                        nearestFlows.append(upComingFlows[i])
                        justHappenedIndex = i
                    } else {
                        break
                    }
                }
            }

            if justHappenedIndex >= 0 {
                onGoingFlows.append(contentsOf: upComingFlows[0 ... justHappenedIndex])
                upComingFlows.removeSubrange(0 ... justHappenedIndex)
            }

            let remaining = upComingFlows.firstIndex(where: {
                !Calendar.current.isDate($0.startTime, inSameDayAs: refreshTime)
            }) ?? upComingFlows.count
            entries.append(
                FlowEntryData(
                    refreshAt: refreshTime,
                    toDisplay: nearestFlows,
                    stillToDoToday: remaining
                )
            )
        }
        return entries
    }
}

struct FlowEntryData {
    let date: Date
    let flows: [Flow]
    let remaining: Int

    init(refreshAt date: Date, toDisplay flows: [Flow], stillToDoToday remaining: Int) {
        self.date = date
        self.flows = flows
        self.remaining = remaining
    }
}
