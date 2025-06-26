# Capacitor Custom Webview Plugin

A Capacitor plugin to open a custom native WebView with navigation controls, file upload, download support, and network monitoring for both Android and iOS.

---

## Features

- Open a native WebView from your Capacitor/Ionic app
- Navigation controls: Back, Forward, Reload, Close
- File upload (camera, gallery, files)
- File download (with download manager on Android, QuickLook on iOS)
- Network request monitoring (XHR/fetch logs)
- Fullscreen modal presentation

---

## Installation

```sh
npm install capacitor-custom-webview-plugin
npx cap sync
```

---

## Usage

```typescript
import { CustomWebview } from '@artn0nymous/capacitor-webview';

// Open a webview with a given URL
CustomWebview.openWebview({
  url: 'https://www.example.com'
});
```

---

## Android Setup

### 1. Declare Permissions (Optional)

**Only add the permissions you actually need.**  
For example, if your web content does not use the camera, microphone, or file upload, you do **not** need to declare those permissions.

Add the following permissions to your app's `android/app/src/main/AndroidManifest.xml` **only if your use case requires them**:

```xml
<!-- Required for all web content -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Only if you use file upload or camera/microphone in your webview -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

> **Note:**  
> If you target Android 13+ (API 33+), you may need to request permissions at runtime for file/camera/microphone access.

### 2. Activity Declaration

If not already present, ensure the following activity is declared in your `AndroidManifest.xml`:

```xml
<activity
    android:name="com.webview.capacitor.custom.CustomWebViewActivity"
    android:theme="@style/Theme.MaterialComponents.DayNight.NoActionBar" />
```

---

## iOS Setup

### 1. Declare Permissions (Optional)

**Only add the Info.plist keys you actually need.**  
For example, if your web content does not use the camera, microphone, or file upload, you do **not** need to declare those keys.

Add the following keys to your app's `ios/App/App/Info.plist` **only if your use case requires them**:

```xml
<!-- Required only if your webview uses camera -->
<key>NSCameraUsageDescription</key>
<string>Camera access is required for file uploads and video calls.</string>
<!-- Required only if your webview uses microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for video calls.</string>
<!-- Required only if your webview uses photo library/file upload -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required for file uploads.</string>
```

---

## Permissions Summary

| Feature         | Android Permission(s)                        | iOS Info.plist Key(s)                  |
|-----------------|---------------------------------------------|----------------------------------------|
| WebView         | INTERNET                                    | (none)                                 |
| File Upload     | CAMERA, RECORD_AUDIO, READ/WRITE_EXTERNAL   | NSCameraUsageDescription, NSPhotoLibraryUsageDescription |
| File Download   | READ/WRITE_EXTERNAL_STORAGE                 | (none, handled by QuickLook)           |
| Microphone      | RECORD_AUDIO                                | NSMicrophoneUsageDescription           |

> **Only add the permissions relevant to your app's needs.**

---

## Example

```typescript
CustomWebview.openWebview({
  url: 'https://your-site.com'
});
```

---

## Notes

- The plugin opens a fullscreen modal WebView with navigation controls.
- Downloads on Android are saved to the public Downloads folder; on iOS, PDFs/images are previewed in-app.

---

## API

### `openWebview(options: { url: string }): Promise<void>`

Opens a native WebView with the specified URL.

#### Example

```typescript
await CustomWebview.openWebview({ url: 'https://www.example.com' });
```

---

## License

MIT
