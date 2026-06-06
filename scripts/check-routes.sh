#!/usr/bin/env bash
# ============================================================================
# check-routes.sh — Validador ultra-agresivo de rutas
# ============================================================================
# Detecta:
#   1. Rutas que generan URLs con "undefined" o "null"
#   2. href que apuntan a rutas inexistentes
#   3. Template literals que pueden producir URLs rotas
#   4. Locale mismatch en URLs generadas
#   5. Links sin trailing slash (inconsistencia)
#   6. Rutas dinámicas sin getStaticPaths
#   7. Slugs de contenido que no coinciden con rutas generadas
#   8. Doble locale en URLs (ej: /es/blog/es/slug)
#   9. Rutas hardcoded que no existen en pages/
#  10. Parámetros de ruta undefined
# ============================================================================
set -euo pipefail

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

error() { echo -e "${RED}✖ ROUTE ERROR:${NC} $1"; ((ERRORS++)) || true; }
warn() { echo -e "${YELLOW}✖ ROUTE WARN:${NC} $1"; ((WARNINGS++)) || true; }
pass() { echo -e "${GREEN}✔ ROUTE OK:${NC} $1"; ((CHECKS_PASSED++)) || true; }
section() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }

LOCALES=("es" "en")

# ============================================================================
# 1. UNDEFINED/NULL EN HREF — Detectar URLs que generan undefined
# ============================================================================
section "1. UNDEFINED/NULL EN HREF (URLs rotas por undefined)"

UNDEFINED_COUNT=0

# Buscar patrones peligrosos en .astro: href={...variable...} donde la variable podría ser undefined
while IFS= read -r f; do
	[ -f "$f" ] || continue

	# Buscar href con template literals que usan variables
	while IFS= read -r line; do
		lineno=$(echo "$line" | cut -d: -f1)
		content=$(echo "$line" | cut -d: -f2-)

		# Detectar patrón href={variable} donde variable podría ser undefined
		if echo "$content" | grep -qE 'href=\{[a-zA-Z_][a-zA-Z0-9_]*\}'; then
			varname=$(echo "$content" | grep -oE 'href=\{[a-zA-Z_][a-zA-Z0-9_]*\}' | sed 's/href={//;s/}//')
			# Excluir si es href={href} (prop pasada tal cual)
			if [ "$varname" = "href" ]; then
				continue
			fi
			# Verificar si la variable se define en el frontmatter
			if ! grep -qE "(const|let|var|export)\s+${varname}\s*=" "$f" 2>/dev/null; then
				error "Variable '${varname}' podría ser undefined en href (file: $f, line: $lineno)"
				((UNDEFINED_COUNT++)) || true
			fi
		fi

		# Detectar href con template literal que contiene variable sin default
		if echo "$content" | grep -qE 'href=\{`[^`]*\$\{[a-zA-Z_][a-zA-Z0-9_]*\}[^`]*`\}'; then
			# Extraer la variable dentro del template
			vars=$(echo "$content" | grep -oE '\$\{([a-zA-Z_][a-zA-Z0-9_]*)\}' | sed 's/\${//;s/}//' || true)
			for varname in $vars; do
				# Variables conocidas que son seguras
				case "$varname" in
				locale | tag | otherLocale | switchLabel | SITE_TITLE) continue ;;
				esac
				# Verificar si se define en el frontmatter
				if ! grep -qE "(const|let|var)\s+${varname}\s*=" "$f" 2>/dev/null; then
					error "Variable '${varname}' en template href podría ser undefined ($f:$lineno)"
					((UNDEFINED_COUNT++)) || true
				fi
			done
		fi
	done < <(grep -n 'href=' "$f" 2>/dev/null || true)
done < <(find src -name "*.astro" -type f 2>/dev/null)

if [ "$UNDEFINED_COUNT" -eq 0 ]; then
	pass "No se detectaron href con variables potencialmente undefined"
fi

# ============================================================================
# 2. DOBLE LOCALE EN URLs — Detectar /es/blog/es/slug
# ============================================================================
section "2. DOBLE LOCALE EN URLs (Detección de locale duplicado)"

