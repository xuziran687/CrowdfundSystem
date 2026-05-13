import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0', // 允许局域网访问
    port: 5173,      // 指定端口（可选，默认为 5173）
    watch: {
      usePolling: true,       // 启用轮询监听，解决 Docker/WSL 下 HMR 不生效
      interval: 100,          // 轮询间隔(ms)
    },
  },
})
