import {TranslationServiceClient} from "@google-cloud/translate";
import {GoogleGenAI} from "@google/genai";
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
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

type RoleData = {
  kind: "learner" | "companion";
  learningLanguage?: string;
};

function normalizedNickname(data: unknown): string {
  const nickname = requiredString(data, "nickname").trim().toLowerCase();
  if (!/^[a-z0-9._-]{3,32}$/.test(nickname)) {
    throw new HttpsError("invalid-argument", "Nickname is invalid.");
  }
  return nickname;
}

function roleFromData(data: unknown): RoleData {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "role is required.");
  }

  const record = data as Record<string, unknown>;
  if (record.kind === "companion") {
    return {kind: "companion"};
  }

  if (record.kind === "learner" && typeof record.learningLanguage === "string") {
    return {
      kind: "learner",
      learningLanguage: record.learningLanguage
    };
  }

  throw new HttpsError("invalid-argument", "role is invalid.");
}

function roleForProfile(profile: FirebaseFirestore.DocumentData | undefined): RoleData {
  const learningLanguage = profile?.learningLanguage;
  if (typeof learningLanguage === "string" && learningLanguage.length > 0) {
    return {
      kind: "learner",
      learningLanguage
    };
  }

  return {kind: "companion"};
}

function messageLanguage(role: RoleData | undefined, nativeLanguage: string | undefined): string {
  return role?.learningLanguage ?? nativeLanguage ?? "english";
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
  const [chatSnapshot, participantSnapshot] = await Promise.all([
    chatRef.get(),
    admin.firestore().collection("users").doc(participantUid).get()
  ]);

  const chat = chatSnapshot.data();
  if (!chat) {
    throw new HttpsError("not-found", "Chat was not found.");
  }

  const roles = (chat.roles ?? {}) as Record<string, RoleData>;
  const unreadCounts = (chat.unreadCounts ?? {}) as Record<string, number>;
  return {
    chat: {
      id: chatRef.id,
      participantUID: participantUid,
      participant: profilePayload(participantUid, participantSnapshot.data()),
      lastMessagePreview: chat.lastMessagePreview ?? "",
      updatedAtMillis: timestampMillis(chat.updatedAt),
      unreadCount: unreadCounts[currentUid] ?? 0,
      nativeLanguage: chat.nativeLanguage ?? "english",
      practiceLanguage: chat.practiceLanguage ?? null,
      currentUserRole: roles[currentUid] ?? {kind: "companion"},
      participantRole: roles[participantUid] ?? {kind: "companion"}
    }
  };
}

export const openAccountChat = onCall({enforceAppCheck: false}, async (request) => {
  const uid = uidFromRequest(request);
  const nickname = normalizedNickname(request.data);
  const currentRole = roleFromData((request.data as Record<string, unknown>).role);
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
  const friendRole = roleForProfile(friendProfile);
  const chatId = [uid, friendUid].sort().join("_");
  const chatRef = db.collection("chats").doc(chatId);

  try {
    await chatRef.create({
      participantUIDs: [friendUid, uid],
      roles: {
        [friendUid]: friendRole,
        [uid]: currentRole
      },
      nativeLanguage: currentProfile?.nativeLanguage ?? "english",
      practiceLanguage: currentRole.learningLanguage ?? null,
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

export const notifyChatMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const message = snapshot.data();
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
    const sent = await sendPushNotification(
      recipientUid,
      chatId,
      notificationPreview(originalText),
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
    const roles = (chat.roles ?? {}) as Record<string, RoleData>;

    const [senderProfileSnapshot, recipientProfileSnapshot] = await Promise.all([
      db.collection("users").doc(senderUid).get(),
      recipientUid ? db.collection("users").doc(recipientUid).get() : Promise.resolve(undefined)
    ]);

    const senderProfile = senderProfileSnapshot.data();
    const recipientProfile = recipientProfileSnapshot?.data();
    const sourceLanguage = messageLanguage(roles[senderUid], senderProfile?.nativeLanguage);
    const targetLanguage = messageLanguage(
      recipientUid ? roles[recipientUid] : undefined,
      recipientProfile?.nativeLanguage ?? sourceLanguage
    );
    const translatedText = sourceLanguage === targetLanguage ?
      originalText :
      await translateWithGoogle(originalText, sourceLanguage, targetLanguage);

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
      translationState: "translated",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
    batch.set(chatRef, {
      lastMessagePreview: translatedText,
      lastMessagePreviews,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
    await batch.commit();

  } catch (error) {
    console.error("processChatMessage failed", error);
    await snapshot.ref.set({
      translationState: "failed",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, {merge: true});
  }
});

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
