import assert from "node:assert/strict";
import test from "node:test";

import {
  googleTranslateCharacterCount,
  normalizeGeminiUsage,
  usageAggregateKey,
  usageDailyDocumentId
} from "./usageTracker";

test("normalizes Gemini token usage with every billable bucket", () => {
  const usage = normalizeGeminiUsage({
    promptTokenCount: 12,
    candidatesTokenCount: 7,
    thoughtsTokenCount: 3,
    cachedContentTokenCount: 2,
    totalTokenCount: 24
  });

  assert.deepEqual(usage, {
    inputTokens: 12,
    outputTokens: 7,
    thinkingTokens: 3,
    cachedTokens: 2,
    totalTokens: 24
  });
});

test("normalizes missing Gemini token usage to zeroes", () => {
  const usage = normalizeGeminiUsage(undefined);

  assert.deepEqual(usage, {
    inputTokens: 0,
    outputTokens: 0,
    thinkingTokens: 0,
    cachedTokens: 0,
    totalTokens: 0
  });
});

test("counts Google Translate characters by Unicode code point", () => {
  assert.equal(googleTranslateCharacterCount("Hello 👋 мир"), 11);
});

test("formats usage daily document ids in UTC", () => {
  assert.equal(
    usageDailyDocumentId(new Date("2026-05-03T23:59:59.000Z")),
    "2026-05-03"
  );
});

test("formats Firestore-safe aggregate keys", () => {
  assert.equal(usageAggregateKey("gemini-2.0-flash"), "gemini_2_0_flash");
  assert.equal(usageAggregateKey("google-translate"), "google_translate");
});
