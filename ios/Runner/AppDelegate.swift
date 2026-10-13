import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
