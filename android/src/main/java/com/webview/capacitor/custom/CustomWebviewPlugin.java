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
    private CustomWebview implementation = new CustomWebview();

    public CustomWebviewPlugin() {
        super();
        Log.d(TAG, "[PLUGIN DEBUG] CustomWebviewPlugin initialized");
    }

    @PluginMethod
    public void openWebview(PluginCall call) {
        boolean debug = call.getBoolean("debug", false);
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
        getActivity().startActivity(intent);

        call.resolve();
    }
}
