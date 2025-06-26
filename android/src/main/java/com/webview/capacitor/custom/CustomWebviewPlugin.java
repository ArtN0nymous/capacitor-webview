package com.webview.capacitor.custom;

import android.content.Intent;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CustomWebview")
public class CustomWebviewPlugin extends Plugin {

    private CustomWebview implementation = new CustomWebview();

    @PluginMethod
    public void echo(PluginCall call) {
        String value = call.getString("value");

        JSObject ret = new JSObject();
        ret.put("value", implementation.echo(value));
        call.resolve(ret);
    }

    @PluginMethod
    public void openWebview(PluginCall call) {
        String url = call.getString("url");
        String iconColor = call.getString("iconColor", "#000000");
        if (url == null || url.isEmpty()) {
            call.reject("URL is required");
            return;
        }

        Intent intent = new Intent(getActivity(), CustomWebViewActivity.class);
        intent.putExtra(CustomWebViewActivity.EXTRA_URL, url);
        intent.putExtra("iconColor", iconColor);
        getActivity().startActivity(intent);

        call.resolve();
    }
}
