export interface CustomWebviewPlugin {
  openWebview(options: { url: string }): Promise<void>;
}
