import {TranslationServiceClient} from "@google-cloud/translate";
import {GoogleGenAI} from "@google/genai";
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  buildGeminiTranslationPrompt,
  chooseTranslationPlan,
  MESSAGE_TRANSLATION_PROMPT_VERSION,
  messageDisplayLanguage,
  restoreProtectedSegments,
  translationCacheKey,
  TranslationProvider
} from "./translationRouter";
import {
  googleTranslateCharacterCount,
  normalizeGeminiUsage,
  usageAggregateKey,
  usageDailyDocumentId
} from "./usageTracker";

admin.initializeApp();

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "huitam-app";
const vertexLocation = process.env.VERTEX_LOCATION || "us-central1";
const translationClient = new TranslationServiceClient();
const genAI = new GoogleGenAI({
  vertexai: true,
  project: projectId,
  location: vertexLocation
});

type TranslationRuntimeConfig = {
  enabled: boolean;
  provider: TranslationProvider;
  geminiModel: string;
  promptVersion: string;
};

let cachedTranslationConfig: {value: TranslationRuntimeConfig; expiresAt: number} | undefined;

type UsageLoggingConfig = {
  enabled: boolean;
  cloudLoggingEnabled: boolean;
  firestoreAggregationEnabled: boolean;
};

let cachedUsageLoggingConfig: {value: UsageLoggingConfig; expiresAt: number} | undefined;

type AIUsageContext = {
  feature: string;
  uid?: string;
  chatId?: string;
  messageId?: string;
  senderUid?: string;
  recipientUid?: string;
  sourceLanguage?: string;
  targetLanguage?: string;
};

type AIUsageRecord = AIUsageContext & {
  provider: "gemini" | "google-translate";
  model: string;
  success: boolean;
  latencyMs: number;
  inputTokens?: number;
  thinkingTokens?: number;
  outputTokens?: number;
  cachedTokens?: number;
  totalTokens?: number;
  translateCharacters?: number;
  errorCode?: string;
};

function uidFromRequest(request: { auth?: { uid?: string } }): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  return uid;
}

