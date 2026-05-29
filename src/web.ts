import { WebPlugin } from '@capacitor/core';

import type { CustomWebviewPlugin, OpenWebviewOptions } from './definitions';

export class CustomWebviewWeb extends WebPlugin implements CustomWebviewPlugin {
  async openWebview(_options: OpenWebviewOptions): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }
}
