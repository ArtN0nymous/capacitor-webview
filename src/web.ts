import { WebPlugin } from '@capacitor/core';

import type { CustomWebviewPlugin } from './definitions';

export class CustomWebviewWeb extends WebPlugin implements CustomWebviewPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
