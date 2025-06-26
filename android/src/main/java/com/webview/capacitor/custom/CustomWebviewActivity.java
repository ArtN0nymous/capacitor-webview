package com.webview.capacitor.custom;

import android.Manifest;
import android.app.Activity;
import android.app.DownloadManager;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;

public class CustomWebViewActivity extends AppCompatActivity {

    public static final String EXTRA_URL = "url";
    private static final int CAMERA_AND_MICROPHONE_PERMISSION_CODE = 1;
    private static final int FILE_CHOOSER_REQUEST_CODE = 2;
    private WebView webView;
    private ValueCallback<Uri[]> mUploadMessage;

    // Interfaz para recibir logs desde JS
    public class NetworkLoggerInterface {
        @JavascriptInterface
        public void log(String type, String url, int status) {
            Log.d("WEBVIEW", type.toUpperCase() + " response from: " + url + " - status: " + status);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_custom_webview);

        webView = findViewById(R.id.webView);

        Button btnBack = findViewById(R.id.btnBack);
        Button btnForward = findViewById(R.id.btnForward);
        Button btnReload = findViewById(R.id.btnReload);
        Button btnClose = findViewById(R.id.btnClose);

        btnBack.setOnClickListener(v -> {
            if (webView.canGoBack()) webView.goBack();
        });

        btnForward.setOnClickListener(v -> {
            if (webView.canGoForward()) webView.goForward();
        });

        btnReload.setOnClickListener(v -> webView.reload());
        btnClose.setOnClickListener(v -> finish());

        WebView.setWebContentsDebuggingEnabled(true);

        String url = getIntent().getStringExtra(EXTRA_URL);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(false);

        webView.addJavascriptInterface(new NetworkLoggerInterface(), "NetworkLogger");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return false;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);

                // Inyecta el JS para monitorear fetch y XHR
                String js = "(function() {" +
                        "const originalFetch = window.fetch;" +
                        "window.fetch = function() {" +
                        "  const url = arguments[0];" +
                        "  return originalFetch.apply(this, arguments)" +
                        "    .then(response => {" +
                        "      window.NetworkLogger.log('fetch-response', url, response.status);" +
                        "      return response;" +
                        "    });" +
                        "};" +
                        "const originalXHROpen = XMLHttpRequest.prototype.open;" +
                        "XMLHttpRequest.prototype.open = function(method, url) {" +
                        "  this._url = url;" +
                        "  return originalXHROpen.apply(this, arguments);" +
                        "};" +
                        "const originalXHRSend = XMLHttpRequest.prototype.send;" +
                        "XMLHttpRequest.prototype.send = function() {" +
                        "  this.addEventListener('loadend', function() {" +
                        "    window.NetworkLogger.log('xhr-response', this._url, this.status);" +
                        "  });" +
                        "  return originalXHRSend.apply(this, arguments);" +
                        "};" +
                        "})();";
                view.evaluateJavascript(js, null);
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
                        checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    request.grant(request.getResources());
                } else {
                    requestCameraAndMicrophonePermission();
                }
            }

            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
                Intent intent = fileChooserParams.createIntent();
                intent.setType("*/*");
                String[] mimeTypes = {"image/jpeg", "image/png", "application/pdf"};
                intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes);
                mUploadMessage = filePathCallback;
                startActivityForResult(intent, FILE_CHOOSER_REQUEST_CODE);
                return true;
            }
        });

        webView.setDownloadListener(new DownloadListener() {
            @Override
            public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimetype, long contentLength) {
                // Descarga en carpeta pública usando DownloadManager
                DownloadManager.Request request = new DownloadManager.Request(Uri.parse(url));
                request.setMimeType(mimetype);

                String cookies = CookieManager.getInstance().getCookie(url);
                request.addRequestHeader("cookie", cookies);
                request.addRequestHeader("User-Agent", userAgent);

                String fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimetype);
                request.setTitle(fileName);
                request.setDescription("Downloading file...");
                request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
                request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

                DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                dm.enqueue(request);

                Toast.makeText(CustomWebViewActivity.this, "File saved in Downloads", Toast.LENGTH_LONG).show();
            }
        });

        webView.loadUrl(url);
    }

    // File result handling
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);
        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            if (mUploadMessage == null) return;
            Uri[] results = null;
            if (resultCode == Activity.RESULT_OK) {
                if (intent != null) {
                    String dataString = intent.getDataString();
                    ClipData clipData = intent.getClipData();
                    if (clipData != null) {
                        results = new Uri[clipData.getItemCount()];
                        for (int i = 0; i < clipData.getItemCount(); i++) {
                            ClipData.Item item = clipData.getItemAt(i);
                            results[i] = item.getUri();
                        }
                    }
                    if (dataString != null)
                        results = new Uri[]{Uri.parse(dataString)};
                }
            }
            mUploadMessage.onReceiveValue(results);
            mUploadMessage = null;
        }
    }

    private void requestCameraAndMicrophonePermission() {
        String[] permissions = {Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO};
        ActivityCompat.requestPermissions(this, permissions, CAMERA_AND_MICROPHONE_PERMISSION_CODE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CAMERA_AND_MICROPHONE_PERMISSION_CODE) {
            if (grantResults.length > 1 && grantResults[0] == PackageManager.PERMISSION_GRANTED
                    && grantResults[1] == PackageManager.PERMISSION_GRANTED) {
                webView.reload();
            } else {
                Toast.makeText(this, "Camera and microphone permissions are required", Toast.LENGTH_SHORT).show();
            }
        }
    }
}