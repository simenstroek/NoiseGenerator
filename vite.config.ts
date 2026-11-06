import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// https://vitejs.dev/config/
export default defineConfig(() => ({
    base: './', // relative paths so it works under a GitHub Pages subpath
    plugins: [vue()],
    resolve: {
        alias: {
            "@": new URL("./src", import.meta.url).pathname,
        },
    },
}));
