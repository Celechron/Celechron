//
//  WatchConnectivityBridge.swift
//  Runner
//
//  iPhone → Apple Watch 数据同步（日程列表、校园卡余额、付款码请求）
//

import Foundation
import Security
import WatchConnectivity

final class WatchConnectivityBridge: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityBridge()

    private let testAccount = "3200000000"

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// 从 App Group 读取已有缓存并推送到手表
    func syncFromAppGroup() {
        #if DEBUG
        let suiteName = "group.top.celechron.celechron.debug"
        #else
        let suiteName = "group.top.celechron.celechron"
        #endif
        let defaults = UserDefaults(suiteName: suiteName)
        var payload: [String: Any] = [:]
        if let flowData = defaults?.data(forKey: "flowList") {
            payload["flowList"] = flowData
            payload["flowListBase64"] = flowData.base64EncodedString()
        }
        if defaults?.object(forKey: "ecardBalance") != nil {
            payload["ecardBalance"] = defaults?.integer(forKey: "ecardBalance") ?? -1
        }
        if let updated = defaults?.object(forKey: "ecardUpdateTime") as? Date {
            payload["ecardUpdateTime"] = updated.timeIntervalSince1970
        }
        // 登录态（不含 token）：手表用此分流真码 / 演示码
        let auth = readSynjonesAuth()
        let loggedIn = auth != nil && auth != testAccount
        payload["ecardLoggedIn"] = loggedIn
        defaults?.set(loggedIn, forKey: "ecardLoggedIn")

        guard !payload.isEmpty else { return }
        push(payload: payload)
    }

    /// 同步日程 JSON（与 App Group 中 flowList 一致）
    func syncFlowList(_ data: Data) {
        push(payload: [
            "flowList": data,
            "flowListBase64": data.base64EncodedString(),
        ])
    }

    /// 同步校园卡余额（单位：分；-1 表示待刷新）
    func syncECardBalance(_ balance: Int, updatedAt: Date = Date()) {
        let auth = readSynjonesAuth()
        let loggedIn = auth != nil && auth != testAccount
        push(payload: [
            "ecardBalance": balance,
            "ecardUpdateTime": updatedAt.timeIntervalSince1970,
            "ecardLoggedIn": loggedIn,
        ])
    }

    private func push(payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            // 尚未激活时仍尝试写入 applicationContext 会失败，缓存到 pending
            pending.merge(payload) { _, new in new }
            return
        }

        var context = session.applicationContext
        for (k, v) in payload {
            context[k] = v
        }
        // applicationContext 对 Data 支持有限，flowList 额外用 base64 兜底
        if let flowData = payload["flowList"] as? Data {
            context["flowListBase64"] = flowData.base64EncodedString()
        }
        try? session.updateApplicationContext(context)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    private var pending: [String: Any] = [:]

    // MARK: - Keychain / 付款码

    /// 与 iOS 小组件一致的 Keychain 读取（App Group access group）
    private func readSynjonesAuth() -> String? {
        #if DEBUG
        let accessGroup = "group.top.celechron.celechron.debug"
        #else
        let accessGroup = "group.top.celechron.celechron"
        #endif
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccount: "synjonesAuth",
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService: "Celechron",
            kSecAttrSynchronizable: false,
            kSecReturnData: true,
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        guard status == errSecSuccess, let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func readECardAccount() -> String? {
        #if DEBUG
        let accessGroup = "group.top.celechron.celechron.debug"
        #else
        let accessGroup = "group.top.celechron.celechron"
        #endif
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccount: "eCardAccount",
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService: "Celechron",
            kSecAttrSynchronizable: false,
            kSecReturnData: true,
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        guard status == errSecSuccess, let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 生成演示用随机数字码（与 Flutter 未登录路径一致）
    private func demoBarcode(length: Int = 16) -> String {
        (0 ..< length).map { _ in String(Int.random(in: 0 ... 9)) }.joined()
    }

    /// 手表请求付款码：已登录则走校园卡接口，否则返回演示码
    private func fulfillPayCodeRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        guard let auth = readSynjonesAuth(), auth != testAccount else {
            replyHandler([
                "barcode": demoBarcode(),
                "isDemo": true,
            ])
            return
        }

        fetchBarcode(synjonesAuth: auth) { code in
            if let code, !code.isEmpty {
                replyHandler([
                    "barcode": code,
                    "isDemo": false,
                ])
            } else {
                replyHandler([
                    "barcode": self.demoBarcode(),
                    "isDemo": true,
                ])
            }
        }
    }

    private func fetchBarcode(synjonesAuth: String, completion: @escaping (String?) -> Void) {
        // 先尽量用缓存的 eCardAccount；没有则先拉卡列表
        if let account = readECardAccount(), !account.isEmpty {
            fetchBarcode(auth: synjonesAuth, account: account, completion: completion)
            return
        }
        fetchAccount(auth: synjonesAuth) { account in
            guard let account, !account.isEmpty else {
                completion(nil)
                return
            }
            self.fetchBarcode(auth: synjonesAuth, account: account, completion: completion)
        }
    }

    private func fetchAccount(auth: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://elife.zju.edu.cn/berserker-app/ykt/tsm/getCampusCards") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(auth)", forHTTPHeaderField: "Synjones-Auth")
        request.addValue(
            "E-CampusZJU/2.3.20 (iPhone; iOS 17.5.1; Scale/3.00)",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let cards = dataObj["card"] as? [[String: Any]], !cards.isEmpty
            else {
                completion(nil)
                return
            }
            // 选余额最高的卡
            let sorted = cards.sorted {
                ($0["db_balance"] as? Int ?? 0) > ($1["db_balance"] as? Int ?? 0)
            }
            let account = sorted.first?["account"] as? String
            completion(account)
        }.resume()
    }

    private func fetchBarcode(auth: String, account: String, completion: @escaping (String?) -> Void) {
        let encoded = account.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? account
        guard let url = URL(
            string:
            "https://elife.zju.edu.cn/berserker-app/ykt/tsm/batchGetBarCodeGet?account=\(encoded)&payacc=%23%23%23&paytype=1&synAccessSource=app"
        ) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("bearer \(auth)", forHTTPHeaderField: "synjones-auth")
        request.addValue(
            "E-CampusZJU/2.3.20 (iPhone; iOS 17.5.1; Scale/3.00)",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any]
            else {
                completion(nil)
                return
            }
            if let barcodes = dataObj["barcode"] as? [String], let first = barcodes.first, !first.isEmpty {
                completion(first)
                return
            }
            if let barcodes = dataObj["barcode"] as? [Any],
               let first = barcodes.first as? String, !first.isEmpty
            {
                completion(first)
                return
            }
            completion(nil)
        }.resume()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated, !pending.isEmpty {
            let copy = pending
            pending.removeAll()
            push(payload: copy)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let action = message["action"] as? String, action == "requestPayCode" {
            fulfillPayCodeRequest(replyHandler: replyHandler)
            return
        }
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // 无 reply 的消息忽略
    }
    #endif
}
