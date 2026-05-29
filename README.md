# Capacitor Custom Webview Plugin

A Capacitor 7 plugin to open a custom native WebView with navigation controls, file upload, PDF/image download, optional cookies and sessions, close events, and debug network logging for Android and iOS.

---

## Features

- Open a native WebView from your Capacitor/Ionic app
- Navigation controls: Back, Forward, Reload, Close
- **Close listener** (`webviewClosed`) when the user dismisses the webview
- **Optional cookies and sessions** (`enableCookies`) for login, OAuth, and authenticated flows
- **PDF download** by URL, `Content-Type`, or `Content-Disposition` (not limited to specific paths)
- Image download and in-app preview (iOS QuickLook)
- File upload (camera, gallery, files) on Android
- Network request monitoring when `debug` is enabled (XHR/fetch logs)
- Fullscreen modal presentation (iOS) / dedicated activity (Android)

---

## Installation

```sh
npm install @artn0nymous/capacitor-webview
npx cap sync
```

**Requirements:** Capacitor 7+, JDK 21 for Android builds.

---

## Usage

```typescript
import { CustomWebview } from '@artn0nymous/capacitor-webview';

// Register the close listener before opening the webview
const closeListener = await CustomWebview.addListener('webviewClosed', () => {
  console.log('WebView closed');
  // Refresh app state, navigate, etc.
});

await CustomWebview.openWebview({
  url: 'https://www.example.com',
  debug: true,           // optional: native network/event logs
  enableCookies: true,   // optional: persistent cookies & session (login/OAuth)
});

// Optional: remove listener when no longer needed
await closeListener.remove();
```

### Login or OAuth flows

Enable cookies so redirects can set session cookies and later requests stay authenticated:

```typescript
await CustomWebview.openWebview({
  url: 'https://your-api.com/auth/start',
  enableCookies: true,
});
```

When `enableCookies` is `false` (default), the webview uses an isolated session (iOS non-persistent store; Android without third-party cookies / DOM storage).

---

## API

### `openWebview(options): Promise<void>`

Opens the native WebView.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | `string` | — | **Required.** URL to load. |
| `debug` | `boolean` | `false` | Enables native logging of navigation and network events. |
| `enableCookies` | `boolean` | `false` | Enables persistent cookies, shared cookie jar, and session storage. Use for login/OAuth. |

### `addListener('webviewClosed', listener): Promise<PluginListenerHandle>`

Fired when the webview is closed (close button or dismiss). Register **before** calling `openWebview`.

### `removeAllListeners(): Promise<void>`

Removes all plugin listeners.

---

## PDF and file downloads

The plugin intercepts PDFs when:

- The URL ends with `.pdf` or includes a PDF filename in query params (`filename`, `file`, `name`, `download`)
- The server responds with `Content-Type: application/pdf`
- The response includes `Content-Disposition` with a `.pdf` filename

- **iOS:** downloads with session cookies, validates PDF content, opens QuickLook preview
- **Android:** uses the system Download Manager (saved to Downloads)

---

## Android setup

### Permissions (optional)

Add only what your web content needs in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />

<!-- File upload / camera / microphone only if required -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Activity declaration

The plugin registers `CustomWebViewActivity` in its own manifest. If you use a custom manifest merge, ensure this activity is available:

```xml
<activity
    android:name="com.webview.capacitor.custom.CustomWebViewActivity"
    android:exported="false"
    android:theme="@style/Theme.MaterialComponents.DayNight.NoActionBar" />
```

---

## iOS setup

### Info.plist (optional)

Add only the keys your web content needs in `ios/App/App/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for file uploads and video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for video calls.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required for file uploads.</string>
```

---

## Permissions summary

| Feature | Android | iOS |
|---------|---------|-----|
| WebView | `INTERNET` | — |
| File upload | `CAMERA`, `RECORD_AUDIO`, storage | Camera / mic / photo library usage descriptions |
| File download | Storage (Downloads folder) | QuickLook (in-app) |
| Cookies / session | `enableCookies: true` | `enableCookies: true` |

---

## Changelog

### 1.1.0

- `webviewClosed` listener when the webview is dismissed
- `enableCookies` option for sessions and OAuth
- Generic PDF detection (URL, `Content-Type`, `Content-Disposition`)
- iOS: `CapacitorWebview.podspec` naming fix
- Android: toolbar icon visibility fix

### 1.0.7

- Initial public release

---

## License

MIT
