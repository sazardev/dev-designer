# AGENTS.md — dev-designer

## Project

Astro 6.x bilingual blog (es/en) at `https://dev-design.dev`. Content collections: `blog` (MDX) and `authors` (MD). Uses Nothing Design System (CSS custom properties, dark/light themes).

## Commands

```bash
npm run dev          # Dev server at localhost:4321
npm run build        # Build to dist/
make audit           # Full check chain: type → lint → format → knip → routes → build → links
make fix             # lint:fix + format
npm run check        # Astro type check (TypeScript strict)
npm run lint         # ESLint
npm run format       # Prettier write
```

### Verification order

`check` → `lint` → `format:check` → `knip` → `check:routes` → `build` → `check:links`

`check:links` requires a prior `build` (scans `dist/`).

## i18n

- Default locale: `es`. Routes use prefix: `/es/blog/...`, `/en/blog/...`.
- Blog posts: `src/content/blog/{es,en}/` — must use **same slug** in both dirs.
- Authors: `src/content/authors/{es,en}/` — same slug requirement.
- Locale in frontmatter **must match** directory (`es` in `blog/es/`, `en` in `blog/en/`).
- Translations: `src/i18n/ui.ts`. Use `useTranslations(locale)` for UI strings.
- Route generation: `src/pages/{locale}/blog/[...slug].astro` uses `post.id.replace("es/", "")` to strip locale prefix.

## Content

### Blog post frontmatter (all required)

```yaml
title: string
description: string
pubDate: date
locale: "es" | "en"
author: string  # must match a slug in src/content/authors/{locale}/
tags: string[]
category: "design-patterns" | "architecture" | "frontend" | "backend" | "devops" | "tips" | "tutorial"
```

Optional: `difficulty` ("beginner" | "intermediate" | "advanced"), `featured`, `relatedPosts`, `draft`, `heroImage`, `updatedDate`.

### Valid categories

Defined in `src/consts.ts` → `CATEGORIES` and `src/i18n/ui.ts` → `categories`. If adding a new category, update both files and `src/content.config.ts` schema.

## Code style

- **Prettier**: double quotes, trailing commas, `printWidth: 100`, semicolons, LF line endings.
- **ESLint**: sorted attributes (alphabetical, case-insensitive), `class:list` directive preferred, `consistent-type-imports` enforced.
- **TypeScript**: strict null checks, no unchecked indexed access, no unused locals/params. Prefix unused vars with `_`.
- **Astro**: `set:html` directive banned (`astro/no-set-html-directive: error`). Semicolons in `.astro` files enforced.

## Git hooks (Husky)

- **pre-commit**: `lint-staged` (eslint --fix + prettier) + `check-routes.sh`
- **pre-push**: eslint (max-warnings=0), prettier check, astro check, check-routes.sh, check-links.sh
- **commit-msg**: commitlint — conventional commits only (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`)

## Gotchas

- `src/pages/index.astro` redirects to `/es/blog` via `window.location.href` (not Astro redirect).
- `check-links.sh` fails if `dist/` doesn't exist — always `npm run build` first.
- `check-routes.sh` runs in pre-commit; it detects undefined hrefs, double-locale URLs, broken links.
- Adding a new blog post requires a translation in the other locale directory to avoid warnings.
- `relatedPosts` uses slugs (not full paths) — must exist in `ALL_SLUGS` across both locales.
- Images: use `<Image>` from `astro:assets`, not raw `<img>`. Hero images go in `src/assets/`.
- `astro-mermaid` diagrams use `securityLevel: "loose"` — avoid in untrusted content.
- Knip ignores `sharp`, `astro-pagefind`, `astro-eslint-parser`, `eslint-plugin-jsx-a11y` as false positives.

## Key files

- `src/consts.ts` — site metadata, categories, difficulty levels
- `src/i18n/ui.ts` — all UI translations
- `src/content.config.ts` — collection schemas (blog + authors)
- `scripts/check-routes.sh` — aggressive route validation (10 checks)
- `scripts/check-links.sh` — full audit: orphan routes, broken links, i18n consistency, frontmatter validation
- `Makefile` — all automation commands
