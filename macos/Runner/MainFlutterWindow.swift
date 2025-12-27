import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    self.contentViewController = flutterViewController
    
    let frame = CGRect(x: 0, y: 0, width: 393, height: 852) // 模拟手机窗口
    self.setFrame(frame, display: true)
    self.minSize = NSSize(width: 393, height: 852)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
