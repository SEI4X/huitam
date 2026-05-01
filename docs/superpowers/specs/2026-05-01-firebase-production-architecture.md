# Firebase Production Architecture

## Goal

Move Huitam from local mocks to a Firebase-backed production slice while preserving the current native SwiftUI style and product idea: real chat with friends, optional learner mode, paid learner tools, and free companion usage.

## Runtime Boundaries

The iOS app owns presentation, local UI state, Apple-provided on-device translation where available, and direct Firestore reads/writes that are safe under Security Rules. Firebase owns identity, durable data, invite documents, notification tokens, and access control. Cloud Functions own all privileged operations: sending notifications, high-quality translation, AI correction/explanation, entitlement changes, anti-abuse checks, and provider calls through Google Cloud IAM.

## Firebase Products

- Firebase Auth: anonymous account at first launch, later upgrade to Apple/Google without changing user document ids.
- Firestore: profiles, settings, chats, messages, invites, study cards, entitlements, device tokens.
- Cloud Functions callable API: `translateText`, `analyzeMessage`, `suggestReply`, `correctDraft`, `explainText`, `sendChatNotification`.
- Cloud Messaging: APNs-backed push notifications. Client stores token; backend sends.
- App Check: App Attest with DeviceCheck fallback in release, debug provider in development.
- Crashlytics/Performance/Analytics: already linked; initialized by Firebase app bootstrap.

## Data Model

Firestore paths:

- `users/{uid}`: profile, onboarding state, public search fields, stats.
- `users/{uid}/private/settings`: app settings.
- `users/{uid}/private/entitlement`: subscription entitlement.
- `users/{uid}/deviceTokens/{token}`: FCM token metadata.
- `users/{uid}/studyCards/{cardId}`: saved learning cards.
- `chats/{chatId}`: participant ids, roles, languages, preview, updated timestamp.
- `chats/{chatId}/messages/{messageId}`: original text, translated text, sender uid, delivery state, optional correction.
- `invites/{inviteId}`: inviter uid, expected guest language, optional guest learning language, created/accepted state.
- `usernames/{normalizedNickname}`: uid lookup for friend search.

## Translation Policy

Simple message translation should prefer Apple Translation when a local session is available and the language pair is supported. High-quality chat translation, corrections, explanations, and grammar analysis go through Cloud Functions, authenticated through the Functions runtime service account. The backend chooses provider by cost/quality:

1. Apple local translation: cheapest/private, best for simple user-visible text when available on device.
2. Google Cloud Translation or equivalent: default for accurate chat translation.
3. Vertex AI Gemini: only for correction, explanation, ambiguity, phrase suggestions, and natural reply help.

## Security

Clients never write other users' profiles, entitlements, notification sends, or API-provider requests directly. Firestore rules allow chat reads/writes only to participants, study cards only to owner, settings only to owner, and invites only to creator/claimed guest. Functions validate `context.auth`, enforce rate limits, check App Check in production, and use Firebase Admin SDK for privileged writes.

## Rollout

This implementation keeps mock classes for tests and previews, but app runtime uses `AppDependencyContainer.production()`. The first production slice signs in anonymously and creates/reads real Firestore documents. Apple/Google account linking, StoreKit subscription verification, and a camera QR scanner are separate vertical slices on top of this foundation.

## Release Setup

Before a TestFlight build can fully use production Firebase, configure the Firebase project from the same account as `GoogleService-Info.plist`:

- Add a `.firebaserc` project alias or pass `--project <project-id>` to Firebase CLI.
- Deploy rules, indexes, and Functions: `firebase deploy --only firestore:rules,firestore:indexes,functions`.
- Enable Firebase Auth anonymous sign-in, Firestore, Cloud Functions, Cloud Messaging, and App Check.
- Enable Google Cloud Translation API and Vertex AI API.
- Grant the Functions runtime service account IAM access to Cloud Translation and Vertex AI.
- Register the debug App Check token printed by the simulator before testing callable Functions locally against production.
- Upload APNs key/certificate for Cloud Messaging before relying on push notifications on devices.
