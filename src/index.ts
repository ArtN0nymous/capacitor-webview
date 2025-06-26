import { registerPlugin } from '@capacitor/core';

import type { CustomWebviewPlugin } from './definitions';

const CustomWebview = registerPlugin<CustomWebviewPlugin>('CustomWebview');

export * from './definitions';
export { CustomWebview };
