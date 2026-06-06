#!/usr/bin/env bash
# ============================================================================
# check-links.sh — Buscador agresivo de problemas en Astro Blog
# ============================================================================
# Ejecuta una auditoría completa del proyecto buscando:
#   1. Rutas huérfanas (páginas sin contenido asociado)
#   2. Links rotos internos en archivos MDX
#   3. Authors inválidos en posts
#   4. Imágenes huérfanas (sin referenciar)
#   5. Slugs de relatedPosts inexistentes
#   6. Consistencia i18n (posts sin par en otro idioma)
#   7. Frontmatter incompleto
#   8. Imports de componentes rotos
#   9. Posts en draft
#  10. CSS selectors huérfanos
#  11. Categorías/tag inválidos
#  12. URLs de assets rotas
# ============================================================================
set -euo pipefail

# Colores
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
CHECKS_PASSED=0

error() { echo -e "${RED}✖ ERROR:${NC} $1"; ((ERRORS++)) || true; }
warn() { echo -e "${YELLOW}✖ WARN:${NC} $1"; ((WARNINGS++)) || true; }
pass() { echo -e "${GREEN}✔ PASS:${NC} $1"; ((CHECKS_PASSED++)) || true; }
section() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }

# ============================================================================
# 1. ROUTES VS CONTENT — Detectar páginas huérfanas
# ============================================================================
section "1. ROUTES VS CONTENT (Páginas Huérfanas)"

