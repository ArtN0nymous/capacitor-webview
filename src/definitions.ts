export interface CustomWebviewPlugin {
  openWebview(options: { url: string, debug?: boolean }): Promise<void>;
}
