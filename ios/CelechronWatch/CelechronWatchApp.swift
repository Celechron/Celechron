//
//  CelechronWatchApp.swift
//  CelechronWatch
//
//  手表端宿主 App：首页入口 + deep link 直达日程/付款码 + 地点导航
//

import SwiftUI
import UIKit
import WatchConnectivity
import WidgetKit

@main
struct CelechronWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate
    @State private var path = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                WatchHomeView()
                    .navigationDestination(for: WatchDeepLink.Destination.self) { dest in
                        switch dest {
                        case .flow:
                            WatchFlowPage()
                        case .ecard:
                            WatchECardPayPage()
                        }
                    }
            }
            .onOpenURL { url in
                if let dest = WatchDeepLink.destination(from: url) {
                    // 重置栈后推入目标页，避免多层叠加
                    path = NavigationPath()
                    path.append(dest)
                }
            }
        }
    }
}

// MARK: - Home

struct WatchHomeView: View {
    var body: some View {
        // 单屏布局：Logo 与系统时间同行；入口用系统图标，不展示具体余额/课程
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: WatchDeepLink.Destination.flow) {
                HomeCard(icon: "calendar", title: "日程")
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开今日日程列表")

            NavigationLink(value: WatchDeepLink.Destination.ecard) {
                HomeCard(icon: "qrcode", title: "付款码")
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开校园卡付款码")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // 与系统时间同行：约 26pt，避免过小模糊或过大挤占
                AppLogoView()
                    .frame(width: 26, height: 26)
                    .accessibilityLabel("Celechron")
            }
        }
    }
}

private struct AppLogoView: View {
    var body: some View {
        // 优先 Asset Catalog（正确 @1x/@2x/@3x），避免误用松散 PNG 的错误点密度
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .clipShape(Circle())
    }
}

/// 首页入口：系统 SF Symbol + 标题，不展示具体业务数据
private struct HomeCard: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 28)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .contentShape(Rectangle())
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Flow Page

struct WatchFlowPage: View {
    @State private var flows: [Flow] = []
    @State private var remainingToday = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            List {
                if flows.isEmpty {
                    Section {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                                .symbolRenderingMode(.hierarchical)
                            Text("今日无事可做")
                                .font(.headline)
                            Text("好好休息")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(flows) { flow in
                            FlowCard(date: context.date, flow: flow)
                                .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        if remainingToday > 0 {
                            Text("今日还有 \(remainingToday) 项")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.automatic)
        }
        .navigationTitle("日程")
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: WatchDataSync.didUpdateNotification)) { _ in
            reload()
        }
    }

    private func reload() {
        let data = WidgetAppGroup.defaults?.data(forKey: WidgetAppGroup.flowListKey) ?? Data()
        let flowList = (try? JSONDecoder().decode([PeriodDto?].self, from: data)) ?? []
        let now = Date()
        let nowTs = now.timeIntervalSince1970

        var ongoing: [Flow] = []
        var upcoming: [Flow] = []
        for dto in flowList.compactMap({ $0 }) {
            guard let flow = Flow(from: dto) else { continue }
            let end = TimeInterval(dto.endTime)
            let start = TimeInterval(dto.startTime)
            if end <= nowTs { continue }
            if start <= nowTs {
                ongoing.append(flow)
            } else if start - nowTs <= 172_800 {
                upcoming.append(flow)
            }
        }
        ongoing.sort { $0.endTime < $1.endTime }
        upcoming.sort { $0.startTime < $1.startTime }
        flows = ongoing + upcoming

        remainingToday = upcoming.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: now)
        }.count
    }
}

/// 单条日程卡片：色条 + 标题/地点(可点导航) + 倒计时
private struct FlowCard: View {
    let date: Date
    let flow: Flow
    @Environment(\.openURL) private var openURL

    private var hasBegun: Bool {
        date.compare(flow.startTime) != .orderedAscending
    }

    private var minutesLeft: Int {
        let reference = hasBegun ? flow.endTime : flow.startTime
        return max(0, Int(ceil(date.distance(to: reference) / 60)))
    }

    private var countdownText: String {
        let m = minutesLeft
        if m >= 60 {
            return String(format: "%d:%02d", m / 60, m % 60)
        }
        return "\(m) 分"
    }

    private var statusLabel: String {
        hasBegun ? "后结束" : "后开始"
    }