function requiredString(data: unknown, field: string): string {
  if (!data || typeof data !== "object" || !(field in data)) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  const value = (data as Record<string, unknown>)[field];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} must be a non-empty string.`);
  }
  return value;
}

function optionalString(data: unknown, field: string): string | undefined {
  if (!data || typeof data !== "object" || !(field in data)) {
    return undefined;
  }
  const value = (data as Record<string, unknown>)[field];
  return typeof value === "string" && value.trim().length > 0 ? value : undefined;
}

function assertShortText(text: string, field = "text"): void {
  if (text.length > 4000) {
    throw new HttpsError("invalid-argument", `${field} is too long.`);
  }
}

function languageCode(language: string | undefined): string | undefined {
  if (!language) return undefined;

  const codes: Record<string, string> = {
    english: "en",
    french: "fr",
    spanish: "es",
    german: "de",
    italian: "it",
    portuguese: "pt",
    russian: "ru",
    japanese: "ja",
    korean: "ko",
    chinese: "zh"
  };

  return codes[language] ?? language;
}

function remoteConfigValue(template: admin.remoteConfig.RemoteConfigTemplate, name: string): string | undefined {
  const parameter = template.parameters[name];
  const defaultValue = parameter?.defaultValue as {value?: string} | undefined;
  const value = defaultValue?.value?.trim();
  return value && value.length > 0 ? value : undefined;
}

async function messageTranslationConfig(): Promise<TranslationRuntimeConfig> {
  const now = Date.now();
  if (cachedTranslationConfig && cachedTranslationConfig.expiresAt > now) {
    return cachedTranslationConfig.value;
  }

  const fallback: TranslationRuntimeConfig = {
    enabled: true,
    provider: "gemini",
    geminiModel: "gemini-2.5-flash-lite",
    promptVersion: MESSAGE_TRANSLATION_PROMPT_VERSION
  };

  try {
    const template = await admin.remoteConfig().getTemplate();
    const enabledValue = remoteConfigValue(template, "message_translation_enabled");
    const providerValue =
      remoteConfigValue(template, "message_translation_provider") ??
      remoteConfigValue(template, "translation_provider");
    const geminiModel =
      remoteConfigValue(template, "message_translation_gemini_model") ??
      fallback.geminiModel;
    const promptVersion =
      remoteConfigValue(template, "message_translation_prompt_version") ??
      fallback.promptVersion;

    const value: TranslationRuntimeConfig = {
      enabled: enabledValue ? enabledValue !== "false" && enabledValue !== "0" : fallback.enabled,
      provider: providerValue === "google" || providerValue === "google-translate" ? "google" : "gemini",
      geminiModel,
      promptVersion
    };
    cachedTranslationConfig = {
      value,
      expiresAt: now + 60_000
    };
    return value;
  } catch (error) {
    console.warn("Remote Config translation settings unavailable. Using fallback.", error);
    cachedTranslationConfig = {
      value: fallback,
      expiresAt: now + 30_000
    };
    return fallback;
  }
}

function remoteConfigBoolean(template: admin.remoteConfig.RemoteConfigTemplate, name: string, fallback: boolean): boolean {
  const value = remoteConfigValue(template, name);
  if (!value) return fallback;
  return value !== "false" && value !== "0";
}

async function usageLoggingConfig(): Promise<UsageLoggingConfig> {
  const now = Date.now();
  if (cachedUsageLoggingConfig && cachedUsageLoggingConfig.expiresAt > now) {
    return cachedUsageLoggingConfig.value;
  }

  const fallback: UsageLoggingConfig = {
    enabled: true,
    cloudLoggingEnabled: true,
    firestoreAggregationEnabled: true
  };

  try {
    const template = await admin.remoteConfig().getTemplate();
    const value: UsageLoggingConfig = {
      enabled: remoteConfigBoolean(template, "ai_usage_logging_enabled", fallback.enabled),
      cloudLoggingEnabled: remoteConfigBoolean(template, "ai_usage_cloud_logging_enabled", fallback.cloudLoggingEnabled),
      firestoreAggregationEnabled: remoteConfigBoolean(
        template,
        "ai_usage_firestore_aggregation_enabled",
        fallback.firestoreAggregationEnabled
      )
    };
    cachedUsageLoggingConfig = {
      value,
      expiresAt: now + 60_000
    };
    return value;
  } catch (error) {
    console.warn("Remote Config AI usage logging settings unavailable. Using fallback.", error);
    cachedUsageLoggingConfig = {
      value: fallback,
      expiresAt: now + 30_000
    };
    return fallback;
  }
}

function usageRecordPayload(record: AIUsageRecord): Record<string, unknown> {
  return {
    event: "huitam_ai_usage",
    feature: record.feature,
    provider: record.provider,
    model: record.model,
    uid: record.uid ?? null,
    chatId: record.chatId ?? null,
    messageId: record.messageId ?? null,
    senderUid: record.senderUid ?? null,
    recipientUid: record.recipientUid ?? null,
    sourceLanguage: record.sourceLanguage ?? null,
    targetLanguage: record.targetLanguage ?? null,
    success: record.success,
    latencyMs: record.latencyMs,
    inputTokens: record.inputTokens ?? 0,
    thinkingTokens: record.thinkingTokens ?? 0,
    outputTokens: record.outputTokens ?? 0,
    cachedTokens: record.cachedTokens ?? 0,
    totalTokens: record.totalTokens ?? 0,
    translateCharacters: record.translateCharacters ?? 0,
    errorCode: record.errorCode ?? null,
    createdAt: new Date().toISOString()
  };
}

function usageAggregateUpdate(record: AIUsageRecord): Record<string, unknown> {
  const providerKey = usageAggregateKey(record.provider);
  const modelKey = usageAggregateKey(record.model);
  const featureKey = usageAggregateKey(record.feature);
  return {
    date: usageDailyDocumentId(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    requests: admin.firestore.FieldValue.increment(1),
    errors: admin.firestore.FieldValue.increment(record.success ? 0 : 1),
    providers: {
      [providerKey]: {
        requests: admin.firestore.FieldValue.increment(1),
        errors: admin.firestore.FieldValue.increment(record.success ? 0 : 1)
      }
    },
    models: {
      [modelKey]: {
        requests: admin.firestore.FieldValue.increment(1)
      }
    },
    features: {
      [featureKey]: {
        requests: admin.firestore.FieldValue.increment(1)
      }
    },
    inputTokens: admin.firestore.FieldValue.increment(record.inputTokens ?? 0),
    thinkingTokens: admin.firestore.FieldValue.increment(record.thinkingTokens ?? 0),
    outputTokens: admin.firestore.FieldValue.increment(record.outputTokens ?? 0),
    cachedTokens: admin.firestore.FieldValue.increment(record.cachedTokens ?? 0),
    totalTokens: admin.firestore.FieldValue.increment(record.totalTokens ?? 0),
    translateCharacters: admin.firestore.FieldValue.increment(record.translateCharacters ?? 0)
  };
}

async function recordAIUsage(record: AIUsageRecord): Promise<void> {
  const config = await usageLoggingConfig();
  if (!config.enabled) return;

  const payload = usageRecordPayload(record);

  if (config.cloudLoggingEnabled) {
    logger.info("huitam_ai_usage", payload);
  }

  if (!config.firestoreAggregationEnabled) return;

  const date = usageDailyDocumentId();
  const db = admin.firestore();
  const writes: Promise<FirebaseFirestore.WriteResult>[] = [
    db.collection("aiUsageDaily").doc(date).set(usageAggregateUpdate(record), {merge: true}),
    db.collection("aiUsageDaily").doc(date).collection("features").doc(record.feature).set(
      usageAggregateUpdate(record),
      {merge: true}
    ),
    db.collection("aiUsageDaily").doc(date).collection("providers").doc(record.provider).set(
      usageAggregateUpdate(record),
      {merge: true}
    )
  ];

  if (record.uid) {
    writes.push(
      db.collection("aiUsageDaily").doc(date).collection("users").doc(record.uid).set(
        usageAggregateUpdate(record),
        {merge: true}
      )
    );
  }

  await Promise.all(writes);
}

async function safeRecordAIUsage(record: AIUsageRecord): Promise<void> {
  try {
    await recordAIUsage(record);
  } catch (error) {
    console.warn("AI usage logging failed", error);
  }
}

function normalizedNickname(data: unknown): string {
  const nickname = requiredString(data, "nickname").trim().toLowerCase();
  if (!/^[a-z0-9._-]{3,32}$/.test(nickname)) {
    throw new HttpsError("invalid-argument", "Nickname is invalid.");
  }
  return nickname;
}

function profilePayload(uid: string, profile: FirebaseFirestore.DocumentData | undefined): Record<string, unknown> {
  return {
    uid,
    nickname: profile?.nickname ?? `user-${uid.slice(0, 6)}`,
    displayName: profile?.displayName ?? "Friend",
    avatarSystemImage: profile?.avatarSystemImage ?? "person.crop.circle.fill",
    nativeLanguage: profile?.nativeLanguage ?? "english",
    learningLanguage: profile?.learningLanguage ?? null
  };
}

function profileLearningLanguage(profile: FirebaseFirestore.DocumentData | undefined): string | undefined {
  const learningLanguage = profile?.learningLanguage;
  return typeof learningLanguage === "string" && learningLanguage.trim().length > 0 ?
    learningLanguage :
    undefined;
}

function profileDisplayLanguage(profile: FirebaseFirestore.DocumentData | undefined): string {
  return messageDisplayLanguage({
    nativeLanguage: profile?.nativeLanguage,
    learningLanguage: profileLearningLanguage(profile)
  });
}

function timestampMillis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }

  return Date.now();
}

async function chatSummaryPayload(
  chatRef: FirebaseFirestore.DocumentReference,
  participantUid: string,
  currentUid: string
): Promise<Record<string, unknown>> {
  const [chatSnapshot, participantSnapshot, currentSnapshot] = await Promise.all([
    chatRef.get(),
    admin.firestore().collection("users").doc(participantUid).get(),
    admin.firestore().collection("users").doc(currentUid).get()
  ]);

  const chat = chatSnapshot.data();
  if (!chat) {
    throw new HttpsError("not-found", "Chat was not found.");
  }

  const unreadCounts = (chat.unreadCounts ?? {}) as Record<string, number>;
  const currentProfile = currentSnapshot.data();
  const participantProfile = participantSnapshot.data();
  const currentLearningLanguage = typeof currentProfile?.learningLanguage === "string" ?
    currentProfile.learningLanguage :
    undefined;
  const participantLearningLanguage = typeof participantProfile?.learningLanguage === "string" ?
    participantProfile.learningLanguage :
    undefined;
  return {
    chat: {
      id: chatRef.id,
      participantUID: participantUid,
      participant: profilePayload(participantUid, participantProfile),
      lastMessagePreview: chat.lastMessagePreview ?? "",
      updatedAtMillis: timestampMillis(chat.updatedAt),
      unreadCount: unreadCounts[currentUid] ?? 0,
      nativeLanguage: currentProfile?.nativeLanguage ?? "english",
      practiceLanguage: currentLearningLanguage ?? null,
      currentUserRole: currentLearningLanguage ?
        {kind: "learner", learningLanguage: currentLearningLanguage} :
        {kind: "companion"},
      participantRole: participantLearningLanguage ?
        {kind: "learner", learningLanguage: participantLearningLanguage} :
        {kind: "companion"}
    }
  };
}

export const openAccountChat = onCall({enforceAppCheck: false}, async (request) => {
  const uid = uidFromRequest(request);
  const nickname = normalizedNickname(request.data);
  const db = admin.firestore();

  const usernameSnapshot = await db.collection("usernames").doc(nickname).get();
  const friendUid = usernameSnapshot.data()?.uid;
  if (typeof friendUid !== "string") {
    throw new HttpsError("not-found", "This huitam account was not found.");
  }

  if (friendUid === uid) {
    throw new HttpsError("failed-precondition", "This is your own huitam link.");
  }

  const existingSnapshot = await db
    .collection("chats")
    .where("participantUIDs", "array-contains", uid)
    .get();
  const existingChat = existingSnapshot.docs.find((doc) => {
    const participantUids = doc.data().participantUIDs;
    return Array.isArray(participantUids) && participantUids.includes(friendUid);
  });

  if (existingChat) {
    return chatSummaryPayload(existingChat.ref, friendUid, uid);
  }

  const [currentProfileSnapshot, friendProfileSnapshot] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("users").doc(friendUid).get()
  ]);
  const currentProfile = currentProfileSnapshot.data();
  const friendProfile = friendProfileSnapshot.data();
  const chatId = [uid, friendUid].sort().join("_");
  const chatRef = db.collection("chats").doc(chatId);

  try {
    await chatRef.create({
      participantUIDs: [friendUid, uid],
      lastMessagePreview: "",
      unreadCounts: {
        [friendUid]: 0,
        [uid]: 0
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    const code = (error as {code?: number | string}).code;
    if (code !== 6 && code !== "already-exists") {
      throw error;
    }
  }

  return chatSummaryPayload(chatRef, friendUid, uid);
});

async function translateWithGoogle(
  text: string,
  sourceLanguage: string | undefined,
  targetLanguage: string,
  usageContext: AIUsageContext
): Promise<string> {
  const startedAt = Date.now();
  const translateCharacters = googleTranslateCharacterCount(text);
  try {
    const [response] = await translationClient.translateText({
      parent: `projects/${projectId}/locations/global`,
      contents: [text],
      mimeType: "text/plain",
      sourceLanguageCode: languageCode(sourceLanguage),
      targetLanguageCode: languageCode(targetLanguage)
    });

    const translatedText = response.translations?.[0]?.translatedText;
    if (!translatedText) {
      throw new HttpsError("internal", "Translation provider returned an empty response.");
    }

    await safeRecordAIUsage({
      ...usageContext,
      provider: "google-translate",
      model: "google-nmt",
      sourceLanguage,
      targetLanguage,
      success: true,
      latencyMs: Date.now() - startedAt,
      translateCharacters
    });
    return translatedText;
  } catch (error) {
    await safeRecordAIUsage({
      ...usageContext,
      provider: "google-translate",
      model: "google-nmt",
      sourceLanguage,
      targetLanguage,
      success: false,
      latencyMs: Date.now() - startedAt,
      translateCharacters,
      errorCode: error instanceof HttpsError ? error.code : error instanceof Error ? error.name : "unknown"
    });
    throw error;
  }
}

async function translateWithGemini(
  text: string,
  sourceLanguage: string | undefined,
  targetLanguage: string,
  model: string,
  contextMessages: string[],
  usageContext: AIUsageContext
): Promise<string> {
  const startedAt = Date.now();
  try {
    const result = await genAI.models.generateContent({
      model,
      contents: buildGeminiTranslationPrompt({
        text,
        sourceLanguage,
        targetLanguage,
        contextMessages
      }),
      config: {
        temperature: 0,
        maxOutputTokens: 512
      }
    });

    const translatedText = result.text?.trim();
    if (!translatedText) {
      throw new HttpsError("internal", "Gemini returned an empty translation.");
    }

    const usage = normalizeGeminiUsage(result.usageMetadata);
    await safeRecordAIUsage({
      ...usageContext,
      provider: "gemini",
      model,
      sourceLanguage,
      targetLanguage,
      success: true,
      latencyMs: Date.now() - startedAt,
      ...usage
    });
    return translatedText;
  } catch (error) {
    await safeRecordAIUsage({
      ...usageContext,
      provider: "gemini",
      model,
      sourceLanguage,
      targetLanguage,
      success: false,
      latencyMs: Date.now() - startedAt,
      errorCode: error instanceof HttpsError ? error.code : error instanceof Error ? error.name : "unknown"
    });
    throw error;
  }
}

async function translatedTextFromCache(
  text: string,
  sourceLanguage: string | undefined,
  targetLanguage: string,
  runtimeConfig: TranslationRuntimeConfig,
  contextMessages: string[],
  usageContext: AIUsageContext
): Promise<{translatedText: string; provider: TranslationProvider; cacheHit: boolean; cacheKey: string}> {
  const provider = runtimeConfig.provider;
  const model = provider === "google" ? "google-nmt" : runtimeConfig.geminiModel;
  const cacheKey = translationCacheKey({
    provider,
    model,
    promptVersion: provider === "gemini" ? runtimeConfig.promptVersion : undefined,
    sourceLanguage,
    targetLanguage,
    text,
    contextMessages: provider === "gemini" ? contextMessages : undefined
  });
  const cacheRef = admin.firestore().collection("translationCache").doc(cacheKey);
  const cachedSnapshot = await cacheRef.get();
  const cachedText = cachedSnapshot.data()?.translatedText;
  if (typeof cachedText === "string" && cachedText.length > 0) {
    return {
      translatedText: cachedText,
      provider,
      cacheHit: true,
      cacheKey
    };
  }

  const translatedText = provider === "google" ?
    await translateWithGoogle(text, sourceLanguage, targetLanguage, usageContext) :
    await translateWithGemini(text, sourceLanguage, targetLanguage, runtimeConfig.geminiModel, contextMessages, usageContext);

  await cacheRef.set({
    translatedText,
    provider,
    model,
    promptVersion: provider === "gemini" ? runtimeConfig.promptVersion : null,
    contextMessages: provider === "gemini" ? contextMessages : [],
    sourceLanguage: sourceLanguage ?? null,
    targetLanguage,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
    useCount: 1
  }, {merge: true});

  return {
    translatedText,
    provider,
    cacheHit: false,
    cacheKey
  };
}

function originalMessageText(message: FirebaseFirestore.DocumentData): string | undefined {
  const text = typeof message.originalText === "string" ? message.originalText.replace(/\s+/g, " ").trim() : "";
  return text.length > 0 ? text : undefined;
}

function recentContextFromMessageDocuments(
  documents: FirebaseFirestore.QueryDocumentSnapshot[],
  currentIndex: number
): string[] {
  return documents
    .slice(Math.max(0, currentIndex - 3), currentIndex)
    .map((document) => originalMessageText(document.data()))
    .filter((text): text is string => typeof text === "string");
}

async function recentChatContext(
  chatRef: FirebaseFirestore.DocumentReference,
  currentMessageId: string
): Promise<string[]> {
  const snapshot = await chatRef.collection("messages")
    .orderBy("createdAt", "desc")
    .limit(4)
    .get();
  return snapshot.docs
    .filter((document) => document.id !== currentMessageId)
    .slice(0, 3)
    .reverse()
    .map((document) => originalMessageText(document.data()))
    .filter((text): text is string => typeof text === "string");
}

async function translationForRecipient(
  originalText: string,
  sourceLanguage: string,
  targetLanguage: string,
  runtimeConfig: TranslationRuntimeConfig,
  contextMessages: string[],
  usageContext: AIUsageContext
): Promise<{
  translatedText: string;
  translationProvider: string;
  translationState: string;
  translationSkipReason?: string;
}> {
  const plan = runtimeConfig.enabled ?
    chooseTranslationPlan({
      text: originalText,
      sourceLanguage,
      targetLanguage,
      configuredProvider: runtimeConfig.provider
    }) :
    {kind: "skip" as const, reason: "non-text" as const, translatedText: originalText};

  if (plan.kind === "translate") {
    const cached = await translatedTextFromCache(plan.text, sourceLanguage, targetLanguage, {
      ...runtimeConfig,
      provider: plan.provider
    }, contextMessages, usageContext);
    await admin.firestore().collection("translationCache").doc(cached.cacheKey).set({
      lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      useCount: admin.firestore.FieldValue.increment(cached.cacheHit ? 1 : 0)
    }, {merge: true});

    return {
      translatedText: restoreProtectedSegments(cached.translatedText, plan.protectedSegments),
      translationProvider: cached.provider,
      translationState: "translated"
    };
  }

  return {
    translatedText: plan.translatedText,
    translationProvider: "none",
    translationState: "skipped",
    translationSkipReason: plan.reason
  };
}

type PushAvatarMetadata = {
  senderUID?: string;
  senderName?: string;
  avatarSymbol?: string;
  avatarColorHex?: string;
  avatarURL?: string;
};

function stableUUIDString(value: string): string {
  const bytes = Array.from(crypto.createHash("sha256").update(value).digest().subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`.toUpperCase();
}

