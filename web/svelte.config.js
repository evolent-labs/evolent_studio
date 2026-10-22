import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

export default {
  preprocess: vitePreprocess(),
  compilerOptions: {
    runes: true,
    warningFilter: (warning) => warning.code !== 'a11y_no_static_element_interactions',
  },
};
