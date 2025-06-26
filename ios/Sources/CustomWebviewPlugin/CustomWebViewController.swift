import UIKit
import WebKit
import QuickLook

class CustomWebviewViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, QLPreviewControllerDataSource, WKScriptMessageHandler {
    var url: URL
    var webView: WKWebView!
    var lastDownloadedPDFURL: URL?

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] viewDidLoad - Iniciando CustomWebviewViewController con URL: \(url.absoluteString)")

        view.backgroundColor = .white

        // Botón de cerrar
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .black
        closeButton.frame = CGRect(x: 16, y: 50, width: 32, height: 32)
        closeButton.addTarget(self, action: #selector(closeWebview), for: .touchUpInside)
        view.addSubview(closeButton)

        // Configuración avanzada de WKWebView
        let webViewPrefs = WKPreferences()
        webViewPrefs.javaScriptCanOpenWindowsAutomatically = false

        let webViewConf = WKWebViewConfiguration()
        webViewConf.preferences = webViewPrefs
        webViewConf.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            webViewConf.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        webView = WKWebView(frame: CGRect(x: 0, y: 90, width: view.frame.width, height: view.frame.height - 90), configuration: webViewConf)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.keyboardDismissMode = .onDrag
        view.addSubview(webView)

        print("[DEBUG] Cargando WebView con URL: \(url.absoluteString)")
        webView.load(URLRequest(url: url))

        let js = """
        (function() {
            const originalFetch = window.fetch;
            window.fetch = function() {
                const url = arguments[0];
                return originalFetch.apply(this, arguments)
                    .then(response => {
                        window.webkit.messageHandlers.networkLogger.postMessage({
                            type: 'fetch-response',
                            url: url,
                            status: response.status
                        });
                        return response;
                    });
            };

            const originalXHROpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                this._url = url;
                return originalXHROpen.apply(this, arguments);
            };
            const originalXHRSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.send = function() {
                this.addEventListener('loadend', function() {
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'xhr-response',
                        url: this._url,
                        status: this.status
                    });
                });
                return originalXHRSend.apply(this, arguments);
            };
        })();
        """

        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
        webView.configuration.userContentController.add(self, name: "networkLogger")
    }

    @objc func closeWebview() {
        print("[DEBUG] Botón cerrar presionado")
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            print("[DEBUG] URL de navegación no válida")
            decisionHandler(.allow)
            return
        }

        print("[DEBUG] Navegando a: \(url.absoluteString)")

        if isDownloadableFile(url) {
            print("[DEBUG] Detectado archivo descargable: \(url.lastPathComponent)")
            downloadFile(url)
            decisionHandler(.cancel)
            return
        }

        if url.path.contains("/api/prescription-pdf") {
            print("[DEBUG] URL detectada como receta PDF: \(url.absoluteString)")
            handlePrescriptionPdfDownload(webView: webView, url: url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // iOS 14+: Detecta descargas iniciadas por el navegador
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        print("[DEBUG] Descarga iniciada (navigationResponse): \(String(describing: download))")
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        print("[DEBUG] Descarga iniciada (navigationAction): \(String(describing: download))")
    }

    // MARK: - Descarga y preview de archivos

    func isDownloadableFile(_ url: URL) -> Bool {
        print("[DEBUG] URL recibida en isDownloadableFile: \(url.absoluteString)")
        print("[DEBUG] lastPathComponent: \(url.lastPathComponent)")
        let ext = URL(fileURLWithPath: url.lastPathComponent).pathExtension.lowercased()
        print("[DEBUG] Analizando extensión: \(ext)")
        let allowedExtensions = ["pdf", "jpeg", "jpg", "png"]
        // También intenta detectar extensión en el query string
        if ext.isEmpty, let extFromQuery = url.valueOf("name")?.split(separator: ".").last?.lowercased() {
            print("[DEBUG] Extensión detectada en query: \(extFromQuery)")
            return allowedExtensions.contains(String(extFromQuery))
        }
        return allowedExtensions.contains(ext)
    }

    func handlePrescriptionPdfDownload(webView: WKWebView, url: URL) {
        print("[DEBUG] Iniciando descarga de receta PDF")
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = headers

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("[ERROR] Error al descargar receta: \(error)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ERROR] Respuesta inválida")
                    return
                }

                print("[DEBUG] Código de estado HTTP: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200, let data = data else {
                    print("[ERROR] Datos inválidos o respuesta no 200")
                    return
                }

                var filename = "prescription.pdf"
                if let disposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                    print("[DEBUG] Content-Disposition: \(disposition)")
                    let filenamePattern = "filename=\"?(.+?)\"?"
                    if let range = disposition.range(of: filenamePattern, options: .regularExpression) {
                        filename = String(disposition[range].dropFirst(9).dropLast())
                    }
                }

                if !filename.lowercased().hasSuffix(".pdf") {
                    filename += ".pdf"
                }

                print("[DEBUG] Nombre final del archivo: \(filename)")
                if !data.starts(with: [0x25, 0x50, 0x44, 0x46]) {
                    let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "\(data.prefix(20))"
                    print("[ERROR] Primeros bytes del archivo: \(snippet)")
                    return
                }
                self.savePDF(data: data, filename: filename)
            }

            task.resume()
        }
    }

    func downloadFile(_ url: URL) {
        print("[DEBUG] Iniciando descarga directa de archivo: \(url.absoluteString)")

        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = headers

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[ERROR] Error en descarga directa: \(error)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ERROR] Respuesta inválida")
                    return
                }

                print("[DEBUG] Código de estado HTTP: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200, let data = data else {
                    print("[ERROR] Datos inválidos o respuesta no 200")
                    return
                }

                var filename = url.lastPathComponent
                var ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                if let disposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                    print("[DEBUG] Content-Disposition: \(disposition)")
                    let filenamePattern = "filename=\"?(.+?)\"?"
                    if let range = disposition.range(of: filenamePattern, options: .regularExpression) {
                        filename = String(disposition[range].dropFirst(9).dropLast())
                        ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                    }
                }
                // Si no hay extensión en el path, intenta obtenerla del query string
                if ext.isEmpty, let extFromQuery = url.valueOf("name")?.split(separator: ".").last?.lowercased() {
                    print("[DEBUG] Usando extensión del query: \(extFromQuery)")
                    ext = String(extFromQuery)
                    filename += ".\(ext)"
                }
                // Si sigue sin extensión, fuerza .pdf por defecto
                if ext.isEmpty {
                    filename += ".pdf"
                }

                print("[DEBUG] Nombre final del archivo: \(filename)")
                self.savePDF(data: data, filename: filename)
            }

            task.resume()
        }
    }

    func savePDF(data: Data, filename: String) {
        print("[DEBUG] Guardando PDF: \(filename)")
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            print("[DEBUG] PDF guardado en: \(fileURL.path)")
            self.lastDownloadedPDFURL = fileURL

            DispatchQueue.main.async {
                let previewController = QLPreviewController()
                previewController.dataSource = self
                print("[DEBUG] Mostrando vista previa del PDF")
                self.present(previewController, animated: true, completion: nil)
            }
        } catch {
            print("[ERROR] Error al guardar el PDF: \(error)")
        }
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        let count = lastDownloadedPDFURL != nil ? 1 : 0
        print("[DEBUG] Archivos para previsualizar: \(count)")
        return count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let url = lastDownloadedPDFURL {
            print("[DEBUG] Cargando archivo para preview: \(url.lastPathComponent)")
            return url as QLPreviewItem
        }
        print("[ERROR] No hay archivo para previsualizar")
        return URL(fileURLWithPath: "") as QLPreviewItem
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "networkLogger", let body = message.body as? [String: Any] {
            let type = body["type"] as? String ?? "unknown"
            let url = body["url"] as? String ?? ""
            let status = body["status"] as? Int
            if let status = status {
                NSLog("[WEBVIEW] \(type.uppercased()) response from: \(url) - status: \(status)")
            } else {
                NSLog("[WEBVIEW] \(type.uppercased()) request to: \(url)")
            }
        }
    }
}

extension URL {
    func valueOf(_ queryParamaterName: String) -> String? {
        guard let url = URLComponents(string: self.absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == queryParamaterName })?.value
    }
}
