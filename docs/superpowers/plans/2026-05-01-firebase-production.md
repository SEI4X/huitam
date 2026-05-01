# Firebase Production Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace app runtime mocks with Firebase-backed production services.

**Architecture:** Keep existing SwiftUI screens and service protocols. Add Firebase implementations behind the protocols, pure DTO mapping for testability, callable Cloud Functions for privileged translation/AI work, and Firestore rules for client-side safety.

**Tech Stack:** SwiftUI, Firebase Auth, Firestore, Functions, Messaging, App Check, TypeScript Cloud Functions.

---

### Task 1: Production Bootstrap

- [x] Add app defaults so production view models do not depend on mock sample data.
- [x] Add Firebase bootstrap with App Check, Messaging delegate, and FCM token persistence hook.
- [x] Switch app runtime to `AppDependencyContainer.production()`.

### Task 2: Firebase Data Layer

- [x] Add auth session helper that guarantees a Firebase user with anonymous sign-in.
- [x] Add Firestore async helpers and DTO mappers.
- [x] Add Firebase implementations for profile, settings, onboarding, chats, friends, study cards, subscription, translation, and AI assist.

### Task 3: Security And Backend Boundary

- [x] Add `firestore.rules`.
- [x] Add `firestore.indexes.json`.
- [x] Add `firebase.json`.
- [x] Add Cloud Functions TypeScript implementation with callable translation, AI endpoints, push notifications, App Check enforcement, and Google Cloud IAM provider access.

### Task 4: Verification

- [x] Add pure mapper/policy tests.
- [x] Run targeted tests.
- [x] Run full unit tests.
- [x] Build and launch on simulator.
