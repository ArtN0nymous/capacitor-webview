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
        print("[DEBUG] viewDidLoad - Starting CustomWebviewViewController with URL: \(url.absoluteString)")

        view.backgroundColor = .white

        // Barra de botones
        let buttonBar = UIStackView()
        buttonBar.axis = .horizontal
        buttonBar.alignment = .center
        buttonBar.distribution = .equalSpacing
        buttonBar.spacing = 12
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonBar)

        // Botón cerrar
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .black
        closeButton.addTarget(self, action: #selector(closeWebview), for: .touchUpInside)
        buttonBar.addArrangedSubview(closeButton)

        // Botón atrás
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left.circle.fill"), for: .normal)
        backButton.tintColor = .black
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        buttonBar.addArrangedSubview(backButton)

        // Botón adelante
        let forwardButton = UIButton(type: .system)
        forwardButton.setImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        forwardButton.tintColor = .black
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        buttonBar.addArrangedSubview(forwardButton)

        // Botón recargar
        let reloadButton = UIButton(type: .system)
        reloadButton.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
        reloadButton.tintColor = .black
        reloadButton.addTarget(self, action: #selector(reloadWebview), for: .touchUpInside)
        buttonBar.addArrangedSubview(reloadButton)

        // Constraints para la barra de botones
        NSLayoutConstraint.activate([
            buttonBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            buttonBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Configuración avanzada de WKWebView
        let webViewPrefs = WKPreferences()
        webViewPrefs.javaScriptCanOpenWindowsAutomatically = false

        let webViewConf = WKWebViewConfiguration()
        webViewConf.preferences = webViewPrefs
        webViewConf.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            webViewConf.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        webView = WKWebView(frame: .zero, configuration: webViewConf)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Constraints para el WebView
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: buttonBar.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

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

    @objc func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    @objc func reloadWebview() {
        webView.reload()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            print("[DEBUG] URL de navegación no válida")
            decisionHandler(.allow)
            return
        }

        print("[DEBUG] Navigating to: \(url.absoluteString)")

        if isDownloadableFile(url) {
            print("[DEBUG] Detected downloadable file: \(url.lastPathComponent)")
            downloadFile(url)
            decisionHandler(.cancel)
            return
        }

        if url.path.contains("/api/prescription-pdf") {
            print("[DEBUG] URL detected as prescription PDF: \(url.absoluteString)")
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
            print("[DEBUG] Extension detected in query: \(extFromQuery)")
            return allowedExtensions.contains(String(extFromQuery))
        }
        return allowedExtensions.contains(ext)
    }

    func handlePrescriptionPdfDownload(webView: WKWebView, url: URL) {
        print("[DEBUG] Starting prescription PDF download")
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = headers

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("[ERROR] Error downloading prescription: \(error)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ERROR] Invalid response")
                    return
                }

                print("[DEBUG] HTTP status code: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200, let data = data else {
                    print("[ERROR] Invalid data or non-200 response")
                    return
                }

                var filename = "prescription.pdf"
                if let disposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                    print("[DEBUG] Content-Disposition: \(disposition)")
                    // search for filename="something.pdf" or filename=something.pdf
                    let regex = try? NSRegularExpression(pattern: "filename=\"?([^\";]+)\"?", options: [])
                    if let match = regex?.firstMatch(in: disposition, options: [], range: NSRange(location: 0, length: disposition.utf16.count)),
                       let range = Range(match.range(at: 1), in: disposition) {
                        filename = String(disposition[range])
                    }
                }

                if !filename.lowercased().hasSuffix(".pdf") {
                    filename += ".pdf"
                }

                print("[DEBUG] Final file name: \(filename)")
                if !data.starts(with: [0x25, 0x50, 0x44, 0x46]) {
                    let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "\(data.prefix(20))"
                    print("[ERROR] First bytes of file: \(snippet)")
                    return
                }
                self.savePDF(data: data, filename: filename)
            }

            task.resume()
        }
    }

    func downloadFile(_ url: URL) {
        print("[DEBUG] Starting direct file download: \(url.absoluteString)")

        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = headers

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[ERROR] Error in direct download: \(error)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[ERROR] Invalid response")
                    return
                }

                print("[DEBUG] HTTP status code: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200, let data = data else {
                    print("[ERROR] Invalid data or non-200 response")
                    return
                }

                var filename = url.lastPathComponent
                var ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                // Si existe el parámetro 'name', úsalo como nombre de archivo
                if let nameParam = url.valueOf("name"), !nameParam.isEmpty {
                    print("[DEBUG] Parámetro name encontrado: \(nameParam)")
                    filename = nameParam
                    ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                }

                // Si hay Content-Disposition, úsalo como prioridad
                if let disposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                    print("[DEBUG] Content-Disposition: \(disposition)")
                    let filenamePattern = "filename=\"?(.+?)\"?"
                    if let range = disposition.range(of: filenamePattern, options: .regularExpression) {
                        filename = String(disposition[range].dropFirst(9).dropLast())
                        ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
                    }
                }
                // Si no hay extensión, fuerza .pdf por defecto
                if ext.isEmpty {
                    filename += ".pdf"
                }

                print("[DEBUG] Final file name: \(filename)")
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
                print("[DEBUG] Showing PDF preview")
                self.present(previewController, animated: true, completion: nil)
            }
        } catch {
            print("[ERROR] Error al guardar el PDF: \(error)")
        }
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        let count = lastDownloadedPDFURL != nil ? 1 : 0
        print("[DEBUG] Files to preview: \(count)")
        return count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let url = lastDownloadedPDFURL {
            print("[DEBUG] Loading file for preview: \(url.lastPathComponent)")
            return url as QLPreviewItem
        }
        print("[ERROR] No file to preview")
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

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            print("[DEBUG] Intercepted window.open or target=_blank: \(url.absoluteString)")
            // Load the URL in the existing webView
            webView.load(URLRequest(url: url))
        }
        // Return nil to prevent opening a new window
        return nil
    }
}

extension URL {
    func valueOf(_ queryParamaterName: String) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == queryParamaterName })?.value
    }
}
