import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const blog = defineCollection({
  loader: glob({ base: "./src/content/blog", pattern: "**/*.{md,mdx}" }),
  schema: ({ image }) =>
    z.object({
      title: z.string(),
      description: z.string(),
      pubDate: z.coerce.date(),
      updatedDate: z.coerce.date().optional(),
      heroImage: z.optional(image()),
      locale: z.enum(["es", "en"]),

      // Metadata
      author: z.string(),
      tags: z.array(z.string()).default([]),
      category: z.enum([
        "design-patterns",
        "architecture",
        "frontend",
        "backend",
        "devops",
        "tips",
        "tutorial",
      ]),
      difficulty: z.enum(["beginner", "intermediate", "advanced"]).optional(),
      featured: z.boolean().default(false),
      relatedPosts: z.array(z.string()).default([]),
      draft: z.boolean().default(false),
    }),
});

const authors = defineCollection({
  loader: glob({ base: "./src/content/authors", pattern: "**/*.md" }),
  schema: z.object({
    name: z.string(),
    avatar: z.string(),
    locale: z.enum(["es", "en"]),
    bio: z.string().optional(),
    social: z
      .object({
        github: z.string().optional(),
        twitter: z.string().optional(),
        linkedin: z.string().optional(),
      })
      .optional(),
  }),
});

export const collections = { blog, authors };
