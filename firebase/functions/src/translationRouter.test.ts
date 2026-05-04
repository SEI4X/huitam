import assert from "node:assert/strict";
import test from "node:test";

import {
  chooseTranslationPlan,
  messageDisplayLanguage,
  restoreProtectedSegments,
  protectUntranslatableSegments,
  translationCacheKey
} from "./translationRouter";
import * as translationRouter from "./translationRouter";

test("skips messages that do not carry translatable text", () => {
  for (const text of ["12345", "+1 (555) 123-4567", "https://huitam.com/user/alex", "😂😂", "ахахах", "ok!!!"]) {
    const plan = chooseTranslationPlan({
      text,
      sourceLanguage: "russian",
      targetLanguage: "english",
      configuredProvider: "google"
    });

    assert.equal(plan.kind, "skip", text);
  }
});

test("uses configured provider for real chat text", () => {
  const googlePlan = chooseTranslationPlan({
    text: "Я забыл зарядку дома",
    sourceLanguage: "russian",
    targetLanguage: "english",
    configuredProvider: "google"
  });
  const geminiPlan = chooseTranslationPlan({
    text: "Я забыл зарядку дома",
    sourceLanguage: "russian",
    targetLanguage: "english",
    configuredProvider: "gemini"
  });

  assert.equal(googlePlan.kind, "translate");
  assert.equal(googlePlan.provider, "google");
  assert.equal(geminiPlan.kind, "translate");
  assert.equal(geminiPlan.provider, "gemini");
});

test("protects links and numbers while keeping text translatable", () => {
  const protectedText = protectUntranslatableSegments("Meet me at https://huitam.com/user/alex at 18:30");

  assert.match(protectedText.text, /__HUITAM_KEEP_0__/);
  assert.match(protectedText.text, /__HUITAM_KEEP_1__/);
  assert.equal(
    restoreProtectedSegments("Встретимся здесь __HUITAM_KEEP_0__ в __HUITAM_KEEP_1__", protectedText.segments),
    "Встретимся здесь https://huitam.com/user/alex в 18:30"
  );
});

test("cache key changes when provider, language, or text changes", () => {
  const base = translationCacheKey({
    provider: "gemini",
    model: "gemini-2.5-flash-lite",
    sourceLanguage: "russian",
    targetLanguage: "english",
    text: "Я дома"
  });

  assert.equal(base, translationCacheKey({
    provider: "gemini",
    model: "gemini-2.5-flash-lite",
    sourceLanguage: "Russian",
    targetLanguage: "English",
    text: "Я   дома"
  }));
  assert.notEqual(base, translationCacheKey({
    provider: "google",
    model: "google-nmt",
    sourceLanguage: "russian",
    targetLanguage: "english",
    text: "Я дома"
  }));
  assert.notEqual(base, translationCacheKey({
    provider: "gemini",
    model: "gemini-2.5-flash-lite",
    sourceLanguage: "russian",
    targetLanguage: "french",
    text: "Я дома"
  }));
});

test("cache key changes when translation prompt version changes", () => {
  const baseInput = {
    provider: "gemini" as const,
    model: "gemini-2.5-flash-lite",
    sourceLanguage: "russian",
    targetLanguage: "english",
    text: "Ну это прям кринж"
  };

  const v1 = translationCacheKey({...baseInput, promptVersion: "chat-v1"});
  const v2 = translationCacheKey({...baseInput, promptVersion: "chat-v2"});

  assert.notEqual(v1, v2);
});

test("cache key changes when Gemini context changes", () => {
  const baseInput = {
    provider: "gemini" as const,
    model: "gemini-2.5-flash-lite",
    promptVersion: "chat-v2",
    sourceLanguage: "russian",
    targetLanguage: "english",
    text: "Да забей"
  };

  assert.notEqual(
    translationCacheKey({...baseInput, contextMessages: ["Он опять перенес встречу"]}),
    translationCacheKey({...baseInput, contextMessages: ["Она сказала, что все нормально"]})
  );
});

test("Gemini translation prompt preserves slang and includes recent chat context", () => {
  const buildPrompt = (translationRouter as unknown as {
    buildGeminiTranslationPrompt?: (input: {
      text: string;
      sourceLanguage?: string;
      targetLanguage: string;
      contextMessages: string[];
    }) => string;
  }).buildGeminiTranslationPrompt;

  assert.equal(typeof buildPrompt, "function");

  const prompt = buildPrompt?.({
    text: "Да забей, это кринж",
    sourceLanguage: "russian",
    targetLanguage: "english",
    contextMessages: ["Он опять перенес встречу", "Ну все понятно", "Да забей"]
  }) ?? "";

  assert.match(prompt, /Recent context/);
  assert.match(prompt, /Он опять перенес встречу/);
  assert.match(prompt, /Да забей/);
  assert.match(prompt, /natural chat equivalent/i);
  assert.match(prompt, /slang/i);
  assert.match(prompt, /Translate only the current message/i);
});

test("message display language follows learner language or native companion language", () => {
  assert.equal(
    messageDisplayLanguage({
      role: {kind: "learner", learningLanguage: "english"},
      nativeLanguage: "russian"
    }),
    "english"
  );
  assert.equal(
    messageDisplayLanguage({
      role: {kind: "companion"},
      nativeLanguage: "russian"
    }),
    "russian"
  );
  assert.equal(
    messageDisplayLanguage({
      role: undefined,
      nativeLanguage: undefined
    }),
    "english"
  );
});

test("message display language follows profile changes without chat role data", () => {
  assert.equal(
    messageDisplayLanguage({
      role: undefined,
      nativeLanguage: "spanish",
      learningLanguage: "german"
    }),
    "german"
  );
  assert.equal(
    messageDisplayLanguage({
      role: undefined,
      nativeLanguage: "spanish",
      learningLanguage: undefined
    }),
    "spanish"
  );
});
