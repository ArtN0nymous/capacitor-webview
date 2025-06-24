import { CustomWebview } from 'capacitor-webview';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    CustomWebview.echo({ value: inputValue })
}
