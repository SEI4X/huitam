import * as crypto from "node:crypto";

export type TranslationProvider = "google" | "gemini";

export type TranslationPlan =
  | {
      kind: "skip";
      reason: "same-language" | "empty" | "non-text" | "common-noise";
      translatedText: string;
    }
  | {
      kind: "translate";
      provider: TranslationProvider;
      text: string;
      protectedSegments: ProtectedSegment[];
    };

export type ProtectedSegment = {
  token: string;
  value: string;
};

export type ChooseTranslationPlanInput = {
  text: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  configuredProvider: string | undefined;
};

export type TranslationCacheKeyInput = {
  provider: TranslationProvider;
  model: string;
  promptVersion?: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  text: string;
  contextMessages?: string[];
};

export type GeminiTranslationPromptInput = {
  text: string;
  sourceLanguage?: string;
  targetLanguage: string;
  contextMessages: string[];
};

export type MessageDisplayLanguageInput = {
  role?: {
    kind?: string;
    learningLanguage?: string;
  };
  nativeLanguage?: string;
  learningLanguage?: string;
};

const commonNoise = new Set([
  "a",
  "ah",
  "aha",
  "ahah",
  "ahaha",
  "ах",
  "ахах",
  "ахаха",
  "ахахах",
  "да",
  "нет",
  "неа",
  "ок",
  "окей",
  "окк",
  "ага",
  "угу",
  "yes",
  "yeah",
  "yep",
  "no",
  "nope",
  "ok",
  "okay",
  "kk",
  "lol",
  "lmao",
  "haha",
  "hahaha",
  "hehe",
  "thanks",
  "thx",
  "ty",
  "спс",
  "пасиб",
  "спасибо"
]);

