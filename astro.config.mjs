// @ts-check

import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import mermaid from "astro-mermaid";
import pagefind from "astro-pagefind";
import { defineConfig } from "astro/config";

// https://astro.build/config
export default defineConfig({
  site: "https://dev-design.dev",
  i18n: {
    defaultLocale: "es",
    locales: ["es", "en"],
    routing: {
      prefixDefaultLocale: true,
    },
  },
  integrations: [
    mdx(),
    mermaid({
      theme: "default",
      autoTheme: true,
      mermaidConfig: {
        securityLevel: "loose",
      },
    }),
    pagefind(),
    sitemap(),
  ],
});
