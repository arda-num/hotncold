import Flutter
import UIKit
import ARKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Shared reference to active AR view
  static weak var activeARView: ARKitView?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register ARKit platform view
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }
    
    let messenger = controller.binaryMessenger
    
    // Setup method channel for AR
    let methodChannel = FlutterMethodChannel(
      name: "com.hotncold.ar/native_ar",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "isARSupported":
        let isSupported = ARWorldTrackingConfiguration.isSupported
        print("[ARKit AppDelegate] isARSupported: \(isSupported)")
        print("[ARKit AppDelegate] Device: \(UIDevice.current.model), iOS: \(UIDevice.current.systemVersion)")
        result(isSupported)
        
      case "startARSession":
        print("[ARKit AppDelegate] startARSession called")
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }
        if let arView = AppDelegate.activeARView {
          print("[ARKit AppDelegate] Forwarding to active AR view")
          arView.startARSessionFromChannel(args: args, result: result)
        } else {
          print("[ARKit AppDelegate] ERROR: No active AR view")
          result(FlutterError(code: "NO_VIEW", message: "ARKit view not initialized", details: nil))
        }
        
      case "stopARSession":
        if let arView = AppDelegate.activeARView {
          arView.stopARSessionFromChannel(result: result)
        } else {
          result(true)
        }
        
      case "collectReward":
        if let arView = AppDelegate.activeARView {
          arView.collectRewardFromChannel(result: result)
        } else {
          result(FlutterError(code: "NO_VIEW", message: "ARKit view not initialized", details: nil))
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Setup event channel
    let eventChannel = FlutterEventChannel(
      name: "com.hotncold.ar/ar_events",
      binaryMessenger: messenger
    )
    let eventHandler = AREventStreamHandler()
    eventChannel.setStreamHandler(eventHandler)
    
    // Register platform view factory with event handler
    let factory = ARKitViewFactory(messenger: messenger, eventHandler: eventHandler)
    registrar(forPlugin: "ARKitPlugin")?.register(
      factory,
      withId: "com.hotncold.ar/arkit_view"
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
