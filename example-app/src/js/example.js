import { CustomWebview } from 'capacitor-webview';

let closeListener = null;

window.openTestWebview = async () => {
  const urlInput = document.getElementById('urlInput');
  const status = document.getElementById('status');
  const url = urlInput?.value?.trim() || 'https://example.com';
  const enableCookies = document.getElementById('enableCookies')?.checked ?? false;

  try {
    if (closeListener) {
      await closeListener.remove();
      closeListener = null;
    }

    closeListener = await CustomWebview.addListener('webviewClosed', () => {
      status.textContent = 'WebView cerrado — listener ejecutado';
    });

    status.textContent = 'Abriendo webview...';
    await CustomWebview.openWebview({
      url,
      debug: true,
      enableCookies,
    });
    status.textContent = 'WebView abierto';
  } catch (err) {
    status.textContent = `Error: ${err.message ?? err}`;
    console.error(err);
  }
};
