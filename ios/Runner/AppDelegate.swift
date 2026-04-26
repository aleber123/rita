import Flutter
import UIKit
import StoreKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SKPaymentQueue.default().add(self)
    GeneratedPluginRegistrant.register(with: self)

    // Widget MethodChannel
    let controller = window?.rootViewController as! FlutterViewController
    let widgetChannel = FlutterMethodChannel(
      name: "com.alexanderbergqvist.birthdayreminder/widget",
      binaryMessenger: controller.binaryMessenger
    )
    widgetChannel.setMethodCallHandler { call, result in
      if call.method == "updateWidget", let args = call.arguments as? [String: Any],
         let data = args["data"] as? String {
        let defaults = UserDefaults(suiteName: "group.com.alexanderbergqvist.birthdayreminder")
        defaults?.set(data, forKey: "widgetData")
        defaults?.synchronize()
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - SKPaymentTransactionObserver
extension AppDelegate: SKPaymentTransactionObserver {
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    // Transactions are handled by the Flutter in_app_purchase plugin.
    // This observer is registered early to ensure iOS delivers all
    // queued transactions to the plugin when it attaches its own listener.
  }
}
