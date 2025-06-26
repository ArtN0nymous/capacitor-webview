export interface CustomWebviewPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  openWebview(options: { url: string }): Promise<void>;
}
