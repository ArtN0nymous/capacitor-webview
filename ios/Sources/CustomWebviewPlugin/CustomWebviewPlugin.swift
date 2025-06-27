import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CustomWebviewPlugin)
public class CustomWebviewPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CustomWebviewPlugin"
    public let jsName = "CustomWebview"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "openWebview", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = CustomWebview()

    @objc func openWebview(_ call: CAPPluginCall) {
        let urlString = call.getString("url") ?? ""
        let debug = call.getBool("debug") ?? false
        guard let url = URL(string: urlString) else {
            if debug { NSLog("[PLUGIN ERROR] Invalid URL: \(urlString)") }
            call.reject("URL is required")
            return
        }

        DispatchQueue.main.async {
            if debug { NSLog("[PLUGIN DEBUG] Starting WebView presentation") }
            if debug { NSLog("[PLUGIN DEBUG] URL: \(url.absoluteString)") }
            if let parentVC = self.bridge?.viewController {
                if debug { NSLog("[PLUGIN DEBUG] parentVC found: \(parentVC)") }

                let webVC = CustomWebviewViewController(url: url)
                webVC.modalPresentationStyle = .fullScreen
                parentVC.present(webVC, animated: true)

                if debug { NSLog("[PLUGIN DEBUG] Presentation requested successfully") }
                call.resolve()
            } else {
                if debug { NSLog("[PLUGIN ERROR] No valid viewController found") }
                call.reject("Could not present the webview")
            }
        }
    }
}
