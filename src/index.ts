import { registerPlugin } from '@capacitor/core';

import type { CustomWebviewPlugin } from './definitions';

const CustomWebview = registerPlugin<CustomWebviewPlugin>('CustomWebview', {
  web: () => import('./web').then((m) => new m.CustomWebviewWeb()),
});

export * from './definitions';
export { CustomWebview };
