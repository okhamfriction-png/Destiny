import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [sveltekit()],
	// Tauri affiche ses propres erreurs Rust : on ne vide pas le terminal.
	clearScreen: false,
	server: {
		port: 1420,
		strictPort: true,
		watch: { ignored: ['**/src-tauri/**', '**/target/**', '**/crates/**'] },
		// examples/ est servi au mock (import JSON) ; rien d'autre hors de studio/.
		fs: { allow: ['examples'] }
	},
	test: {
		include: ['src/**/*.test.ts'],
		environment: 'node'
	}
});