BLOG_SLUGS_ES=()
BLOG_SLUGS_EN=()
for f in src/content/blog/es/*.mdx src/content/blog/es/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')
	BLOG_SLUGS_ES+=("$slug")
done
for f in src/content/blog/en/*.mdx src/content/blog/en/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')
	BLOG_SLUGS_EN+=("$slug")
done

for slug in "${BLOG_SLUGS_ES[@]}"; do
	if [ ! -f "src/pages/es/blog/${slug}.astro" ] && [ ! -f "src/pages/es/blog/[...slug].astro" ]; then
		error "Blog post 'es/${slug}' no tiene página asociada en src/pages/es/blog/"
	fi
done
for slug in "${BLOG_SLUGS_EN[@]}"; do
	if [ ! -f "src/pages/en/blog/${slug}.astro" ] && [ ! -f "src/pages/en/blog/[...slug].astro" ]; then
		error "Blog post 'en/${slug}' no tiene página asociada en src/pages/en/blog/"
	fi
done

for locale in es en; do
	for page in index about; do
		if [ ! -f "src/pages/${locale}/${page}.astro" ]; then
			warn "Página estática '${locale}/${page}' no existe"
		fi
	done
done

pass "Análisis de rutas completado (${#BLOG_SLUGS_ES[@]} posts ES, ${#BLOG_SLUGS_EN[@]} posts EN)"

# ============================================================================
# 2. BROKEN INTERNAL LINKS — Links rotos en MDX
# ============================================================================
section "2. BROKEN INTERNAL LINKS (Links Rotos en MDX)"

BROKEN_LINK_COUNT=0
MD_LINK_RE='\[([^\]]*)\]\(([^)]+)\)'
for f in src/content/blog/**/*.mdx src/content/blog/**/*.md; do
	[ -f "$f" ] || continue
	while IFS= read -r line; do
		while [[ "$line" =~ $MD_LINK_RE ]]; do
			link_text="${BASH_REMATCH[1]}"
			link_url="${BASH_REMATCH[2]}"

			if [[ ! "$link_url" =~ ^https?:// ]] && [[ ! "$link_url" =~ ^mailto: ]] && [[ ! "$link_url" =~ ^# ]]; then
				clean_url=$(echo "$link_url" | sed 's/#.*//')
				clean_url=$(echo "$clean_url" | sed 's/?.*//')

				dir=$(dirname "$f")
				resolved="${dir}/${clean_url}"

				if [ ! -f "$resolved" ] && [ ! -d "$resolved" ]; then
					error "Link roto en '$f': [${link_text}](${link_url}) → ${resolved}"
					((BROKEN_LINK_COUNT++)) || true
				fi
			fi

			line="${line#*"${BASH_REMATCH[0]}"}"
		done
	done < "$f"
done

if [ "$BROKEN_LINK_COUNT" -eq 0 ]; then
	pass "No se encontraron links internos rotos en MDX"
else
	error "Se encontraron ${BROKEN_LINK_COUNT} links internos rotos"
fi

# ============================================================================
# 3. INVALID AUTHORS — Authors referenciados que no existen
# ============================================================================
section "3. INVALID AUTHORS (Authors Inválidos)"

EXISTING_AUTHORS=()
for f in src/content/authors/es/*.md src/content/authors/en/*.md; do
	[ -f "$f" ] || continue
	author_slug=$(basename "$f" | sed 's/\.md$//')
	EXISTING_AUTHORS+=("$author_slug")
done

INVALID_AUTHORS=0
for f in src/content/blog/**/*.mdx src/content/blog/**/*.md; do
	[ -f "$f" ] || continue
	author=$(grep -m1 '^author:' "$f" 2>/dev/null | sed 's/^author:[[:space:]]*//' | tr -d "'\"" || true)
	if [ -n "$author" ]; then
		found=false
		for ea in "${EXISTING_AUTHORS[@]}"; do
			if [ "$ea" = "$author" ]; then
				found=true
				break
			fi
		done
		if [ "$found" = false ]; then
			error "Author inválido en '$f': '${author}' (existentes: ${EXISTING_AUTHORS[*]})"
			((INVALID_AUTHORS++)) || true
		fi
	fi
done

if [ "$INVALID_AUTHORS" -eq 0 ]; then
	pass "Todos los authors referenciados son válidos"
fi

# ============================================================================
# 4. ORPHAN IMAGES — Imágenes sin referenciar
# ============================================================================
section "4. ORPHAN IMAGES (Imágenes Huérfanas)"

ORPHAN_IMAGES=0
while IFS= read -r img; do
	[ -f "$img" ] || continue
	img_name=$(basename "$img")
	if ! grep -rq "$img_name" src/ --include='*.astro' --include='*.ts' --include='*.tsx' --include='*.mdx' --include='*.md' --include='*.css' 2>/dev/null; then
		warn "Imagen huérfana: '$img' no referenciada en ningún archivo"
		((ORPHAN_IMAGES++)) || true
	fi
done < <(find src/assets -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.svg" -o -name "*.gif" -o -name "*.webp" \) 2>/dev/null)

if [ "$ORPHAN_IMAGES" -eq 0 ]; then
	pass "Todas las imágenes están siendo utilizadas"
else
	warn "${ORPHAN_IMAGES} imágenes huérfanas encontradas"
fi

# ============================================================================
# 5. BROKEN RELATED POSTS — Slugs de relatedPosts inexistentes
# ============================================================================
section "5. BROKEN RELATED POSTS (Slugs Rotos)"

BROKEN_RELATED=0
ALL_SLUGS=()
for f in src/content/blog/es/*.mdx src/content/blog/es/*.md src/content/blog/en/*.mdx src/content/blog/en/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')
	ALL_SLUGS+=("$slug")
done

for f in src/content/blog/**/*.mdx src/content/blog/**/*.md; do
	[ -f "$f" ] || continue
	in_related=false
	while IFS= read -r line; do
		if [[ "$line" =~ ^relatedPosts: ]]; then
			in_related=true
			if [[ "$line" =~ \[.*\] ]]; then
				items=$(echo "$line" | sed 's/relatedPosts:[[:space:]]*\[//' | sed 's/\].*//' | tr ',' '\n' | tr -d "'\" ")
				for item in $items; do
					[ -z "$item" ] && continue
					found=false
					for slug in "${ALL_SLUGS[@]}"; do
						if [ "$slug" = "$item" ]; then
							found=true
							break
						fi
					done
					if [ "$found" = false ]; then
						error "relatedPosts roto en '$f': '${item}' no existe"
						((BROKEN_RELATED++)) || true
					fi
				done
				in_related=false
			fi
			continue
		fi
		if [ "$in_related" = true ]; then
			if [[ "$line" =~ ^\- ]]; then
				item=$(echo "$line" | sed 's/^-[[:space:]]*//' | tr -d "'\" ")
				found=false
				for slug in "${ALL_SLUGS[@]}"; do
					if [ "$slug" = "$item" ]; then
						found=true
						break
					fi
				done
				if [ "$found" = false ]; then
					error "relatedPosts roto en '$f': '${item}' no existe"
					((BROKEN_RELATED++)) || true
				fi
			elif [[ "$line" =~ ^[a-zA-Z] ]]; then
				in_related=false
			fi
		fi
	done < "$f"
done

if [ "$BROKEN_RELATED" -eq 0 ]; then
	pass "Todos los relatedPosts apuntan a slugs válidos"
fi

# ============================================================================
# 6. I18N CONSISTENCY — Posts sin par en otro idioma
# ============================================================================
section "6. I18N CONSISTENCY (Consistencia de Idiomas)"

for f in src/content/blog/es/*.mdx src/content/blog/es/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')
	if [ ! -f "src/content/blog/en/${slug}.mdx" ] && [ ! -f "src/content/blog/en/${slug}.md" ]; then
		warn "Post ES '${slug}' no tiene variante en EN"
	fi
done

for f in src/content/blog/en/*.mdx src/content/blog/en/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')
	if [ ! -f "src/content/blog/es/${slug}.mdx" ] && [ ! -f "src/content/blog/es/${slug}.md" ]; then
		warn "Post EN '${slug}' no tiene variante en ES"
	fi
done

for f in src/content/authors/es/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.md$//')
	if [ ! -f "src/content/authors/en/${slug}.md" ]; then
		warn "Author ES '${slug}' no tiene variante en EN"
	fi
done

for f in src/content/authors/en/*.md; do
	[ -f "$f" ] || continue
	slug=$(basename "$f" | sed 's/\.md$//')
	if [ ! -f "src/content/authors/es/${slug}.md" ]; then
		warn "Author EN '${slug}' no tiene variante en ES"
	fi
done

pass "Análisis de consistencia i18n completado"

# ============================================================================
# 7. FRONTMATTER VALIDATION — Campos requeridos faltantes
# ============================================================================
section "7. FRONTMATTER VALIDATION (Campos Requeridos)"

REQUIRED_BLOG_FIELDS=("title" "description" "pubDate" "locale" "author" "tags" "category")
REQUIRED_AUTHOR_FIELDS=("name" "avatar" "locale")
MISSING_FIELDS=0

for f in src/content/blog/**/*.mdx src/content/blog/**/*.md; do
	[ -f "$f" ] || continue
	for field in "${REQUIRED_BLOG_FIELDS[@]}"; do
		if ! grep -q "^${field}:" "$f" 2>/dev/null; then
			error "Campo requerido '${field}' falta en '$f'"
			((MISSING_FIELDS++)) || true
		fi
	done
done

for f in src/content/authors/**/*.md; do
	[ -f "$f" ] || continue
	for field in "${REQUIRED_AUTHOR_FIELDS[@]}"; do
		if ! grep -q "^${field}:" "$f" 2>/dev/null; then
			error "Campo requerido '${field}' falta en '$f'"
			((MISSING_FIELDS++)) || true
		fi
	done
done

if [ "$MISSING_FIELDS" -eq 0 ]; then
	pass "Todos los campos requeridos están presentes"
fi

# ============================================================================
# 8. BROKEN COMPONENT IMPORTS — Imports de componentes rotos
# ============================================================================
section "8. BROKEN COMPONENT IMPORTS (Imports Rotos)"

BROKEN_IMPORTS=0
while IFS= read -r f; do
	[ -f "$f" ] || continue
	while IFS= read -r line; do
		if [[ "$line" =~ import.*from[[:space:]]+['\"](\..*?)['\"] ]]; then
			import_path="${BASH_REMATCH[1]}"
			dir=$(dirname "$f")
			resolved="${dir}/${import_path}"
			if [ ! -f "$resolved" ] && [ ! -f "${resolved}.ts" ] && [ ! -f "${resolved}.tsx" ] && [ ! -f "${resolved}.astro" ] && [ ! -f "${resolved}/index.ts" ] && [ ! -f "${resolved}/index.astro" ]; then
				error "Import roto en '$f': '${import_path}' no se puede resolver"
				((BROKEN_IMPORTS++)) || true
			fi
		fi
	done < "$f"
done < <(find src -name "*.astro" -type f 2>/dev/null)

if [ "$BROKEN_IMPORTS" -eq 0 ]; then
	pass "Todos los imports de componentes son válidos"
fi

# ============================================================================
# 9. DRAFT POSTS — Posts en draft
# ============================================================================
section "9. DRAFT POSTS (Posts en Borrador)"

DRAFT_COUNT=0
for f in src/content/blog/**/*.mdx src/content/blog/**/*.md; do
	[ -f "$f" ] || continue
	if grep -q '^draft: true' "$f" 2>/dev/null; then
		warn "Post en draft: '$f'"
		((DRAFT_COUNT++)) || true
	fi
done

if [ "$DRAFT_COUNT" -eq 0 ]; then
	pass "No hay posts en draft"
else
	warn "${DRAFT_COUNT} posts en draft encontrados"
fi

# ============================================================================
# 10. INVALID CATEGORIES — Categorías que no existen en CATEGORIES
# ============================================================================
section "10. INVALID CATEGORIES & TAGS (Categorías/Tags Inválidos)"

VALID_CATEGORIES=("design-patterns" "architecture" "frontend" "backend" "devops" "tips" "tutorial")
INVALID_CATS=0

for f in src/content/blog/**/*.mdx src/content/blog/**/*.md; do
	[ -f "$f" ] || continue
	cat=$(grep -m1 '^category:' "$f" 2>/dev/null | sed 's/^category:[[:space:]]*//' | tr -d "'\"" || true)
	if [ -n "$cat" ]; then
		found=false
		for vc in "${VALID_CATEGORIES[@]}"; do
			if [ "$vc" = "$cat" ]; then
				found=true
				break
			fi
		done
		if [ "$found" = false ]; then
			error "Categoría inválida '${cat}' en '$f' (válidas: ${VALID_CATEGORIES[*]})"
			((INVALID_CATS++)) || true
		fi
	fi
done

if [ "$INVALID_CATS" -eq 0 ]; then
	pass "Todas las categorías son válidas"
fi

# ============================================================================
# 11. CSS SELECTORS EN COMPONENTES — Verificar selectores CSS usados
# ============================================================================
section "11. CSS CLASS USAGE (Clases CSS Huérfanas)"

CSS_WARNINGS=0
JS_PATTERNS="addEventListener|querySelector|getElementById|classList|setAttribute|getItem|setItem|preventDefault|toLocaleDateString|getFullYear|openSearch|innerHTML|outerHTML|textContent|appendChild|removeChild|insertBefore|replaceChild|dispatchEvent|removeEventListener"

while IFS= read -r f; do
	[ -f "$f" ] || continue
	# Extraer solo el bloque <style> del archivo
	in_style=false
	style_content=""
	while IFS= read -r line; do
		if [[ "$line" =~ \<style\> ]]; then
			in_style=true
			continue
		fi
		if [[ "$line" =~ \</style\> ]]; then
			in_style=false
			continue
		fi
		if [ "$in_style" = true ]; then
			style_content+="$line"$'\n'
		fi
	done < "$f"

	[ -z "$style_content" ] && continue

	# Extraer clases CSS del bloque style (excluyendo pseudo-selectores y JS)
	while IFS= read -r class; do
		clean_class=$(echo "$class" | sed 's/^\.\([a-zA-Z_-][a-zA-Z0-9_-]*\).*/\1/')
		[ "$clean_class" = "$class" ] && continue
		[ ${#clean_class} -lt 3 ] && continue
		# Excluir patrones de JavaScript
		if echo "$clean_class" | grep -qE "^($JS_PATTERNS)$"; then
			continue
		fi
		# Verificar si se usa en el template HTML del mismo archivo
		if ! grep -q "class=.*${clean_class}" "$f" 2>/dev/null && ! grep -q "class={.*${clean_class}" "$f" 2>/dev/null; then
			warn "Posible clase CSS no usada: '.${clean_class}' en '$f'"
			((CSS_WARNINGS++)) || true
		fi
	done < <(echo "$style_content" | grep -oE '\.[a-zA-Z_-][a-zA-Z0-9_-]*' 2>/dev/null | sort -u || true)
done < <(find src/components src/layouts -name "*.astro" -type f 2>/dev/null)

if [ "$CSS_WARNINGS" -eq 0 ]; then
	pass "No se detectaron clases CSS huérfanas obvias"
else
	warn "${CSS_WARNINGS} posibles clases CSS no utilizadas"
fi

# ============================================================================
# 12. LOCALE CONSISTENCY — Verificar locale field en frontmatter
# ============================================================================
section "12. LOCALE FIELD CONSISTENCY (Consistencia de Locale)"

LOCALE_ERRORS=0
for f in src/content/blog/es/*.mdx src/content/blog/es/*.md; do
	[ -f "$f" ] || continue
	locale=$(grep -m1 '^locale:' "$f" 2>/dev/null | sed 's/^locale:[[:space:]]*//' | tr -d "'\"" || true)
	if [ "$locale" != "es" ]; then
		error "Locale incorrecto en '$f': esperado 'es', obtenido '${locale}'"
		((LOCALE_ERRORS++)) || true
	fi
done

for f in src/content/blog/en/*.mdx src/content/blog/en/*.md; do
	[ -f "$f" ] || continue
	locale=$(grep -m1 '^locale:' "$f" 2>/dev/null | sed 's/^locale:[[:space:]]*//' | tr -d "'\"" || true)
	if [ "$locale" != "en" ]; then
		error "Locale incorrecto en '$f': esperado 'en', obtenido '${locale}'"
		((LOCALE_ERRORS++)) || true
	fi
done

if [ "$LOCALE_ERRORS" -eq 0 ]; then
	pass "Todos los campos locale son consistentes con su directorio"
fi

# ============================================================================
# RESUMEN FINAL
# ============================================================================
echo ""
echo -e "${BOLD}${CYAN}━━━ RESUMEN DE AUDITORÍA ━━━${NC}"
echo ""
echo -e "  ${RED}Errores:${NC}    ${ERRORS}"
echo -e "  ${YELLOW}Warnings:${NC}   ${WARNINGS}"
echo -e "  ${GREEN}Checks OK:${NC}  ${CHECKS_PASSED}"
echo ""

if [ "$ERRORS" -gt 0 ]; then
	echo -e "${RED}${BOLD}✖ AUDITORÍA FALLIDA — ${ERRORS} error(es) encontrado(s)${NC}"
	exit 1
elif [ "$WARNINGS" -gt 0 ]; then
	echo -e "${YELLOW}${BOLD}⚠ AUDITORÍA COMPLETADA CON WARNINGS — ${WARNINGS} warning(s)${NC}"
	exit 0
else
	echo -e "${GREEN}${BOLD}✔ AUDITORÍA LIMPIA — Todos los checks pasaron${NC}"
	exit 0
fi