function avatarColorHex(uid: string): string {
  const palette = ["#336BFF", "#5CB8A3", "#F5388F", "#8766FF", "#FF8C42", "#42D1EB"];
  const stableID = stableUUIDString(uid);
  const sum = Array.from(stableID).reduce((total, char) => total + char.codePointAt(0)!, 0);
  return palette[sum % palette.length];
}

function avatarSymbolName(symbol: unknown): string {
  const value = typeof symbol === "string" && symbol.trim().length > 0 ? symbol : "person.crop.circle.fill";
  return value.includes("person") ? "person.fill" : value;
}

async function sendPushNotification(
  recipientUid: string,
  chatId: string,
  preview: string,
  avatar: PushAvatarMetadata = {}
): Promise<number> {
  const tokensSnapshot = await admin.firestore()
    .collection("users")
    .doc(recipientUid)
    .collection("deviceTokens")
    .get();

  const tokens = tokensSnapshot.docs.map((doc) => doc.id);
  if (tokens.length === 0) {
    return 0;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: avatar.senderName ?? "New message",
      body: preview
    },
    data: {
      chatId,
      ...(avatar.senderUID ? {senderUID: avatar.senderUID} : {}),
      senderName: avatar.senderName ?? "New message",
      chatAvatarSymbol: avatar.avatarSymbol ?? "person.fill",
      chatAvatarColorHex: avatar.avatarColorHex ?? "#336BFF",
      ...(avatar.avatarURL ? {chatAvatarURL: avatar.avatarURL} : {})
    },
    apns: {
      payload: {
        aps: {
          mutableContent: true,
          threadId: chatId
        }
      }
    }
  });

  return response.successCount;
}

