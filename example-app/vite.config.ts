import { defineConfig } from 'vite';
import basicSsl from '@vitejs/plugin-basic-ssl';

export default defineConfig({
  root: './src',
  plugins: [basicSsl()],
  server: {
    host: true,
    port: 5173,
  },
  build: {
    outDir: '../dist',
    minify: false,
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: './src/index.html',
        geolocationTest: './src/geolocation-test.html',
      },
    },
  },
});
