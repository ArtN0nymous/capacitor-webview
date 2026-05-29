import UIKit
import WebKit
import QuickLook

class CustomWebviewViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, QLPreviewControllerDataSource, WKScriptMessageHandler {
    var url: URL
    var webView: WKWebView!
    var lastDownloadedPDFURL: URL?
    var debug: Bool = false
    var enableCookies: Bool = false
    var onClose: (() -> Void)?
    private var didNotifyClose = false

    init(url: URL, debug: Bool = false, enableCookies: Bool = false) {
        self.url = url
        self.debug = debug
        self.enableCookies = enableCookies
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        if debug { print("[DEBUG] viewDidLoad - Starting CustomWebviewViewController with URL: \(url.absoluteString)") }

        view.backgroundColor = .white

        // Button bar setup
        let buttonBar = UIStackView()
        buttonBar.axis = .horizontal
        buttonBar.alignment = .center
        buttonBar.distribution = .equalSpacing
        buttonBar.spacing = 12
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonBar)

        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .black
        closeButton.addTarget(self, action: #selector(closeWebview), for: .touchUpInside)
        buttonBar.addArrangedSubview(closeButton)

        // Back button
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left.circle.fill"), for: .normal)
        backButton.tintColor = .black
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        buttonBar.addArrangedSubview(backButton)

        // Forward button
        let forwardButton = UIButton(type: .system)
        forwardButton.setImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        forwardButton.tintColor = .black
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        buttonBar.addArrangedSubview(forwardButton)

        // refresh button
        let reloadButton = UIButton(type: .system)
        reloadButton.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
        reloadButton.tintColor = .black
        reloadButton.addTarget(self, action: #selector(reloadWebview), for: .touchUpInside)
        buttonBar.addArrangedSubview(reloadButton)

        // Constraints for the button bar
        NSLayoutConstraint.activate([
            buttonBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            buttonBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        // webview configuration
        let webViewPrefs = WKPreferences()
        webViewPrefs.javaScriptCanOpenWindowsAutomatically = false

        let webViewConf = WKWebViewConfiguration()
        webViewConf.preferences = webViewPrefs
        webViewConf.websiteDataStore = enableCookies ? .default() : .nonPersistent()
        webViewConf.allowsInlineMediaPlayback = true
        if #available(iOS 14.0, *) {
            webViewConf.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        if debug {
            let storeType = enableCookies ? "default (persistent, shared)" : "nonPersistent (isolated)"
            print("[DEBUG] Cookie store: \(storeType)")
        }

        webView = WKWebView(frame: .zero, configuration: webViewConf)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Constraints for the webview
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: buttonBar.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if debug { print("[DEBUG] Cargando WebView con URL: \(url.absoluteString)") }
        webView.load(URLRequest(url: url))

        if debug {
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
    }

    @objc func closeWebview() {
        if debug { print("[DEBUG] Botón cerrar presionado") }
        dismiss(animated: true) { [weak self] in
            self?.notifyCloseIfNeeded()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            notifyCloseIfNeeded()
        }
    }

    private func notifyCloseIfNeeded() {
        guard !didNotifyClose else { return }
        didNotifyClose = true
        onClose?()
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
            if debug { print("[DEBUG] URL de navegación no válida") }
            decisionHandler(.allow)
            return
        }

        if debug { print("[DEBUG] Navigating to: \(url.absoluteString)") }

        if shouldDownloadPdfFromURL(url) {
            if debug { print("[DEBUG] PDF detectado por URL: \(url.absoluteString)") }
            downloadPdf(from: url)
            decisionHandler(.cancel)
            return
        }

        if isDownloadableImage(url) {
            if debug { print("[DEBUG] Imagen detectada: \(url.lastPathComponent)") }
            downloadFile(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame,
              let httpResponse = navigationResponse.response as? HTTPURLResponse,
              let url = httpResponse.url else {
            decisionHandler(.allow)
            return
        }

        let mimeType = httpResponse.mimeType
        let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition")

        if shouldDownloadPdf(url: url, mimeType: mimeType, contentDisposition: contentDisposition) {
            if debug { print("[DEBUG] PDF detectado por respuesta HTTP: \(url.absoluteString)") }
            let suggestedFilename = filenameFromContentDisposition(contentDisposition)
            downloadPdf(from: url, suggestedFilename: suggestedFilename)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // iOS 14+: handle downloads initiated by navigation actions or responses
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        if debug { print("[DEBUG] Descarga iniciada (navigationResponse): \(String(describing: download))") }
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        if debug { print("[DEBUG] Descarga iniciada (navigationAction): \(String(describing: download))") }
    }

    // MARK: - File Download Handling

    func shouldDownloadPdfFromURL(_ url: URL) -> Bool {
        if fileExtension(from: url.lastPathComponent) == "pdf" { return true }

        for queryKey in ["filename", "file", "name", "download"] {
            if let value = url.valueOf(queryKey), fileExtension(from: value) == "pdf" {
                return true
            }
        }

        return false
    }

    func shouldDownloadPdf(url: URL, mimeType: String?, contentDisposition: String?) -> Bool {
        if mimeType?.lowercased() == "application/pdf" { return true }
        if shouldDownloadPdfFromURL(url) { return true }

        if let disposition = contentDisposition?.lowercased() {
            if disposition.contains("filename="),
               let filename = filenameFromContentDisposition(contentDisposition),
               filename.lowercased().hasSuffix(".pdf") {
                return true
            }
            if disposition.contains("attachment"), mimeType?.lowercased() == "application/pdf" {
                return true
            }
        }

        return false
    }

    func isDownloadableImage(_ url: URL) -> Bool {
        let allowedExtensions = ["jpeg", "jpg", "png"]
        let ext = fileExtension(from: url.lastPathComponent)
        if allowedExtensions.contains(ext) { return true }

        for queryKey in ["filename", "file", "name", "download"] {
            if let value = url.valueOf(queryKey), allowedExtensions.contains(fileExtension(from: value)) {
                return true
            }
        }

        return false
    }

    func fileExtension(from filename: String) -> String {
        URL(fileURLWithPath: filename).pathExtension.lowercased()
    }

    func filenameFromContentDisposition(_ contentDisposition: String?) -> String? {
        guard let contentDisposition else { return nil }

        let regex = try? NSRegularExpression(pattern: "filename\\*?=(?:UTF-8''|\"?)([^\";]+)", options: [.caseInsensitive])
        let range = NSRange(location: 0, length: contentDisposition.utf16.count)
        if let match = regex?.firstMatch(in: contentDisposition, options: [], range: range),
           let filenameRange = Range(match.range(at: 1), in: contentDisposition) {
            return String(contentDisposition[filenameRange]).removingPercentEncoding
        }

        return nil
    }

    func resolveFilename(for url: URL, httpResponse: HTTPURLResponse?, suggestedFilename: String?) -> String {
        if let suggestedFilename, !suggestedFilename.isEmpty {
            return suggestedFilename.lowercased().hasSuffix(".pdf") ? suggestedFilename : "\(suggestedFilename).pdf"
        }

        if let disposition = httpResponse?.value(forHTTPHeaderField: "Content-Disposition"),
           let filename = filenameFromContentDisposition(disposition), !filename.isEmpty {
            return filename.lowercased().hasSuffix(".pdf") ? filename : "\(filename).pdf"
        }

        for queryKey in ["filename", "file", "name", "download"] {
            if let value = url.valueOf(queryKey), !value.isEmpty {
                return value.lowercased().hasSuffix(".pdf") ? value : "\(value).pdf"
            }
        }

        let lastPath = url.lastPathComponent
        if !lastPath.isEmpty, lastPath != "/" {
            return lastPath.lowercased().hasSuffix(".pdf") ? lastPath : "\(lastPath).pdf"
        }

        return "download.pdf"
    }

    func downloadPdf(from url: URL, suggestedFilename: String? = nil) {
        if debug { print("[DEBUG] Iniciando descarga de PDF: \(url.absoluteString)") }

        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    if self.debug { print("[ERROR] Error descargando PDF: \(error)") }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    if self.debug { print("[ERROR] Respuesta inválida") }
                    return
                }

                if self.debug { print("[DEBUG] HTTP status code: \(httpResponse.statusCode)") }

                guard (200...299).contains(httpResponse.statusCode), let data = data else {
                    if self.debug { print("[ERROR] Datos inválidos o respuesta no exitosa") }
                    return
                }

                let filename = self.resolveFilename(for: url, httpResponse: httpResponse, suggestedFilename: suggestedFilename)
                if self.debug { print("[DEBUG] Nombre final del archivo: \(filename)") }

                if !data.starts(with: [0x25, 0x50, 0x44, 0x46]) {
                    if self.debug { print("[ERROR] El archivo descargado no es un PDF válido") }
                    return
                }

                self.savePDF(data: data, filename: filename)
            }

            task.resume()
        }
    }

    func downloadFile(_ url: URL) {
        if debug { print("[DEBUG] Starting direct file download: \(url.absoluteString)") }

        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            var request = URLRequest(url: url)
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = headers

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    if self.debug { print("[ERROR] Error in direct download: \(error)") }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    if self.debug { print("[ERROR] Invalid response") }
                    return
                }

                if self.debug { print("[DEBUG] HTTP status code: \(httpResponse.statusCode)") }

                guard (200...299).contains(httpResponse.statusCode), let data = data else {
                    if self.debug { print("[ERROR] Invalid data or non-200 response") }
                    return
                }

                var filename = url.lastPathComponent
                var ext = fileExtension(from: filename)
                for queryKey in ["filename", "file", "name", "download"] {
                    if let value = url.valueOf(queryKey), !value.isEmpty {
                        filename = value
                        ext = fileExtension(from: filename)
                        break
                    }
                }

                if let disposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
                   let dispositionFilename = filenameFromContentDisposition(disposition) {
                    filename = dispositionFilename
                    ext = fileExtension(from: filename)
                }

                if ext.isEmpty {
                    filename += ".pdf"
                }

                if self.debug { print("[DEBUG] Final file name: \(filename)") }
                self.savePDF(data: data, filename: filename)
            }

            task.resume()
        }
    }