function notificationPreview(text: string): string {
  const trimmed = text.replace(/\s+/g, " ").trim();
  if (trimmed.length === 0) {
    return "Open huitam to read it.";
  }
  return trimmed.length > 120 ? `${trimmed.slice(0, 117)}...` : trimmed;
}

async function sendMessageNotification(
  messageRef: FirebaseFirestore.DocumentReference,
  recipientUid: string,
  senderUid: string,
  chatId: string,
  previewText: string
): Promise<void> {
  const [senderProfileSnapshot, senderAuthUser] = await Promise.all([
    admin.firestore().collection("users").doc(senderUid).get(),
    admin.auth().getUser(senderUid).catch(() => undefined)
  ]);
  const senderProfile = senderProfileSnapshot.data();

  const sent = await sendPushNotification(
    recipientUid,
    chatId,
    notificationPreview(previewText),
    {
      senderName: senderProfile?.displayName ?? senderProfile?.nickname ?? "New message",
      senderUID: senderUid,
      avatarSymbol: avatarSymbolName(senderProfile?.avatarSystemImage),
      avatarColorHex: avatarColorHex(senderUid),
      avatarURL: typeof senderProfile?.avatarURL === "string" ? senderProfile.avatarURL :
        typeof senderProfile?.photoURL === "string" ? senderProfile.photoURL :
          senderAuthUser?.photoURL
    }
  );

  await messageRef.set({
    notificationState: sent > 0 ? "sent" : "no_tokens",
    notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
  }, {merge: true});
}

