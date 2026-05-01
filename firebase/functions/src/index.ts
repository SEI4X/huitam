import {TranslationServiceClient} from "@google-cloud/translate";
import {GoogleGenAI} from "@google/genai";
import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

admin.initializeApp();

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "huitam-app";
const vertexLocation = process.env.VERTEX_LOCATION || "us-central1";
const translationClient = new TranslationServiceClient();
const genAI = new GoogleGenAI({
  vertexai: true,
  project: projectId,
  location: vertexLocation
});

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

async function translateWithGoogle(text: string, sourceLanguage: string | undefined, targetLanguage: string): Promise<string> {
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
  return translatedText;
}

async function generateWithGemini(prompt: string): Promise<string> {
  const result = await genAI.models.generateContent({
    model: "gemini-2.0-flash",
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
  return text;
}

export const translateText = onCall({enforceAppCheck: true}, async (request) => {
  uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const sourceLanguage = optionalString(request.data, "sourceLanguage");
  const targetLanguage = requiredString(request.data, "targetLanguage");
  const route = optionalString(request.data, "route") ?? "cloudTranslation";

  if (route === "gemini") {
    const translatedText = await generateWithGemini(
      `Translate the message into ${targetLanguage}. Return only the translation.\n\nMessage:\n${text}`
    );
    return {translatedText, targetLanguage, provider: "gemini"};
  }

  const translatedText = await translateWithGoogle(text, sourceLanguage, targetLanguage);
  return {
    translatedText,
    targetLanguage,
    provider: "google-translate"
  };
});

export const analyzeMessage = onCall({enforceAppCheck: true}, async (request) => {
  uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const language = optionalString(request.data, "language") ?? "english";
  const result = await generateWithGemini(
    `Analyze this ${language} message for a language learner. Return compact JSON with keys tokens, phraseSuggestions, grammarNotes. tokens must be objects with text, translation, partOfSpeech. grammarNotes must be objects with title and explanation. Message: ${text}`
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
  uidFromRequest(request);
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
    `Write one natural short reply in ${targetLanguage}. Return only the reply.\n\nChat:\n${history}`
  );
  return {suggestion};
});

export const correctDraft = onCall({enforceAppCheck: true}, async (request) => {
  uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const targetLanguage = requiredString(request.data, "targetLanguage");
  const correctedText = await generateWithGemini(
    `Correct this ${targetLanguage} chat message. Preserve meaning and tone. Return only corrected text.\n\n${text}`
  );
  return {correctedText};
});

export const explainText = onCall({enforceAppCheck: true}, async (request) => {
  uidFromRequest(request);
  const text = requiredString(request.data, "text");
  assertShortText(text);
  const language = requiredString(request.data, "language");
  const explanation = await generateWithGemini(
    `Explain this ${language} phrase for a language learner. Be concise and practical.\n\n${text}`
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

  const tokensSnapshot = await admin.firestore()
    .collection("users")
    .doc(recipientUid)
    .collection("deviceTokens")
    .get();

  const tokens = tokensSnapshot.docs.map((doc) => doc.id);
  if (tokens.length === 0) {
    return {sent: 0};
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: "New message",
      body: preview
    },
    data: {
      chatId
    }
  });

  return {sent: response.successCount};
});