    func savePDF(data: Data, filename: String) {
        if debug { print("[DEBUG] Guardando PDF: \(filename)") }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            if debug { print("[DEBUG] PDF guardado en: \(fileURL.path)") }
            self.lastDownloadedPDFURL = fileURL

            DispatchQueue.main.async {
                let previewController = QLPreviewController()
                previewController.dataSource = self
                if self.debug { print("[DEBUG] Showing PDF preview") }
                self.present(previewController, animated: true, completion: nil)
            }
        } catch {
            if debug { print("[ERROR] Error al guardar el PDF: \(error)") }
        }
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        let count = lastDownloadedPDFURL != nil ? 1 : 0
        if debug { print("[DEBUG] Files to preview: \(count)") }
        return count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let url = lastDownloadedPDFURL {
            if debug { print("[DEBUG] Loading file for preview: \(url.lastPathComponent)") }
            return url as QLPreviewItem
        }
        if debug { print("[ERROR] No file to preview") }
        return URL(fileURLWithPath: "") as QLPreviewItem
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "networkLogger", let body = message.body as? [String: Any] {
            let type = body["type"] as? String ?? "unknown"
            let url = body["url"] as? String ?? ""
            let status = body["status"] as? Int
            if debug {
                if let status = status {
                    NSLog("[WEBVIEW] \(type.uppercased()) response from: \(url) - status: \(status)")
                } else {
                    NSLog("[WEBVIEW] \(type.uppercased()) request to: \(url)")
                }
            }
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if debug { print("[DEBUG] Intercepted window.open or target=_blank: \(url.absoluteString)") }
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
