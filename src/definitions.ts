export interface CustomWebviewPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
