import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var funnelEnvironmentChannel: FlutterMethodChannel?
  private var subscriptionStatusChannel: FlutterMethodChannel?
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
    subscriptionStatusChannel = SubscriptionStatus.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
  }
}

/// Trial analytics asks whether the live subscription will renew and
/// whether it's still in its free trial (lib/core/funnel/trial_engagement.dart).
/// in_app_purchase doesn't expose StoreKit 2's renewal info. Answers nil when
/// there's no live subscription or the renewal status can't be read.
enum SubscriptionStatus {
  static func register(with messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: "swiftbee/subscription_status", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "status" else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task {
        let status = await current()
        DispatchQueue.main.async { result(status) }
      }
    }
    return channel
  }

  private static func current() async -> [String: Any]? {
    var latest: Transaction?
    for await entitlement in Transaction.currentEntitlements {
      guard case .verified(let t) = entitlement,
            t.productType == .autoRenewable,
            t.revocationDate == nil else { continue }
      if latest == nil || t.purchaseDate > latest!.purchaseDate { latest = t }
    }
    guard let t = latest,
          let product = try? await Product.products(for: [t.productID]).first,
          let statuses = try? await product.subscription?.status else { return nil }
    var willAutoRenew: Bool?
    for s in statuses {
      guard case .verified(let renewal) = s.renewalInfo,
            case .verified(let tx) = s.transaction,
            tx.originalID == t.originalID else { continue }
      willAutoRenew = renewal.willAutoRenew
    }
    guard let willAutoRenew else { return nil }

    // The Annual (Friend) intro offer is a paid first year, not a trial.
    var inFreeTrial = t.offerType == .introductory && !t.productID.hasSuffix(".friend")
    if #available(iOS 17.2, *), let offer = t.offer {
      inFreeTrial = offer.paymentMode == .freeTrial
    }
    var out: [String: Any] = [
      "productId": t.productID,
      "willAutoRenew": willAutoRenew,
      "inFreeTrial": inFreeTrial,
      "originalPurchaseDate": t.originalPurchaseDate.timeIntervalSince1970 * 1000,
    ]
    if let expires = t.expirationDate {
      out["expirationDate"] = expires.timeIntervalSince1970 * 1000
    }
    return out
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
