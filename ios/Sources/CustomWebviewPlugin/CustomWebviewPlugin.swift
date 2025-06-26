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
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openWebview", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = CustomWebview()

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }

    @objc func openWebview(_ call: CAPPluginCall) {
        let urlString = call.getString("url") ?? ""
        guard let url = URL(string: urlString) else {
            NSLog("[PLUGIN ERROR] Invalid URL: \(urlString)")
            call.reject("URL is required")
            return
        }

        DispatchQueue.main.async {
            NSLog("[PLUGIN DEBUG] Starting WebView presentation")
            NSLog("[PLUGIN DEBUG] URL: \(url.absoluteString)")
            if let parentVC = self.bridge?.viewController {
                NSLog("[PLUGIN DEBUG] parentVC found: \(parentVC)")

                let webVC = CustomWebviewViewController(url: url)
                webVC.modalPresentationStyle = .fullScreen
                parentVC.present(webVC, animated: true)

                NSLog("[PLUGIN DEBUG] Presentation requested successfully")
                call.resolve()
            } else {
                NSLog("[PLUGIN ERROR] No valid viewController found")
                call.reject("Could not present the webview")
            }
        }
    }
}
