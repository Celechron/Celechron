import Flutter
import UIKit
import WidgetKit
import workmanager
import flutter_local_notifications

extension FlutterError: Error {}
private class FlowMessengerImplementation: FlowMessenger {
    func transfer(data: FlowMessage, completion: @escaping (Result<Bool, Error>) -> Void) {
#if DEBUG
        let userDefaults = UserDefaults(suiteName: "group.top.celechron.celechron.debug")
#else
        let userDefaults = UserDefaults(suiteName: "group.top.celechron.celechron")
#endif
        let encoded = try? JSONEncoder().encode(data.flowListDto)
        userDefaults?.set(encoded, forKey: "flowList")
        if let encoded {
            WatchConnectivityBridge.shared.syncFlowList(encoded)
        }
        WatchConnectivityBridge.shared.syncFromAppGroup()
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "FlowWidget")
        }
        completion(.success(true))
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Background AppRefresh MethodChannel
        WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "top.celechron.celechron.backgroundScholarFetch", frequency: NSNumber(value: 15 * 60))
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        // Notification MethodChannel
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
            GeneratedPluginRegistrant.register(with: registry)
        }

        // Apple Watch 数据同步
        WatchConnectivityBridge.shared.activate()
        WatchConnectivityBridge.shared.syncFromAppGroup()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        // Flow widget MethodChannel
        FlowMessengerSetup.setUp(binaryMessenger: engineBridge.applicationRegistrar.messenger(), api: FlowMessengerImplementation())

        // ECard widget MethodChannel
        let ecardWidgetChannel = FlutterMethodChannel(name: "top.celechron.celechron/ecardWidget", binaryMessenger: engineBridge.applicationRegistrar.messenger())
        WatchConnectivityBridge.shared.credentialRefreshHandler = { completion in
            DispatchQueue.main.async {
                ecardWidgetChannel.invokeMethod("refreshCredential", arguments: nil) { value in
                    let success = (value as? Bool) == true
                    if success {
                        if #available(iOS 14.0, *) {
                            WidgetCenter.shared.reloadTimelines(ofKind: "ECardWidget")
                        }
                    }
                    completion(success)
                }
            }
        }
        ecardWidgetChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard call.method == "update" || call.method == "logout" else {
                result(FlutterMethodNotImplemented)
                return
            }
            if call.method == "logout" {
                WatchConnectivityBridge.shared.revokeWatchCredential()
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "ECardWidget")
                }
                result(nil)
                return
            }

            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "ECardWidget")
            }
            // The Dart side writes auth/account before invoking this method, so
            // credentials can be provisioned immediately without waiting for the widget.
            WatchConnectivityBridge.shared.syncCredentialToWatch()
            // 小组件刷新后会写入余额缓存；稍后再同步到手表
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                WatchConnectivityBridge.shared.syncFromAppGroup()
            }
            result(nil)
        })
    }
}
