#!/usr/bin/env node

/**
 * Link Checker - Detects broken internal links in built HTML output
 *
 * Scans dist/ for all HTML files, extracts internal links,
 * and verifies they resolve to existing pages.
 */

import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join, relative } from "node:path";

const DIST_DIR = join(import.meta.dirname, "..", "dist");

const INTERNAL_LINK_REGEX = /href=["'](\/[^"'#?]+)(?:\?[^"']*)?(?:#[^"']*)?["']/g;


function getAllFiles(dir, extensions) {
  const files = [];
  try {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        files.push(...getAllFiles(fullPath, extensions));
      } else if (extensions.includes(extname(entry.name))) {
        files.push(fullPath);
      }
    }
  } catch {}
  return files;
}

function extname(p) {
  const idx = p.lastIndexOf(".");
  return idx !== -1 ? p.slice(idx) : "";
}

function main() {
  console.log("🔗 Link Checker - Scanning for broken links...\n");

  if (!existsSync(DIST_DIR)) {
    console.log("❌ dist/ directory not found. Run 'npm run build' first.\n");
    process.exit(1);
  }

  const htmlFiles = getAllFiles(DIST_DIR, [".html"]);
  const brokenLinks = [];
  const allLinks = new Set();

  for (const file of htmlFiles) {
    const content = readFileSync(file, "utf-8");
    const htmlPath = relative(DIST_DIR, file);

    let match;
    while ((match = INTERNAL_LINK_REGEX.exec(content)) !== null) {
      const link = match[1];
      if (link.includes("/undefined")) continue;
      allLinks.add(link);

      const targetPath = join(DIST_DIR, link === "/" ? "index.html" : link);

      const existsAsFile = existsSync(targetPath);
      const existsAsDir = existsSync(join(targetPath, "index.html"));

      if (!existsAsFile && !existsAsDir) {
        brokenLinks.push({
          source: htmlPath,
          link,
          reason: "Target not found in dist/",
        });
      }
    }

    INTERNAL_LINK_REGEX.lastIndex = 0;
  }

  console.log(`📄 Scanned ${htmlFiles.length} HTML files`);
  console.log(`🔗 Found ${allLinks.size} unique internal links\n`);

  if (brokenLinks.length === 0) {
    console.log("✅ No broken links found!\n");
  } else {
    console.log(`❌ Found ${brokenLinks.length} broken link(s):\n`);
    for (const { source, link, reason } of brokenLinks) {
      console.log(`  ❌ ${link}`);
      console.log(`     Source: ${source}`);
      console.log(`     Reason: ${reason}`);
    }
    console.log("");
  }

  console.log(`📊 Summary: ${allLinks.size} links checked, ${brokenLinks.length} broken\n`);

  if (brokenLinks.length > 0) {
    process.exit(1);
  }
}

main();
