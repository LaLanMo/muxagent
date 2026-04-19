import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pendingPairingLinkDefaultsKey = "pending_pairing_deeplink_url"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      storePendingPairingLink(url)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    storePendingPairingLink(url)
    return super.application(application, open: url, options: options)
  }

  private func storePendingPairingLink(_ url: URL) {
    NSLog("[NativePreferencePairingLinkSource] storing native link %@", url.absoluteString)
    UserDefaults.standard.set(url.absoluteString, forKey: pendingPairingLinkDefaultsKey)
  }
}
