import UIKit
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  var rtsp: RTSPPlayer?
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "rtsp_bridge", binaryMessenger: controller.binaryMessenger)
    rtsp = RTSPPlayer(channel: channel)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
        case "start": let url = (call.arguments as! [String:Any])["url"] as! String; self.rtsp?.start(url: url); result(nil)
        case "stop": self.rtsp?.stop(); result(nil)
        case "setInterval": let ms = (call.arguments as! [String:Any])["ms"] as! Int; self.rtsp?.setInterval(ms: ms); result(nil)
        default: result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
