import UIKit
import Flutter
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
        userDefaults?.set(try? JSONEncoder().encode(data.flowListDto), forKey: "flowList")
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "FlowWidget")
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Flow widget MethodChannel
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        FlowMessengerSetup.setUp(binaryMessenger: controller.binaryMessenger, api: FlowMessengerImplementation())
        
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
        
        // ECard widget MethodChannel
        let ecardWidgetChannel = FlutterMethodChannel(name: "top.celechron.celechron/ecardWidget", binaryMessenger: controller.binaryMessenger)
        ecardWidgetChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "ECardWidget")
            }
        })

        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
