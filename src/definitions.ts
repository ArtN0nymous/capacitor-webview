import type { PluginListenerHandle } from '@capacitor/core';

export interface OpenWebviewOptions {
  url: string;
  debug?: boolean;
  /**
   * Enable persistent cookies and session storage (localStorage/sessionStorage).
   * When enabled, the webview shares the app's cookie jar and persists sessions
   * across opens. When disabled, the webview uses an isolated ephemeral session.
   * @default false
   */
  enableCookies?: boolean;
  /**
   * Immersive fullscreen: hides the status bar (iOS) or both the status and
   * navigation bars (Android). On Android, swipe from the screen edge to
   * reveal system bars temporarily.
   * @default false
   */
  fullscreen?: boolean;
}

export interface WebviewClosedEvent {
  /** Emitted when the native webview is dismissed. */
}

export interface CustomWebviewPlugin {
  openWebview(options: OpenWebviewOptions): Promise<void>;

  addListener(
    eventName: 'webviewClosed',
    listenerFunc: (event: WebviewClosedEvent) => void,
  ): Promise<PluginListenerHandle>;

  removeAllListeners(): Promise<void>;
}
