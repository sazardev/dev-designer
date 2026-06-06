import readingTime from "reading-time";

export function getReadingTime(content: string): string {
  const stats = readingTime(content);
  return stats.text.replace("min read", "min");
}

export function getReadingTimeMinutes(content: string): number {
  const stats = readingTime(content);
  return stats.minutes;
}