    private var accent: Color {
        hasBegun ? .blue : .orange
    }

    private var progress: Double {
        guard hasBegun else { return 0 }
        let total = flow.endTime.timeIntervalSince(flow.startTime)
        guard total > 0 else { return 0 }
        let done = date.timeIntervalSince(flow.startTime)
        return min(1, max(0, done / total))
    }

    private var timeRangeText: String {
        "\(flow.startTime.HHmm24())–\(flow.endTime.HHmm24())"
    }

    private var locationText: String {
        flow.location ?? "无地点"
    }

    private var canNavigate: Bool {
        WatchDeepLink.mapsURL(for: locationText) != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(flow.name ?? "未命名日程")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                // 地点：可点击跳转 Apple 地图步行导航（热区 ≥ 44pt）
                Button {
                    if let url = WatchDeepLink.mapsURL(for: locationText) {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: canNavigate ? "location.fill" : "location")
                            .font(.caption2)
                        Text(locationText)
                            .font(.caption2)
                            .lineLimit(1)
                        if canNavigate {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 9))
                        }
                    }
                    .foregroundStyle(canNavigate ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canNavigate)
                .accessibilityLabel(canNavigate ? "导航至\(locationText)" : locationText)
                .accessibilityHint(canNavigate ? "在地图中打开步行路线" : "")

                Text(timeRangeText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(countdownText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                    Text(statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if hasBegun {
                    ProgressView(value: progress)
                        .tint(accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(flow.name ?? "未命名日程")，\(countdownText)\(statusLabel)，\(timeRangeText)")
    }
}

// MARK: - ECard Pay Page (QR)

struct WatchECardPayPage: View {
    @State private var barcode = ""
    @State private var balanceText = "待刷新"
    @State private var qrImage: UIImage?
    @State private var isDemo = true
    @State private var isLoading = false
    @State private var statusMessage = ""
    @AccessibilityFocusState private var announceRefresh: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.78
            VStack(spacing: 4) {
                Spacer(minLength: 4)

                Button {
                    refreshCode()
                } label: {
                    ZStack {
                        Group {
                            if let qrImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: side, height: side)
                        .padding(3)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .opacity(isDemo ? 0.92 : 1)

                        if isLoading {
                            ProgressView()
                                .tint(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(minWidth: side, minHeight: side)
                .contentShape(Rectangle())
                .accessibilityLabel(isDemo ? "演示付款码，点按刷新" : "校园卡付款码，点按刷新")
                .accessibilityHint("生成新的付款码")
                .accessibilityValue(statusMessage.isEmpty ? (isDemo ? "演示码" : "真实码") : statusMessage)

                if isDemo {
                    Text("演示码 · 请在 iPhone 登录")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityLabel("当前为演示码，请在 iPhone 登录校园卡")
                }

                Text(balanceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .navigationTitle("付款码")
        .onAppear {
            reloadBalance()
            refreshCode()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchDataSync.didUpdateNotification)) { _ in
            reloadBalance()
        }
    }

    private func reloadBalance() {
        let defaults = WidgetAppGroup.defaults
        if defaults?.object(forKey: WidgetAppGroup.ecardBalanceKey) == nil {
            balanceText = ECardBalanceFormatter.string(from: 1897)
        } else {
            let balance = defaults?.integer(forKey: WidgetAppGroup.ecardBalanceKey) ?? -1
            balanceText = ECardBalanceFormatter.string(from: balance)
        }
    }

    private var isLoggedIn: Bool {
        WidgetAppGroup.defaults?.bool(forKey: WidgetAppGroup.ecardLoggedInKey) == true
    }

    private func refreshCode() {
        if isLoggedIn {
            requestRealBarcodeFromPhone()
        } else {
            applyDemoCode()
        }
    }

    private func applyDemoCode() {
        isDemo = true
        // 与 iPhone 未登录 mock 一致：16 位随机数字
        barcode = (0 ..< 16).map { _ in String(Int.random(in: 0 ... 9)) }.joined()
        qrImage = SimpleQRCode.image(from: barcode, size: 240)
        statusMessage = "已刷新演示码"
        announceRefresh = true
    }

    private func requestRealBarcodeFromPhone() {
        guard WCSession.isSupported() else {
            applyDemoCode()
            statusMessage = "无法连接 iPhone，已显示演示码"
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            // 手机不可达：仍用演示码但标注
            applyDemoCode()
            statusMessage = "iPhone 未连接，已显示演示码"
            return
        }

        isLoading = true
        session.sendMessage(
            ["action": "requestPayCode"],
            replyHandler: { reply in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let code = reply["barcode"] as? String, !code.isEmpty {
                        let demo = (reply["isDemo"] as? Bool) ?? false
                        self.isDemo = demo
                        self.barcode = code
                        self.qrImage = SimpleQRCode.image(from: code, size: 240)
                        self.statusMessage = demo ? "已刷新演示码" : "已刷新付款码"
                        self.announceRefresh = true
                    } else {
                        self.applyDemoCode()
                        self.statusMessage = "获取失败，已显示演示码"
                    }
                }
            },
            errorHandler: { _ in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.applyDemoCode()
                    self.statusMessage = "获取失败，已显示演示码"
                }
            }
        )
    }
}

// MARK: - App Delegate / WatchConnectivity

final class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate {
    func applicationDidFinishLaunching() {
        activateSession()
        #if DEBUG
        seedPreviewDataIfNeeded()
        #endif
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    #if DEBUG
    private func seedPreviewDataIfNeeded() {
        let defaults = WidgetAppGroup.defaults
        guard defaults?.data(forKey: WidgetAppGroup.flowListKey) == nil else { return }
        let now = Int64(Date().timeIntervalSince1970)
        let sample: [PeriodDto?] = [
            PeriodDto(
                uid: "preview-1",
                type: .classes,
                name: "信号与系统",
                startTime: now - 1800,
                endTime: now + 2700,
                location: "紫金港西1-216"
            ),
            PeriodDto(
                uid: "preview-2",
                type: .classes,
                name: "数据结构",
                startTime: now + 3600,
                endTime: now + 7200,
                location: "玉泉教7-202"
            ),
        ]
        if let data = try? JSONEncoder().encode(sample) {
            defaults?.set(data, forKey: WidgetAppGroup.flowListKey)
        }
        defaults?.set(1897, forKey: WidgetAppGroup.ecardBalanceKey)
        defaults?.set(Date(), forKey: WidgetAppGroup.ecardUpdateTimeKey)
        defaults?.set(false, forKey: WidgetAppGroup.ecardLoggedInKey)
        WidgetCenter.shared.reloadAllTimelines()
        WatchDataSync.notifyUpdated()
    }
    #endif

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            applyApplicationContext(session.receivedApplicationContext)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        applyApplicationContext(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        applyApplicationContext(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyApplicationContext(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        applyApplicationContext(message)
        replyHandler(["ok": true])
    }

    private func applyApplicationContext(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        let defaults = WidgetAppGroup.defaults

        if let flowData = context["flowList"] as? Data {
            defaults?.set(flowData, forKey: WidgetAppGroup.flowListKey)
        } else if let flowBase64 = context["flowListBase64"] as? String,
                  let flowData = Data(base64Encoded: flowBase64)
        {
            defaults?.set(flowData, forKey: WidgetAppGroup.flowListKey)
        }

        if let balance = context["ecardBalance"] as? Int {
            defaults?.set(balance, forKey: WidgetAppGroup.ecardBalanceKey)
            defaults?.set(Date(), forKey: WidgetAppGroup.ecardUpdateTimeKey)
        } else if let balance = context["ecardBalance"] as? NSNumber {
            defaults?.set(balance.intValue, forKey: WidgetAppGroup.ecardBalanceKey)
            defaults?.set(Date(), forKey: WidgetAppGroup.ecardUpdateTimeKey)
        }

        if let ts = context["ecardUpdateTime"] as? TimeInterval {
            defaults?.set(Date(timeIntervalSince1970: ts), forKey: WidgetAppGroup.ecardUpdateTimeKey)
        }

        if let loggedIn = context["ecardLoggedIn"] as? Bool {
            defaults?.set(loggedIn, forKey: WidgetAppGroup.ecardLoggedInKey)
        } else if let loggedIn = context["ecardLoggedIn"] as? NSNumber {
            defaults?.set(loggedIn.boolValue, forKey: WidgetAppGroup.ecardLoggedInKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
        DispatchQueue.main.async {
            WatchDataSync.notifyUpdated()
        }
    }
}
