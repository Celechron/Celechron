//
//  WatchConnectivityBridge.swift
//  Celechron
//
//  iPhone → Apple Watch 数据同步（日程列表、校园卡余额、付款码请求）
//

import Foundation
import Security
import WatchConnectivity

final class WatchConnectivityBridge: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityBridge()

    private let testAccount = "3200000000"
    private let ecardService = ECardService()
    private let revisionLock = NSLock()
    private var lastCredentialRevision: Int64 = 0

    /// Installed by AppDelegate after the Flutter engine is ready. The Dart
    /// implementation reuses ECardWidgetMessenger's existing CAS refresh path.
    var credentialRefreshHandler: ((@escaping (Bool) -> Void) -> Void)?

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
        if loggedIn {
            pushCredentialIfReachable()
        } else {
            sendCredentialRevocationIfReachable()
        }
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
        if loggedIn {
            pushCredentialIfReachable()
        }
    }

    /// Called after ECardWidgetMessenger has refreshed the iPhone Keychain.
    func syncCredentialToWatch() {
        syncFromAppGroup()
    }

    /// Revocation contains no secret, so the normal reliable context path is
    /// safe. Watch also deletes the Keychain item when ecardLoggedIn becomes false.
    func revokeWatchCredential() {
        push(payload: ["ecardLoggedIn": false])
        sendCredentialRevocationIfReachable()
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

    private func writeECardAccount(_ value: String) {
        #if DEBUG
        let accessGroup = "group.top.celechron.celechron.debug"
        #else
        let accessGroup = "group.top.celechron.celechron"
        #endif
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "eCardAccount",
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService: "Celechron",
            kSecAttrSynchronizable: false,
        ]
        let data = Data(value.utf8)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private func nextCredentialRevision() -> Int64 {
        revisionLock.lock()
        defer { revisionLock.unlock() }
        let now = Int64(Date().timeIntervalSince1970 * 1_000)
        lastCredentialRevision = max(now, lastCredentialRevision + 1)
        return lastCredentialRevision
    }

    private func credentialPayload(auth: String, account: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "auth": auth,
            "revision": nextCredentialRevision(),
        ]
        if let account, !account.isEmpty {
            payload["account"] = account
        }
        return payload
    }

    private func currentCredentialPayload() -> [String: Any]? {
        guard let auth = readSynjonesAuth(), !auth.isEmpty, auth != testAccount else { return nil }
        return credentialPayload(auth: auth, account: readECardAccount())
    }

    /// Credentials are intentionally sent only as a live message. They never
    /// enter applicationContext or transferUserInfo, both of which persist data.
    private func pushCredentialIfReachable() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable,
              let credential = currentCredentialPayload()
        else {
            return
        }
        WCSession.default.sendMessage(
            [
                "action": "provisionPayCredential",
                "credential": credential,
            ],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    private func sendCredentialRevocationIfReachable() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable
        else {
            return
        }
        WCSession.default.sendMessage(
            ["action": "revokePayCredential"],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    /// 生成演示用随机数字码（与 Flutter 未登录路径一致）
    private func demoBarcode(length: Int = 16) -> String {
        (0 ..< length).map { _ in String(Int.random(in: 0 ... 9)) }.joined()
    }

    /// 手表回退请求：iPhone 使用与 ECardWidget 相同的服务和错误分类。
    private func fulfillPayCodeRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        guard let auth = readSynjonesAuth(), auth != testAccount else {
            replyHandler([
                "barcode": demoBarcode(),
                "isDemo": true,
                "loggedIn": false,
            ])
            return
        }

        ecardService.fetchPayCode(auth: auth, cachedAccount: readECardAccount()) { result in
            switch result {
            case let .success(payCode):
                if payCode.account != self.readECardAccount() {
                    self.writeECardAccount(payCode.account)
                }
                replyHandler([
                    "barcode": payCode.code,
                    "isDemo": false,
                    "loggedIn": true,
                    "credential": self.credentialPayload(auth: auth, account: payCode.account),
                ])
            case let .failure(error):
                replyHandler([
                    "error": error.wireValue,
                    "loggedIn": true,
                    "retryable": error == .transientFailure,
                    "needsRefresh": error == .authenticationExpired,
                ])
            }
        }
    }

    private func fulfillCredentialRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        guard let credential = currentCredentialPayload() else {
            replyHandler(["loggedIn": false])
            return
        }
        replyHandler([
            "loggedIn": true,
            "credential": credential,
        ])
    }

    private func fulfillCredentialRefresh(replyHandler: @escaping ([String: Any]) -> Void) {
        guard let handler = credentialRefreshHandler else {
            replyHandler(["error": "refreshUnavailable", "retryable": false])
            return
        }
        handler { success in
            guard success, let credential = self.currentCredentialPayload() else {
                replyHandler(["error": "refreshFailed", "retryable": false])
                return
            }
            replyHandler([
                "loggedIn": true,
                "credential": credential,
            ])
            self.pushCredentialIfReachable()
        }
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
        if activationState == .activated {
            pushCredentialIfReachable()
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
        guard let action = message["action"] as? String else {
            replyHandler(["ok": true])
            return
        }
        if action == "requestPayCode" {
            fulfillPayCodeRequest(replyHandler: replyHandler)
            return
        }
        if action == "requestPayCredential" {
            fulfillCredentialRequest(replyHandler: replyHandler)
            return
        }
        if action == "refreshPayCredential" {
            fulfillCredentialRefresh(replyHandler: replyHandler)
            return
        }
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // 无 reply 的消息忽略
    }
    #endif
}
