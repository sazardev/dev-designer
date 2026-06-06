export const SITE_TITLE = "dev-design";
export const SITE_DESCRIPTION = {
  es: "Patrones de diseño, arquitectura de software y mejores prácticas",
  en: "Design patterns, software architecture and best practices",
};

export const LOCALES = ["es", "en"] as const;
export const DEFAULT_LOCALE = "es";

export const CATEGORIES = {
  "design-patterns": { es: "Patrones de Diseño", en: "Design Patterns" },
  architecture: { es: "Arquitectura", en: "Architecture" },
  frontend: { es: "Frontend", en: "Frontend" },
  backend: { es: "Backend", en: "Backend" },
  devops: { es: "DevOps", en: "DevOps" },
  tips: { es: "Tips", en: "Tips" },
  tutorial: { es: "Tutorial", en: "Tutorial" },
} as const;

export const DIFFICULTY = {
  beginner: { es: "Principiante", en: "Beginner", color: "var(--success)" },
  intermediate: { es: "Intermedio", en: "Intermediate", color: "var(--warning)" },
  advanced: { es: "Avanzado", en: "Advanced", color: "var(--accent)" },
} as const;
