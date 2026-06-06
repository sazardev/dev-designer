#!/usr/bin/env node

/**
 * Route Analyzer - Detects abandoned/orphaned routes
 *
 * Scans all pages in src/pages/ and all internal links across the codebase.
 * Reports routes that have zero internal links pointing to them (orphans).
 */

import { readdirSync, readFileSync } from "node:fs";
import { join, relative, extname } from "node:path";

const SRC_DIR = join(import.meta.dirname, "..", "src");
const PAGES_DIR = join(SRC_DIR, "pages");


const LINK_REGEX = /href=["']([^"'#]+)["']/g;
const TEMPLATE_LINK_REGEX = /href=\{`([^`]+)`\}/g;

const DYNAMIC_SEGMENTS = /\[.*?\]/g;

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

function extractLinks(content) {
  const links = new Set();

  // Literal href="..." links
  let match;
  const literalRegex = new RegExp(LINK_REGEX.source, "g");
  while ((match = literalRegex.exec(content)) !== null) {
    links.add(match[1]);
  }

  // Template literal href={`...`} links - extract route segments
  const templateRegex = new RegExp(TEMPLATE_LINK_REGEX.source, "g");
  while ((match = templateRegex.exec(content)) !== null) {
    const template = match[1];
    // Extract segments that look like route parts (not variable interpolation)
    const segments = template.split("/").filter((s) => s && !s.startsWith("${"));
    if (segments.length > 0) {
      links.add("/" + segments.join("/"));
    }
  }

  return links;
}

function fileToRoute(filePath) {
  const rel = relative(PAGES_DIR, filePath);
  let route = "/" + rel.replace(/\.(astro|md|mdx)$/, "").replace(/\/index$/, "/");
  route = route.replace(/\/?$/, "/");
  return route;
}

function normalizeRoute(route) {
  return route.replace(/\/$/, "") || "/";
}

function collectAllInternalLinks() {
  const allLinks = new Set();
  const sourceFiles = getAllFiles(SRC_DIR, [".astro", ".ts", ".tsx", ".md", ".mdx"]);

  for (const file of sourceFiles) {
    const content = readFileSync(file, "utf-8");
    for (const link of extractLinks(content)) {
      if (link.startsWith("/") && !link.startsWith("//")) {
        allLinks.add(normalizeRoute(link));
      }
    }
  }

  return allLinks;
}

function collectAllRoutes() {
  const routes = new Map();
  const pageFiles = getAllFiles(PAGES_DIR, [".astro", ".md", ".mdx"]);

  for (const file of pageFiles) {
    const route = normalizeRoute(fileToRoute(file));
    const isDynamic = DYNAMIC_SEGMENTS.test(route);
    routes.set(route, { file, isDynamic });
  }

  return routes;
}

function main() {
  console.log("🔍 Route Analyzer - Scanning for orphaned routes...\n");

  const internalLinks = collectAllInternalLinks();
  const routes = collectAllRoutes();

  console.log(`📄 Found ${routes.size} routes in src/pages/`);
  console.log(`🔗 Found ${internalLinks.size} unique internal links across codebase\n`);

  const orphans = [];
  const linked = [];

  for (const [route, info] of routes) {
    if (info.isDynamic) {
      continue;
    }

    const matched = [...internalLinks].some((link) => {
      const normalized = normalizeRoute(link);
      if (normalized === route || normalized === route.replace(/\/$/, "")) return true;
      // Check if the link segment matches the route's last segment
      const routeSegments = route.split("/").filter(Boolean);
      const linkSegments = normalized.split("/").filter(Boolean);
      const lastRouteSeg = routeSegments[routeSegments.length - 1];
      const lastLinkSeg = linkSegments[linkSegments.length - 1];
      return lastRouteSeg && lastLinkSeg && lastRouteSeg === lastLinkSeg;
    });

    if (matched) {
      linked.push(route);
    } else {
      orphans.push({ route, file: info.file });
    }
  }

  if (orphans.length === 0) {
    console.log("✅ No orphaned routes found! All routes have internal links.\n");
  } else {
    console.log(`⚠️  Found ${orphans.length} orphaned route(s):\n`);
    for (const { route, file } of orphans) {
      const relFile = relative(process.cwd(), file);
      console.log(`  ❌ ${route}`);
      console.log(`     └─ ${relFile}`);
    }
    console.log("");
  }

  console.log(`📊 Summary: ${linked.length} linked, ${orphans.length} orphaned\n`);

  if (orphans.length > 0) {
    process.exit(1);
  }
}

main();