DOUBLE_LOCALE=0

while IFS= read -r f; do
	[ -f "$f" ] || continue
	while IFS= read -r line; do
		lineno=$(echo "$line" | cut -d: -f1)
		content=$(echo "$line" | cut -d: -f2-)

		# Buscar patrones como /${locale}/blog/${post.id}/ donde post.id contiene el locale
		if echo "$content" | grep -qE 'href=.*\$\{locale\}/blog/\$\{post\.id\}'; then
			error "Posible doble locale: href usa post.id que puede incluir locale duplicado ($f:$lineno)"
			error "  → Usa post.id.replace(\`\${locale}/\`, '') en lugar de solo post.id"
			((DOUBLE_LOCALE++)) || true
		fi

		# Buscar hardcoded con doble locale
		for loc in "${LOCALES[@]}"; do
			pattern="/${loc}/blog/${loc}/"
			if echo "$content" | grep -qF "$pattern"; then
				error "Doble locale detectado en URL hardcoded: '${pattern}' ($f:$lineno)"
				((DOUBLE_LOCALE++)) || true
			fi
		done
	done < <(grep -n 'href=' "$f" 2>/dev/null || true)
done < <(find src -name "*.astro" -type f 2>/dev/null)

if [ "$DOUBLE_LOCALE" -eq 0 ]; then
	pass "No se detectaron URLs con doble locale"
fi

# ============================================================================
# 3. HREF A RUTAS INEXISTENTES — Verificar que los href apunten a rutas válidas
# ============================================================================
section "3. HREF A RUTAS INEXISTENTES (Links a páginas que no existen)"

BROKEN_HREF=0

# Recopilar todas las rutas estáticas que existen en pages/
STATIC_ROUTES=()
while IFS= read -r f; do
	[ -f "$f" ] || continue
	route=$(echo "$f" | sed 's|^src/pages||' | sed 's|/index\.\(astro\|md\|mdx\)$|/|' | sed 's|\.\(astro\|md\|mdx\)$|/|')
	# Limpiar
	route=$(echo "$route" | sed 's|//|/|g')
	STATIC_ROUTES+=("$route")
done < <(find src/pages -name "*.astro" -o -name "*.md" -o -name "*.mdx" 2>/dev/null | grep -v '\[\.\.\.' || true)

