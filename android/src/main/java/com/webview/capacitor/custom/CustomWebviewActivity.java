package com.webview.capacitor.custom;

import android.os.Bundle;
import android.util.Log;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.appcompat.app.AppCompatActivity;

public class CustomWebViewActivity extends AppCompatActivity {

    public static final String EXTRA_URL = "url";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        WebView webView = new WebView(this);
        setContentView(webView);

        String url = getIntent().getStringExtra(EXTRA_URL);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setDomStorageEnabled(true);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return false; // permite que el WebView maneje las URL
            }
        });

        webView.setDownloadListener((url1, userAgent, contentDisposition, mimetype, contentLength) -> {
            Log.d("WebViewDownload", "Download requested: " + url1);
            // Aquí puedes manejar la descarga (guardar archivo, usar DownloadManager, etc.)
        });

        webView.loadUrl(url);
    }
}