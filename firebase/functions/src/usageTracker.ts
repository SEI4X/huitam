export type GeminiUsageMetadata = {
  promptTokenCount?: number;
  candidatesTokenCount?: number;
  thoughtsTokenCount?: number;
  cachedContentTokenCount?: number;
  totalTokenCount?: number;
};

export type NormalizedGeminiUsage = {
  inputTokens: number;
  outputTokens: number;
  thinkingTokens: number;
  cachedTokens: number;
  totalTokens: number;
};

function finiteCount(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ?
    Math.trunc(value) :
    0;
}

export function normalizeGeminiUsage(usage: GeminiUsageMetadata | undefined): NormalizedGeminiUsage {
  return {
    inputTokens: finiteCount(usage?.promptTokenCount),
    outputTokens: finiteCount(usage?.candidatesTokenCount),
    thinkingTokens: finiteCount(usage?.thoughtsTokenCount),
    cachedTokens: finiteCount(usage?.cachedContentTokenCount),
    totalTokens: finiteCount(usage?.totalTokenCount)
  };
}

export function googleTranslateCharacterCount(text: string): number {
  return Array.from(text).length;
}

export function usageDailyDocumentId(date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

export function usageAggregateKey(value: string): string {
  const key = value.trim().toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
  return key.length > 0 ? key : "unknown";
}