export const notifyChatMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const message = snapshot.data();
  if (message.translationState === "pending") return;

  const senderUid = typeof message.senderUID === "string" ? message.senderUID : undefined;
  const originalText = typeof message.originalText === "string" ? message.originalText : "";
  if (!senderUid || originalText.trim().length === 0) return;

  const db = admin.firestore();
  const chatId = event.params.chatId;
  const [chatSnapshot, senderProfileSnapshot, senderAuthUser] = await Promise.all([
    db.collection("chats").doc(chatId).get(),
    db.collection("users").doc(senderUid).get(),
    admin.auth().getUser(senderUid).catch(() => undefined)
  ]);
  const chat = chatSnapshot.data();
  const senderProfile = senderProfileSnapshot.data();
  if (!chat) return;

  const participantUids = Array.isArray(chat.participantUIDs) ? chat.participantUIDs as string[] : [];
  const recipientUid = participantUids.find((uid) => uid !== senderUid);
  if (!recipientUid) return;

  try {
    const sent = await sendPushNotification(recipientUid, chatId, notificationPreview(originalText), {
      senderName: senderProfile?.displayName ?? senderProfile?.nickname ?? "New message",
      senderUID: senderUid,
      avatarSymbol: avatarSymbolName(senderProfile?.avatarSystemImage),
      avatarColorHex: avatarColorHex(senderUid),
      avatarURL: typeof senderProfile?.avatarURL === "string" ? senderProfile.avatarURL :
        typeof senderProfile?.photoURL === "string" ? senderProfile.photoURL :
          senderAuthUser?.photoURL
    });
    await snapshot.ref.set({
      notificationState: sent > 0 ? "sent" : "no_tokens",
      notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
  } catch (error) {
    console.error("notifyChatMessage failed", error);
    await snapshot.ref.set({
      notificationState: "failed",
      notificationError: error instanceof Error ? error.message : "Unknown notification error",
      notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
  }
});

export const processChatMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const message = snapshot.data();
  if (message.translationState !== "pending") return;

  const senderUid = typeof message.senderUID === "string" ? message.senderUID : undefined;
  const originalText = typeof message.originalText === "string" ? message.originalText : "";
  if (!senderUid || originalText.trim().length === 0) {
    await snapshot.ref.set({
      translationState: "failed",
      deliveryState: "failed",
      translationError: "Message text is empty.",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
    return;
  }

  const db = admin.firestore();
  const chatId = event.params.chatId;
  const chatRef = db.collection("chats").doc(chatId);

  try {
    const chatSnapshot = await chatRef.get();
    const chat = chatSnapshot.data();
    if (!chat) throw new Error("Chat was not found.");

    const participantUids = Array.isArray(chat.participantUIDs) ? chat.participantUIDs as string[] : [];
    const recipientUid = participantUids.find((uid) => uid !== senderUid);
    const [senderProfileSnapshot, recipientProfileSnapshot] = await Promise.all([
      db.collection("users").doc(senderUid).get(),
      recipientUid ? db.collection("users").doc(recipientUid).get() : Promise.resolve(undefined)
    ]);

    const senderProfile = senderProfileSnapshot.data();
    const recipientProfile = recipientProfileSnapshot?.data();
    const sourceLanguage = profileDisplayLanguage(senderProfile);
    const targetLanguage = recipientProfile ?
      profileDisplayLanguage(recipientProfile) :
      sourceLanguage;
    const runtimeConfig = await messageTranslationConfig();
    const contextMessages = await recentChatContext(chatRef, event.params.messageId);
    const translation = await translationForRecipient(originalText, sourceLanguage, targetLanguage, runtimeConfig, contextMessages, {
      feature: "message_translation",
      uid: recipientUid ?? senderUid,
      chatId,
      messageId: event.params.messageId,
      senderUid,
      recipientUid,
      sourceLanguage,
      targetLanguage
    });
    const translatedText = translation.translatedText;

    const displayTexts: Record<string, string> = {
      [senderUid]: originalText
    };
    if (recipientUid) {
      displayTexts[recipientUid] = translatedText;
    }

    const lastMessagePreviews: Record<string, string> = {
      [senderUid]: originalText
    };
    if (recipientUid) {
      lastMessagePreviews[recipientUid] = translatedText;
    }

    const batch = db.batch();
    batch.set(snapshot.ref, {
      translatedText,
      displayTexts,
      sourceLanguage,
      displayLanguages: recipientUid ? {[senderUid]: sourceLanguage, [recipientUid]: targetLanguage} : {[senderUid]: sourceLanguage},
      translationState: translation.translationState,
      translationProvider: translation.translationProvider,
      ...(translation.translationSkipReason ? {translationSkipReason: translation.translationSkipReason} : {}),
      visibleTo: recipientUid ? [senderUid, recipientUid] : [senderUid],
      deliveryState: "sent",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
    batch.set(chatRef, {
      lastMessagePreview: translatedText,
      lastMessagePreviews,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
    await batch.commit();

    if (recipientUid) {
      try {
        await sendMessageNotification(snapshot.ref, recipientUid, senderUid, chatId, translatedText);
      } catch (notificationError) {
        console.error("processChatMessage notification failed", notificationError);
        await snapshot.ref.set({
          notificationState: "failed",
          notificationError: notificationError instanceof Error ? notificationError.message : "Unknown notification error",
          notificationUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, {merge: true});
      }
    }

  } catch (error) {
    console.error("processChatMessage failed", error);
    await snapshot.ref.set({
      translationState: "failed",
      deliveryState: "failed",
      translationError: error instanceof Error ? error.message : "Translation failed.",
      visibleTo: senderUid ? [senderUid] : [],
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
  }
});

export const refreshUserMessageTranslations = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const beforeLanguage = profileDisplayLanguage(before);
  const afterLanguage = profileDisplayLanguage(after);
  if (beforeLanguage === afterLanguage) return;

  const uid = event.params.uid;
  const db = admin.firestore();
  const runtimeConfig = await messageTranslationConfig();
  const chatsSnapshot = await db.collection("chats")
    .where("participantUIDs", "array-contains", uid)
    .get();

  for (const chatDocument of chatsSnapshot.docs) {
    const chat = chatDocument.data();
    const participantUids = Array.isArray(chat.participantUIDs) ? chat.participantUIDs as string[] : [];
    const otherUid = participantUids.find((participantUid) => participantUid !== uid);
    if (!otherUid) continue;

    const otherProfileSnapshot = await db.collection("users").doc(otherUid).get();
    const otherProfile = otherProfileSnapshot.data();
    const sourceLanguage = profileDisplayLanguage(otherProfile);
    const messagesSnapshot = await chatDocument.ref.collection("messages")
      .orderBy("createdAt", "desc")
      .limit(200)
      .get();

    const messageDocuments = [...messagesSnapshot.docs].reverse();
    let batch = db.batch();
    let batchCount = 0;
    for (let messageIndex = 0; messageIndex < messageDocuments.length; messageIndex += 1) {
      const messageDocument = messageDocuments[messageIndex];
      const message = messageDocument.data();
      if (message.senderUID !== otherUid) continue;
      const originalText = typeof message.originalText === "string" ? message.originalText : "";
      if (!originalText.trim()) continue;
      const contextMessages = recentContextFromMessageDocuments(messageDocuments, messageIndex);

      const translation = await translationForRecipient(originalText, sourceLanguage, afterLanguage, runtimeConfig, contextMessages, {
        feature: "message_translation_refresh",
        uid,
        chatId: chatDocument.id,
        messageId: messageDocument.id,
        senderUid: otherUid,
        recipientUid: uid,
        sourceLanguage,
        targetLanguage: afterLanguage
      });
      batch.set(messageDocument.ref, {
        [`displayTexts.${uid}`]: translation.translatedText,
        [`displayLanguages.${uid}`]: afterLanguage,
        [`translationProviders.${uid}`]: translation.translationProvider,
        [`translationStates.${uid}`]: translation.translationState,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, {merge: true});
      batchCount += 1;

      if (batchCount === 450) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }
  }
});

async function generateWithGemini(prompt: string, usageContext: AIUsageContext): Promise<string> {
  const model = "gemini-2.0-flash";
  const startedAt = Date.now();
  try {
    const result = await genAI.models.generateContent({
      model,
      contents: prompt,
      config: {
        temperature: 0.2,
        maxOutputTokens: 512
      }
    });

    const text = result.text?.trim();
    if (!text) {
      throw new HttpsError("internal", "Gemini returned an empty response.");
    }

    const usage = normalizeGeminiUsage(result.usageMetadata);
    await safeRecordAIUsage({
      ...usageContext,
      provider: "gemini",
      model,
      success: true,
      latencyMs: Date.now() - startedAt,
      ...usage
    });
    return text;
  } catch (error) {
    await safeRecordAIUsage({
      ...usageContext,
      provider: "gemini",
      model,
      success: false,
      latencyMs: Date.now() - startedAt,
      errorCode: error instanceof HttpsError ? error.code : error instanceof Error ? error.name : "unknown"
    });
    throw error;
  }
}

export const translateText = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const sourceLanguage = optionalString(request.data, "sourceLanguage");
  const targetLanguage = requiredString(request.data, "targetLanguage");
  const route = optionalString(request.data, "route") ?? "cloudTranslation";

  if (route === "gemini") {
    const translatedText = await generateWithGemini(
      `Translate the message into ${targetLanguage}. Return only the translation.\n\nMessage:\n${text}`,
      {
        feature: "manual_translate",
        uid,
        sourceLanguage,
        targetLanguage
      }
    );
    return {translatedText, targetLanguage, provider: "gemini"};
  }

  const translatedText = await translateWithGoogle(text, sourceLanguage, targetLanguage, {
    feature: "manual_translate",
    uid,
    sourceLanguage,
    targetLanguage
  });
  return {
    translatedText,
    targetLanguage,
    provider: "google-translate"
  };
});

export const analyzeMessage = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const language = optionalString(request.data, "language") ?? "english";
  const result = await generateWithGemini(
    `Analyze this ${language} message for a language learner. Return compact JSON with keys tokens, phraseSuggestions, grammarNotes. tokens must be objects with text, translation, partOfSpeech. grammarNotes must be objects with title and explanation. Message: ${text}`,
    {
      feature: "analyze_message",
      uid,
      targetLanguage: language
    }
  );

  try {
    return JSON.parse(result);
  } catch {
    return {
      tokens: [{text, translation: "", partOfSpeech: "Phrase"}],
      phraseSuggestions: [],
      grammarNotes: [{title: "Explanation", explanation: result}]
    };
  }
});

export const suggestReply = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  const targetLanguage = requiredString(request.data, "targetLanguage");
  const messagesValue = (request.data as Record<string, unknown>)?.messages;
  const messages: unknown[] = Array.isArray(messagesValue) ? messagesValue : [];
  const history = messages
    .slice(-12)
    .map((item: unknown) => {
      if (!item || typeof item !== "object") return "";
      const record = item as Record<string, unknown>;
      return `${record.direction ?? "message"}: ${record.text ?? ""}`;
    })
    .filter(Boolean)
    .join("\n");
  const suggestion = await generateWithGemini(
    `Write one natural short reply in ${targetLanguage}. Return only the reply.\n\nChat:\n${history}`,
    {
      feature: "suggest_reply",
      uid,
      targetLanguage
    }
  );
  return {suggestion};
});

export const correctDraft = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const targetLanguage = requiredString(request.data, "targetLanguage");
  const correctedText = await generateWithGemini(
    `Correct this ${targetLanguage} chat message. Preserve meaning and tone. Return only corrected text.\n\n${text}`,
    {
      feature: "correct_draft",
      uid,
      targetLanguage
    }
  );
  return {correctedText};
});