# Verificar href hardcoded que apunten a rutas que no existen
while IFS= read -r f; do
	[ -f "$f" ] || continue
	while IFS= read -r line; do
		lineno=$(echo "$line" | cut -d: -f1)
		content=$(echo "$line" | cut -d: -f2-)

		# Extraer hrefs hardcoded (no template literals)
		hrefs=$(echo "$content" | grep -oE 'href="(/[^"]+)"' | sed 's/href="//;s/"$//' || true)
		for href in $hrefs; do
			# Skip external links, public files, and anchors
			[[ "$href" =~ ^https?:// ]] && continue
			[[ "$href" =~ ^mailto: ]] && continue
			[[ "$href" =~ ^# ]] && continue
			[[ "$href" =~ ^/(favicon|sitemap|robots) ]] && continue

			# Normalizar
			clean=$(echo "$href" | sed 's|/$||')

			# Verificar si la ruta estática existe
			found=false
			for route in "${STATIC_ROUTES[@]}"; do
				clean_route=$(echo "$route" | sed 's|/$||')
				if [ "$clean" = "$clean_route" ]; then
					found=true
					break
				fi
			done

			if [ "$found" = false ]; then
				# No reportar si es un patrón dinámico
				if [[ ! "$href" =~ /blog/ ]] || [[ "$href" =~ ^/[a-z][a-z]/blog$ ]]; then
					# Es una ruta estática que no existe
					if [ ! -f "src/pages${href}.astro" ] && [ ! -f "src/pages${href}/index.astro" ] && [ ! -f "src/pages${href}.md" ]; then
						warn "href apunta a ruta no verificable: '${href}' ($f:$lineno) — puede ser dinámica"
					fi
				fi
			fi
		done
	done < <(grep -n 'href="' "$f" 2>/dev/null || true)
done < <(find src -name "*.astro" -type f 2>/dev/null)

pass "Verificación de href hardcoded completada"

# ============================================================================
# 4. LOCALE CONSISTENCY EN HREF — Verificar que hrefs usen el locale correcto
# ============================================================================
section "4. LOCALE CONSISTENCY EN HREF (Consistencia de locale en URLs)"

LOCALE_MISMATCH=0

while IFS= read -r f; do
	[ -f "$f" ] || continue

	# Determinar el locale del archivo basado en su ruta
	file_locale=""
	if echo "$f" | grep -qE '^src/pages/es/'; then
		file_locale="es"
	elif echo "$f" | grep -qE '^src/pages/en/'; then
		file_locale="en"
	fi

	[ -z "$file_locale" ] && continue

	while IFS= read -r line; do
		lineno=$(echo "$line" | cut -d: -f1)
		content=$(echo "$line" | cut -d: -f2-)

		# Verificar que hrefs hardcoded usen el locale correcto
		hrefs=$(echo "$content" | grep -oE 'href="(/[^"]+)"' | sed 's/href="//;s/"$//' || true)
		for href in $hrefs; do
			[[ "$href" =~ ^https?:// ]] && continue
			[[ "$href" =~ ^mailto: ]] && continue

			# Verificar si el href usa un locale diferente al del archivo
			for loc in "${LOCALES[@]}"; do
				if echo "$href" | grep -qE "^/${loc}/" && [ "$loc" != "$file_locale" ]; then
					warn "href usa locale '${loc}' pero el archivo está en '${file_locale}/' ($f:$lineno)"
					((LOCALE_MISMATCH++)) || true
				fi
			done
		done
	done < <(grep -n 'href=' "$f" 2>/dev/null || true)
done < <(find src/pages -name "*.astro" -type f 2>/dev/null)

if [ "$LOCALE_MISMATCH" -eq 0 ]; then
	pass "Todos los href usan el locale correcto de su archivo"
fi

# ============================================================================
# 5. TRAILING SLASH CONSISTENCY — Verificar consistencia de trailing slash
# ============================================================================
section "5. TRAILING SLASH CONSISTENCY (Consistencia de barra final)"

SLASH_INCONSISTENT=0

while IFS= read -r f; do
	[ -f "$f" ] || continue
	while IFS= read -r line; do
		lineno=$(echo "$line" | cut -d: -f1)
		content=$(echo "$line" | cut -d: -f2-)

		# Buscar hrefs hardcoded sin trailing slash que apunten a páginas (no archivos)
		hrefs=$(echo "$content" | grep -oE 'href="(/[^"]+)"' | sed 's/href="//;s/"$//' || true)
		for href in $hrefs; do
			[[ "$href" =~ ^https?:// ]] && continue
			[[ "$href" =~ ^mailto: ]] && continue
			[[ "$href" =~ \.(jpg|png|svg|gif|css|js|ico|xml|json|woff|woff2)$ ]] && continue
			[[ "$href" =~ \? ]] && continue
			[[ "$href" =~ ^# ]] && continue

			# Si no termina en / y no es un archivo, podría necesitar trailing slash
			if [[ ! "$href" =~ /$ ]] && [[ ! "$href" =~ \.[a-z]+$ ]]; then
				# Verificar si es una ruta de página (no un anchor o query)
				if echo "$href" | grep -qE '^/[a-z][a-z]/'; then
					warn "href sin trailing slash: '${href}' ($f:$lineno) — inconsistente con el resto del proyecto"
					((SLASH_INCONSISTENT++)) || true
				fi
			fi
		done
	done < <(grep -n 'href=' "$f" 2>/dev/null || true)
done < <(find src -name "*.astro" -type f 2>/dev/null)

if [ "$SLASH_INCONSISTENT" -eq 0 ]; then
	pass "Trailing slash consistente en todos los href"
fi

# ============================================================================
# 6. CONTENT SLUG vs ROUTE MISMATCH — Verificar que slugs coincidan
# ============================================================================
section "6. CONTENT SLUG vs ROUTE (Slugs vs Rutas generadas)"

SLUG_MISMATCH=0

# Para cada post de blog, verificar que el slug generado por getStaticPaths coincida
for locale in "${LOCALES[@]}"; do
	for f in src/content/blog/${locale}/*.mdx src/content/blog/${locale}/*.md; do
		[ -f "$f" ] || continue
		slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')

		# Verificar que la ruta esperada exista
		expected_route="src/pages/${locale}/blog/${slug}.astro"
		if [ ! -f "$expected_route" ]; then
			# Verificar si hay un [...slug].astro (ruta dinámica)
			if [ -f "src/pages/${locale}/blog/[...slug].astro" ]; then
				# OK, es dinámico
				:
			else
				error "Post '${locale}/${slug}' no tiene ruta asociada ni dinámica"
				((SLUG_MISMATCH++)) || true
			fi
		fi
	done
done

if [ "$SLUG_MISMATCH" -eq 0 ]; then
	pass "Todos los slugs de contenido tienen rutas asociadas"
fi

# ============================================================================
# 7. GETSTATICPATHS RETURN VALUES — Verificar return values de getStaticPaths
# ============================================================================
section "7. GETSTATICPATHS RETURN VALUES (Verificación de parámetros)"

GSP_ERRORS=0

while IFS= read -r f; do
	[ -f "$f" ] || continue

	# Verificar que getStaticPaths retorne params que coincidan con el archivo
	if grep -q 'getStaticPaths' "$f" 2>/dev/null; then
		# Extraer los params retornados
		params=$(grep -A5 'getStaticPaths' "$f" | grep -oE 'params:\s*\{[^}]+\}' | grep -oE '[a-zA-Z]+:\s*"[^"]+"' || true)
		for param in $params; do
			key=$(echo "$param" | cut -d: -f1 | tr -d ' ')
			value=$(echo "$param" | cut -d: -f2- | tr -d '" ')

			# Verificar que el param value no sea undefined/null
			if [ "$value" = "undefined" ] || [ "$value" = "null" ]; then
				error "getStaticPaths retorna param '${key}' con valor '${value}' ($f)"
				((GSP_ERRORS++)) || true
			fi
		done
	fi
done < <(find src/pages -name "*.astro" -type f 2>/dev/null)

if [ "$GSP_ERRORS" -eq 0 ]; then
	pass "getStaticPaths retorna valores válidos"
fi

# ============================================================================
# 8. IMPORTS DE RUTAS DINÁMICAS — Verificar que [...slug].astro exista
# ============================================================================
section "8. RUTAS DINÁMICAS (Verificación de catch-all routes)"

DYNAMIC_OK=0

for locale in "${LOCALES[@]}"; do
	# Verificar que exista [...slug].astro para cada locale que tiene blog
	if [ -d "src/content/blog/${locale}" ]; then
		if [ -f "src/pages/${locale}/blog/[...slug].astro" ]; then
			((DYNAMIC_OK++)) || true
		else
			error "Falta ruta dinámica 'src/pages/${locale}/blog/[...slug].astro' para posts de '${locale}'"
		fi
	fi
done

if [ "$DYNAMIC_OK" -gt 0 ]; then
	pass "Rutas dinámicas [...slug] presentes para todos los locales con blog"
fi

# ============================================================================
# 9. REDIRECTS Y LINKS EXTERNOS ROTOS — Detectar redirects problemáticos
# ============================================================================
section "9. REDIRECTS Y PATRONES PROBLEMÁTICOS"

REDIRECT_COUNT=0

while IFS= read -r f; do
	[ -f "$f" ] || continue

	# Detectar window.location.href en scripts (posibles redirects no SEO-friendly)
	if grep -q 'window.location.href' "$f" 2>/dev/null; then
		target=$(grep -oE 'window\.location\.href\s*=\s*"[^"]+"' "$f" | sed 's/window.location.href\s*=\s*"//;s/"$//' || true)
		if [ -n "$target" ]; then
			warn "Redirect por JavaScript en '$f' → '${target}' (no es SEO-friendly, usa redirect de Astro)"
			((REDIRECT_COUNT++)) || true
		fi
	fi

	# Detectar href="" vacío
	if grep -q 'href=""' "$f" 2>/dev/null; then
		error "href vacío detectado en '$f'"
		((REDIRECT_COUNT++)) || true
	fi

	# Detectar href="#" que podría ser un link roto
	while IFS= read -r line; do
		lineno=$(echo "$line" | cut -d: -f1)
		content=$(echo "$line" | cut -d: -f2-)
		if echo "$content" | grep -qE 'href="#"'; then
			# Solo warn si no es un botón o elemento interactivo
			if ! echo "$content" | grep -qE '(button|role=)'; then
				warn "href='#' detectado en '$f:$lineno' — ¿es un link roto o un botón?"
				((REDIRECT_COUNT++)) || true
			fi
		fi
	done < <(grep -n 'href="#"' "$f" 2>/dev/null || true)
done < <(find src -name "*.astro" -type f 2>/dev/null)

if [ "$REDIRECT_COUNT" -eq 0 ]; then
	pass "No se detectaron redirects problemáticos ni href vacíos"
fi

# ============================================================================
# 10. CROSS-REFERENCE: TODO JUNTO — Verificación cruzada final
# ============================================================================
section "10. CROSS-REFERENCE FINAL (Verificación cruzada completa)"

# Verificar que cada post tenga su par en ambos idiomas
CROSS_ERRORS=0
for locale in "${LOCALES[@]}"; do
	other=""
	if [ "$locale" = "es" ]; then other="en"; else other="es"; fi

	for f in src/content/blog/${locale}/*.mdx src/content/blog/${locale}/*.md; do
		[ -f "$f" ] || continue
		slug=$(basename "$f" | sed 's/\.\(mdx\|md\)$//')

		# Verificar que exista en el otro idioma
		if [ ! -f "src/content/blog/${other}/${slug}.mdx" ] && [ ! -f "src/content/blog/${other}/${slug}.md" ]; then
			warn "Post '${locale}/${slug}' no tiene variante en '${other}'"
			((CROSS_ERRORS++)) || true
		fi

		# Verificar que el link del blog index apunte a la ruta correcta
		# La ruta debe ser: /${locale}/blog/${slug}/
		expected_href="/${locale}/blog/${slug}/"
		# Verificar que el archivo de página exista
		if [ ! -f "src/pages/${locale}/blog/${slug}.astro" ] && [ ! -f "src/pages/${locale}/blog/[...slug].astro" ]; then
			error "Link esperado '${expected_href}' no tiene ruta asociada"
			((CROSS_ERRORS++)) || true
		fi
	done
done

if [ "$CROSS_ERRORS" -eq 0 ]; then
	pass "Verificación cruzada completada sin errores"
fi

# ============================================================================
# RESUMEN FINAL
# ============================================================================
echo ""
echo -e "${BOLD}${CYAN}━━━ RESUMEN DE VALIDACIÓN DE RUTAS ━━━${NC}"
echo ""
echo -e "  ${RED}Errores:${NC}    ${ERRORS}"
echo -e "  ${YELLOW}Warnings:${NC}   ${WARNINGS}"
echo -e "  ${GREEN}Checks OK:${NC}  ${CHECKS_PASSED}"
echo ""

if [ "$ERRORS" -gt 0 ]; then
	echo -e "${RED}${BOLD}✖ VALIDACIÓN DE RUTAS FALLIDA — ${ERRORS} error(es) encontrado(s)${NC}"
	echo -e "${RED}${BOLD}  Los errores de rutas causan 404s yLinks rotos en producción${NC}"
	exit 1
elif [ "$WARNINGS" -gt 0 ]; then
	echo -e "${YELLOW}${BOLD}⚠ VALIDACIÓN DE RUTAS CON WARNINGS — ${WARNINGS} warning(s)${NC}"
	exit 0
else
	echo -e "${GREEN}${BOLD}✔ TODAS LAS RUTAS VÁLIDAS — Sin errores ni warnings${NC}"
	exit 0
fi
