import Flutter
import QuanYu
import Network
import UIKit
import quanyu_sdk

@main
@objc class AppDelegate: FlutterAppDelegate {

    // MARK: - Properties
    private var enableForceBackground: Bool = false
    private var backtaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var pathMonitor = NWPathMonitor()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 监听网络
        monitorNetWork()

        // 默认参数
        let defaultValues: [String: Any] = [
            "CallKit": true,
            "PushNotification": false,
            "ForceBackground": true,
        ]
        UserDefaults.standard.register(defaults: defaultValues)

        // 添加终止监听
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleTermination),
//            name: UIApplication.willTerminateNotification,
//            object: nil
//        )

        let settings = UserDefaults.standard
        enableForceBackground = settings.bool(forKey: "ForceBackground")

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Background Task Management
    private func beginBackgroundTaskForRegister() {
        backtaskIdentifier = UIApplication.shared.beginBackgroundTask {
            self.endBackgroundTaskForRegister()
        }

        let interval: TimeInterval = 5  // waiting 5 sec, stop endBackgroundTaskForRegister
        Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            self.endBackgroundTaskForRegister()
        }
    }

    private func endBackgroundTaskForRegister() {
        if backtaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backtaskIdentifier)
            backtaskIdentifier = .invalid
        }
    }

    // MARK: - App Lifecycle
    override func applicationDidEnterBackground(_ application: UIApplication) {
        print("applicationDidEnterBackground")

        if enableForceBackground {
            PortSIPManager.shared().startKeepAwake()
        } else {
//            PortSIPManager.shared().unRegister()
            beginBackgroundTaskForRegister()
        }
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        print("applicationWillEnterForeground")

        if enableForceBackground {
            PortSIPManager.shared().stopKeepAwake()

//            var dic: [String: String] = [:]
//            dic["netSatus"] = "有网"
//
//            NotificationCenter.default.post(
//                name: Notification.Name("internetChange"),
//                object: nil,
//                userInfo: dic
//            )
        } else {
//            PortSIPManager.shared().refreshRegister()
        }
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return true
    }

    // MARK: - Network Monitoring
    private func monitorNetWork() {
        pathMonitor.pathUpdateHandler = { path in
            var dic: [String: String] = [:]
            if path.status == .satisfied {
                dic["netSatus"] = "有网"
            } else {
                dic["netSatus"] = "无网"
            }
            NotificationCenter.default.post(
                name: Notification.Name("internetChange"),
                object: nil,
                userInfo: dic
            )
        }
        let queue = DispatchQueue(label: "com.quanyu.network.monitor")
        pathMonitor.start(queue: queue)
    }

    // 处理终止事件
//    @objc func handleTermination() {
//        print("应用即将终止！")
//    }
}

// MARK: -