export const explainText = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const language = requiredString(request.data, "language");
  const explanation = await generateWithGemini(
    `Explain this ${language} phrase for a language learner. Be concise and practical.\n\n${text}`,
    {
      feature: "explain_text",
      uid,
      targetLanguage: language
    }
  );
  return {explanation};
});

export const startTrial = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  await admin.firestore()
    .collection("users")
    .doc(uid)
    .collection("private")
    .doc("entitlement")
    .set({
      status: "trial",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});

  return {
    status: "trial"
  };
});

export const sendChatNotification = onCall({enforceAppCheck: true}, async (request) => {
  uidFromRequest(request);
  const recipientUid = requiredString(request.data, "recipientUid");
  const chatId = requiredString(request.data, "chatId");
  const preview = requiredString(request.data, "preview");

  return {sent: await sendPushNotification(recipientUid, chatId, preview)};
});

async function deleteCollection(collection: FirebaseFirestore.CollectionReference): Promise<number> {
  let deleted = 0;
  while (true) {
    const snapshot = await collection.limit(300).get();
    if (snapshot.empty) {
      return deleted;
    }

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deleted += 1;
    });
    await batch.commit();
  }
}

async function deleteChat(chatRef: FirebaseFirestore.DocumentReference): Promise<void> {
  await deleteCollection(chatRef.collection("messages"));
  await chatRef.delete();
}

