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
    public void echo(PluginCall call) {
        Log.d(TAG, "[PLUGIN DEBUG] echo called");
        String value = call.getString("value");

        JSObject ret = new JSObject();
        ret.put("value", implementation.echo(value));
        call.resolve(ret);
    }

    @PluginMethod
    public void openWebview(PluginCall call) {
        Log.d(TAG, "[PLUGIN DEBUG] openWebview called");
        String url = call.getString("url");
        if (url == null || url.isEmpty()) {
            Log.e(TAG, "[PLUGIN ERROR] URL is required");
            call.reject("URL is required");
            return;
        }

        Log.d(TAG, "[PLUGIN DEBUG] Opening CustomWebViewActivity with URL: " + url);
        Intent intent = new Intent(getActivity(), CustomWebViewActivity.class);
        intent.putExtra(CustomWebViewActivity.EXTRA_URL, url);
        getActivity().startActivity(intent);

        call.resolve();
    }
}
