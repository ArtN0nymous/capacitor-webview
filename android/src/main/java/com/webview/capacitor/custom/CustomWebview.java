package com.webview.capacitor.custom;

import android.util.Log;

public class CustomWebview {

    public String echo(String value) {
        Log.i("Echo", value);
        return value;
    }
}