export const deleteAccount = onCall({enforceAppCheck: true}, async (request) => {
  const uid = uidFromRequest(request);
  const reason = requiredString(request.data, "reason").trim();
  if (reason.length < 3 || reason.length > 1000) {
    throw new HttpsError("invalid-argument", "Reason must be between 3 and 1000 characters.");
  }

  const db = admin.firestore();
  await db.collection("accountDeletionRequests").doc(uid).set({
    uid,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }, {merge: false});

  const chatsSnapshot = await db.collection("chats")
    .where("participantUIDs", "array-contains", uid)
    .get();
  await Promise.all(chatsSnapshot.docs.map((doc) => deleteChat(doc.ref)));

  const usernamesSnapshot = await db.collection("usernames")
    .where("uid", "==", uid)
    .get();
  await Promise.all(usernamesSnapshot.docs.map((doc) => doc.ref.delete()));

  const invitedSnapshot = await db.collection("invites")
    .where("inviterUID", "==", uid)
    .get();
  const guestInvitesSnapshot = await db.collection("invites")
    .where("guestUID", "==", uid)
    .get();
  const inviteRefs = new Map<string, FirebaseFirestore.DocumentReference>();
  invitedSnapshot.docs.forEach((doc) => inviteRefs.set(doc.id, doc.ref));
  guestInvitesSnapshot.docs.forEach((doc) => inviteRefs.set(doc.id, doc.ref));
  await Promise.all(Array.from(inviteRefs.values()).map((ref) => ref.delete()));

  const userRef = db.collection("users").doc(uid);
  await deleteCollection(userRef.collection("private"));
  await deleteCollection(userRef.collection("studyCards"));
  await deleteCollection(userRef.collection("deviceTokens"));
  await userRef.delete();

  await admin.auth().deleteUser(uid);
  return {deleted: true};
});
