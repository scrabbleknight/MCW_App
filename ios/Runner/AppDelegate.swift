import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var funnelEnvironmentChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    funnelEnvironmentChannel = FunnelEnvironment.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
  }
}

/// Funnel analytics asks which App Store environment this install came from
/// (lib/core/funnel/analytics_environment.dart): StoreKit 2's signed
/// AppTransaction says production, sandbox (TestFlight and App Review) or
/// xcode. Nothing on iOS 15, or when the App Store can't vouch for it; the
/// app then falls back to the receipt's path.
enum FunnelEnvironment {
  static func register(with messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: "swiftbee/funnel_environment", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "environment" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard #available(iOS 16.0, *) else {
        result([String: Any]())
        return
      }
      Task {
        let appStore = await appStoreEnvironment()
        DispatchQueue.main.async { result(["appStore": appStore as Any]) }
      }
    }
    return channel
  }

  @available(iOS 16.0, *)
  private static func appStoreEnvironment() async -> String? {
    guard case .verified(let transaction)? = try? await AppTransaction.shared else { return nil }
    switch transaction.environment {
    case .production: return "production"
    case .sandbox: return "sandbox"
    case .xcode: return "xcode"
    default: return nil
    }
  }
}

/// Keeps Flutter content clear of the iPadOS window controls (the close /
/// minimise / tile buttons in the top-left corner). Flutter's safe area
/// doesn't include them, so back arrows and avatars sat underneath.
@objc(RunnerViewController)
class RunnerViewController: FlutterViewController {
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard #available(iOS 26.0, *) else { return }
    // The safe area pushed down far enough to clear the window controls.
    // Once our extra inset is applied the two match, so this settles.
    let adapted = view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
    let extra = adapted.top - view.safeAreaInsets.top
    if extra > 0.5 {
      additionalSafeAreaInsets.top += extra
    }
  }
}
