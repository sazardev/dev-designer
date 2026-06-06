.PHONY: help dev build preview lint lint-fix format format-check check knip \
       check-links check-routes check-all audit fix clean install hooks \
       add-hook pre-commit pre-push commit-msg

# ============================================================================
# ASTRO DEV DESIGNER — Makefile de Automatización
# ============================================================================

# Colors
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BOLD := \033[1m
NC := \033[0m

help: ## Mostrar esta ayuda
	@echo ""
	@printf "\033[1m\033[0;36m━━━ ASTRO DEV DESIGNER — Comandos Disponibles ━━━\033[0m\n"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[0;32mmake %-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ============================================================================
# DESARROLLO
# ============================================================================

dev: ## Iniciar servidor de desarrollo
	npm run dev

build: ## Construir el proyecto para producción
	npm run build

preview: ## Previsualizar la build de producción
	npm run preview

# ============================================================================
# LINTING & FORMATEO
# ============================================================================

lint: ## Ejecutar ESLint en todo el proyecto
	npm run lint

lint-fix: ## Ejecutar ESLint con auto-fix
	npm run lint:fix

format: ## Formatear todo con Prettier
	npm run format

format-check: ## Verificar formateo sin modificar archivos
	npm run format:check

# ============================================================================
# TYPE CHECKING
# ============================================================================

check: ## Ejecutar Astro type check (TypeScript estricto)
	npm run check

# ============================================================================
# CODE HEALTH — Detección de código muerto
# ============================================================================

knip: ## Encontrar imports/exports/dependencias no usados
	npm run knip

# ============================================================================
# LINK & ROUTE CHECKING
# ============================================================================

check-links: ## Verificar links rotos en HTML generado (requiere build previo)
	npm run check:links

check-routes: ## Analizar rutas huérfanas en el código fuente (JS)
	npm run check:routes

check-routes-strict: ## Validador ultra-agresivo de rutas (undefined, doble locale, href rotos)
	bash scripts/check-routes.sh

check-all: ## Auditoría completa de links, rutas, authors, i18n, frontmatter
	npm run check:all && bash scripts/check-routes.sh

# ============================================================================
# AUDITORÍA COMPLETA
# ============================================================================

audit: ## Ejecutar TODOS los checks (type, lint, format, knip, routes, build, links)
	@printf "\033[1m\033[0;36m━━━ Ejecutando auditoría completa ━━━\033[0m\n"
	@echo ""
	@printf "\033[1;33m[1/7]\033[0m Type checking..."
	npm run check
	@printf "\033[1;33m[2/7]\033[0m ESLint...\n"
	npm run lint
	@printf "\033[1;33m[3/7]\033[0m Prettier check...\n"
	npm run format:check
	@printf "\033[1;33m[4/7]\033[0m Knip (código muerto)...\n"
	npm run knip
	@printf "\033[1;33m[5/8]\033[0m Route analyzer (JS)...\n"
	npm run check:routes
	@printf "\033[1;33m[6/8]\033[0m Route validator (bash)...\n"
	bash scripts/check-routes.sh
	@printf "\033[1;33m[7/8]\033[0m Build...\n"
	npm run build
	@printf "\033[1;33m[8/8]\033[0m Link checker...\n"
	@echo ""
	@printf "\033[0;32m\033[1m✔ Auditoría completada exitosamente\033[0m\n"

# ============================================================================
# FIX — Reparar todo lo que se pueda
# ============================================================================

fix: ## Auto-fix: lint + format + knip
	@printf "\033[1m\033[0;36m━━━ Ejecutando fixes automáticos ━━━\033[0m\n"
	@echo ""
	@printf "\033[1;33m[1/3]\033[0m ESLint auto-fix...\n"
	npm run lint:fix
	@printf "\033[1;33m[2/3]\033[0m Prettier format...\n"
	npm run format
	@printf "\033[1;33m[3/3]\033[0m Knip (verificar código muerto)...\n"
	-npm run knip || true
	@echo ""
	@printf "\033[0;32m\033[1m✔ Fixes completados\033[0m\n"

# ============================================================================
# INSTALACIÓN & CONFIGURACIÓN
# ============================================================================

install: ## Instalar todas las dependencias
	npm install

hooks: ## Configurar hooks de Husky
	npx husky

# ============================================================================
# HOOKS INDIVIDUALES — Para testing manual
# ============================================================================

pre-commit: ## Ejecutar lint-staged (simula pre-commit)
	npx lint-staged

pre-push: ## Ejecutar checks de pre-push (simula pre-push)
	npx eslint . --max-warnings=0
	npx prettier --check "src/**/*.{astro,ts,tsx,js,jsx,mdx}"
	npx astro check

commit-msg: ## Ejecutar commitlint (simula commit-msg)
	@echo "Uso: make commit-msg MSG='feat: add feature'"

add-hook: ## Agregar un hook personalizado. Uso: make add-hook HOOK=pre-commit CMD='npm test'
	@printf "\033[0;36mAgregando hook: %s\033[0m\n" "$(HOOK)"
	@echo "$(CMD)" > .husky/$(HOOK)
	@chmod +x .husky/$(HOOK)
	@printf "\033[0;32m✔ Hook '%s' creado\033[0m\n" "$(HOOK)"

# ============================================================================
# LIMPIEZA
# ============================================================================

clean: ## Limpiar build y caches
	rm -rf dist/ .astro/ node_modules/.cache
	@printf "\033[0;32m✔ Caches limpiados\033[0m\n"

clean-all: ## Limpiar todo incluyendo node_modules
	rm -rf dist/ .astro/ node_modules/
	@printf "\033[0;32m✔ Todo limpiado\033[0m\n"

# ============================================================================
# UTILIDADES
# ============================================================================

list-routes: ## Listar todas las rutas del proyecto
	@printf "\033[1m\033[0;36m━━━ Rutas en src/pages/ ━━━\033[0m\n"
	@find src/pages -name "*.astro" -o -name "*.md" -o -name "*.mdx" | sort | sed 's|src/pages||' | sed 's|/index\.\(astro\|md\|mdx\)$$|/|' | sed 's|\.\(astro\|md\|mdx\)$$||'

list-content: ## Listar todo el contenido del blog
	@printf "\033[1m\033[0;36m━━━ Blog Posts ━━━\033[0m\n"
	@echo ""
	@printf "\033[1;33mES:\033[0m\n"
	@ls -1 src/content/blog/es/ 2>/dev/null || echo "  (vacío)"
	@echo ""
	@echo "$(YELLOW)EN:${NC}"
	@ls -1 src/content/blog/en/ 2>/dev/null || echo "  (vacío)"

list-authors: ## Listar todos los autores
	@printf "\033[1m\033[0;36m━━━ Authors ━━━\033[0m\n"
	@echo ""
	@printf "\033[1;33mES:\033[0m\n"
	@ls -1 src/content/authors/es/ 2>/dev/null || echo "  (vacío)"
	@echo ""
	@echo "$(YELLOW)EN:${NC}"
	@ls -1 src/content/authors/en/ 2>/dev/null || echo "  (vacío)"

status: ## Mostrar estado del proyecto (git + herramientas)
	@printf "\033[1m\033[0;36m━━━ Estado del Proyecto ━━━\033[0m\n"
	@echo ""
	@printf "\033[1;33mGit Status:\033[0m\n"
	@git status --short
	@echo ""
	@printf "\033[1;33mHusky Hooks:\033[0m\n"
	@ls -1 .husky/ 2>/dev/null | grep -v '^_$$' || echo "  (no configurado)"
	@echo ""
	@printf "\033[1;33mNode:\033[0m $$(node --version)\n"
	@printf "\033[1;33mnpm:\033[0m $$(npm --version)\n"
