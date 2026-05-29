package com.webview.capacitor.custom;

import android.content.Intent;
import android.util.Log;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CustomWebview")
public class CustomWebviewPlugin extends Plugin {

    private static final String TAG = "CustomWebviewPlugin";
    private static CustomWebviewPlugin instance;
    private CustomWebview implementation = new CustomWebview();

    public CustomWebviewPlugin() {
        super();
        Log.d(TAG, "[PLUGIN DEBUG] CustomWebviewPlugin initialized");
    }

    @Override
    public void load() {
        instance = this;
    }

    static CustomWebviewPlugin getInstance() {
        return instance;
    }

    void fireWebviewClosedEvent() {
        notifyListeners("webviewClosed", new JSObject());
    }

    @PluginMethod
    public void openWebview(PluginCall call) {
        boolean debug = call.getBoolean("debug", false);
        boolean enableCookies = call.getBoolean("enableCookies", false);
        String url = call.getString("url");
        if (debug) Log.d(TAG, "[PLUGIN DEBUG] openWebview called");
        if (url == null || url.isEmpty()) {
            if (debug) Log.e(TAG, "[PLUGIN ERROR] URL is required");
            call.reject("URL is required");
            return;
        }

        if (debug) Log.d(TAG, "[PLUGIN DEBUG] Opening CustomWebViewActivity with URL: " + url);
        Intent intent = new Intent(getActivity(), CustomWebViewActivity.class);
        intent.putExtra(CustomWebViewActivity.EXTRA_URL, url);
        intent.putExtra("debug", debug);
        intent.putExtra(CustomWebViewActivity.EXTRA_ENABLE_COOKIES, enableCookies);
        intent.putExtra(CustomWebViewActivity.EXTRA_FULLSCREEN, call.getBoolean("fullscreen", false));
        getActivity().startActivity(intent);

        call.resolve();
    }
}
