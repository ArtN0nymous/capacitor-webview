import { CustomWebview } from 'capacitor-webview';

let closeListener = null;

const PRESETS = {
  public: 'https://browserleaks.com/geo',
  local: 'https://localhost:5173/geolocation-test.html',
};

window.setPreset = (name) => {
  const urlInput = document.getElementById('urlInput');
  const status = document.getElementById('status');
  const preset = PRESETS[name];

  if (!preset || !urlInput) {
    return;
  }

  urlInput.value = preset;

  if (name === 'local') {
    status.textContent =
      'Preset local: ejecuta "npm start" en example-app y usa ngrok si pruebas en dispositivo físico (WebView no confía en cert self-signed).';
  } else {
    status.textContent = 'Preset público listo — abre el WebView y acepta permiso de ubicación.';
  }
};

window.openTestWebview = async () => {
  const urlInput = document.getElementById('urlInput');
  const status = document.getElementById('status');
  const url = urlInput?.value?.trim() || PRESETS.public;
  const enableCookies = document.getElementById('enableCookies')?.checked ?? false;

  if (url.startsWith('http://')) {
    status.textContent =
      'Advertencia: HTTP no es contexto seguro — geolocation fallará. Usa HTTPS.';
  }

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
    status.textContent = 'WebView abierto — revisa permisos de ubicación en el dispositivo';
  } catch (err) {
    status.textContent = `Error: ${err.message ?? err}`;
    console.error(err);
  }
};