const urlPattern = /\bhttps?:\/\/[^\s<>"']+|\bwww\.[^\s<>"']+/gi;
const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const phonePattern = /(?<![\p{L}\p{N}])\+?\d[\d\s().-]{5,}\d(?![\p{L}\p{N}])/gu;
const timePattern = /(?<![\p{L}\p{N}])\d{1,2}:\d{2}(?![\p{L}\p{N}])/gu;
const numberPattern = /(?<![\p{L}\p{N}])\d+(?:[.,]\d+)*(?![\p{L}\p{N}])/gu;
const textLetterPattern = /\p{L}/u;

export const MESSAGE_TRANSLATION_PROMPT_VERSION = "chat-v2";

export function chooseTranslationPlan(input: ChooseTranslationPlanInput): TranslationPlan {
  const trimmedText = input.text.replace(/\s+/g, " ").trim();
  if (!trimmedText) {
    return {kind: "skip", reason: "empty", translatedText: input.text};
  }

  if (normalizeLanguage(input.sourceLanguage) === normalizeLanguage(input.targetLanguage)) {
    return {kind: "skip", reason: "same-language", translatedText: input.text};
  }

  if (isCommonNoise(trimmedText)) {
    return {kind: "skip", reason: "common-noise", translatedText: input.text};
  }

  const protectedText = protectUntranslatableSegments(trimmedText);
  if (!hasMeaningfulText(protectedText.text)) {
    return {kind: "skip", reason: "non-text", translatedText: input.text};
  }

  return {
    kind: "translate",
    provider: configuredProvider(input.configuredProvider),
    text: protectedText.text,
    protectedSegments: protectedText.segments
  };
}

export function protectUntranslatableSegments(text: string): {text: string; segments: ProtectedSegment[]} {
  const matches: Array<{start: number; end: number; value: string}> = [];
  const patterns = [urlPattern, emailPattern, phonePattern, timePattern, numberPattern];

  for (const pattern of patterns) {
    pattern.lastIndex = 0;
    for (const match of text.matchAll(pattern)) {
      const start = match.index ?? -1;
      if (start < 0) continue;
      const value = match[0];
      const end = start + value.length;
      const overlaps = matches.some((existing) => start < existing.end && end > existing.start);
      if (!overlaps) {
        matches.push({start, end, value});
      }
    }
  }

  matches.sort((left, right) => left.start - right.start);

  let cursor = 0;
  let nextText = "";
  const segments: ProtectedSegment[] = [];
  for (const match of matches) {
    const token = `__HUITAM_KEEP_${segments.length}__`;
    nextText += text.slice(cursor, match.start);
    nextText += token;
    segments.push({token, value: match.value});
    cursor = match.end;
  }
  nextText += text.slice(cursor);

  return {text: nextText, segments};
}

export function restoreProtectedSegments(text: string, segments: ProtectedSegment[]): string {
  return segments.reduce(
    (result, segment) => result.split(segment.token).join(segment.value),
    text
  );
}

export function translationCacheKey(input: TranslationCacheKeyInput): string {
  const payload = [
    "v1",
    input.provider,
    input.model,
    input.promptVersion ?? "legacy",
    normalizeLanguage(input.sourceLanguage) ?? "auto",
    normalizeLanguage(input.targetLanguage) ?? "auto",
    input.text.replace(/\s+/g, " ").trim(),
    ...(input.contextMessages ?? []).map((message) => message.replace(/\s+/g, " ").trim())
  ].join("\u001f");
  return crypto.createHash("sha256").update(payload).digest("hex");
}

export function buildGeminiTranslationPrompt(input: GeminiTranslationPromptInput): string {
  const sourceInstruction = input.sourceLanguage ?
    `Source language: ${input.sourceLanguage}.` :
    "Detect the source language.";
  const contextLines = input.contextMessages
    .map((message, index) => `${index + 1}. ${message.replace(/\s+/g, " ").trim()}`)
    .filter((line) => !line.endsWith(". "));
  const recentContext = contextLines.length > 0 ?
    ["Recent context. Use this only to understand tone and meaning:", ...contextLines].join("\n") :
    "Recent context: none.";

  return [
    "Translate a private messenger chat message.",
    sourceInstruction,
    `Target language: ${input.targetLanguage}.`,
    "",
    recentContext,
    "",
    "Rules:",
    "- Translate only the current message.",
    "- Return a natural chat equivalent, not a literal classroom translation.",
    "- Preserve slang, jokes, emotion, intensity, emojis, punctuation, and casual tone.",
    "- Keep names, links, numbers, times, emails, and every placeholder like __HUITAM_KEEP_0__ exactly unchanged.",
    "- Do not add explanations, quotes, labels, Markdown, alternatives, or commentary.",
    "",
    "Current message:",
    input.text
  ].join("\n");
}

export function messageDisplayLanguage(input: MessageDisplayLanguageInput): string {
  const learningLanguage = input.learningLanguage ??
    (input.role?.kind === "learner" ? input.role.learningLanguage : undefined);
  return learningLanguage?.trim() || input.nativeLanguage?.trim() || "english";
}

function configuredProvider(value: string | undefined): TranslationProvider {
  return value === "google" || value === "google-translate" || value === "cloudTranslation" ?
    "google" :
    "gemini";
}

function normalizeLanguage(language: string | undefined): string | undefined {
  return language?.trim().toLowerCase();
}

function isCommonNoise(text: string): boolean {
  const normalized = text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "");

  if (!normalized) return true;
  if (commonNoise.has(normalized)) return true;
  if (/^(а?ха)+х?$/.test(normalized)) return true;
  if (/^(ha)+h?$/.test(normalized)) return true;
  if (/^(he)+h?$/.test(normalized)) return true;
  return false;
}

function hasMeaningfulText(text: string): boolean {
  const withoutTokens = text.replace(/__HUITAM_KEEP_\d+__/g, " ");
  if (!textLetterPattern.test(withoutTokens)) return false;

  const lettersOnly = Array.from(withoutTokens.matchAll(/\p{L}/gu)).map((match) => match[0]).join("");
  if (lettersOnly.length === 0) return false;

  return !isCommonNoise(lettersOnly);
}
