# Example app — probar `capacitor-webview`

App Capacitor mínima que consume el plugin local (`"capacitor-webview": "file:.."`).

## Requisitos

- Node 20+
- Android Studio y/o Xcode
- En la raíz del repo: plugin compilado (`npm run build`)

## 1. Sincronizar plugin + app

Desde la **raíz del repo**:

```bash
npm run build
cd example-app
npm install
npm run build
npx cap sync
```

Cada vez que cambies código nativo o TS del plugin, repite `npm run build` en la raíz y `npx cap sync` aquí.

## 2. Ejecutar en dispositivo

```bash
# Android (emulador o USB)
npm run android

# iOS (simulador o dispositivo)
npm run ios
```

La pantalla inicial tiene un campo URL y el botón **Abrir WebView**.

## 3. Probar geolocalización

El WebView del plugin es **independiente** del WebView de Capacitor. La página cargada debe usar **HTTPS** y la **app host** (esta example-app) debe declarar permisos de ubicación.

### Permisos ya incluidos en esta app de prueba

- **Android** (`android/app/src/main/AndroidManifest.xml`): `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- **iOS** (`ios/App/App/Info.plist`): `NSLocationWhenInUseUsageDescription`

En apps reales, el integrador añade esos mismos permisos/claves en su proyecto.

### Opción A — test rápido (sin servidor local)

1. Abre la app en el dispositivo.
2. Pulsa **Preset: test público** (URL `https://browserleaks.com/geo`).
3. **Abrir WebView**.
4. Acepta el permiso de ubicación del sistema.
5. La página debe mostrar coordenadas. Si hace timeout ~12–15 s, el puente WebView ↔ nativo sigue fallando.

### Opción B — página de test propia (`geolocation-test.html`)

1. En otra terminal:

   ```bash
   cd example-app
   npm start
   ```

   Vite sirve HTTPS en `https://localhost:5173/geolocation-test.html`.

2. **Simulador iOS**: preset **test local** suele funcionar con `https://localhost:5173/...`.

3. **Emulador Android**: usa `https://10.0.2.2:5173/geolocation-test.html` (10.0.2.2 = tu máquina host).

4. **Dispositivo físico**: el WebView **no confía** en el certificado self-signed de Vite. Expón el servidor con túnel HTTPS:

   ```bash
   npx ngrok http 5173
   ```

   Copia la URL `https://….ngrok-free.dev/geolocation-test.html` en el campo URL y abre el WebView.

### Opción C — tu backend real

Pega la URL HTTPS de tu entorno (p. ej. ngrok + ruta del editor). Activa **enableCookies** si la web necesita sesión tras login/redirect.

## 4. Depurar

`openWebview` se llama con `debug: true`.

| Plataforma | Dónde mirar |
|------------|-------------|
| Android | Logcat, filtro `CustomWebViewActivity` o `WEBVIEW` |
| iOS | Consola de Xcode al ejecutar la app |

Señales útiles:

- `Location permission denied` — falta permiso en manifest/Info.plist o usuario denegó.
- `URL uses HTTP` — geolocation no funcionará.
- Timeout en la página — suele faltar `onGeolocationPermissionsShowPrompt` (Android) o delegado iOS 15+ (versión antigua del plugin).

## Scripts

| Comando | Descripción |
|---------|-------------|
| `npm start` | Vite dev server (HTTPS) + `geolocation-test.html` |
| `npm run build` | Genera `dist/` (shell + página de test) |
| `npm run android` | build + cap sync + run Android |
| `npm run ios` | build + cap sync + run iOS |
