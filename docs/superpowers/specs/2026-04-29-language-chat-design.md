# Language Chat Foundation Design

## Purpose

Build the first production-ready foundation for an iOS language practice app where normal conversations with friends become daily language training.

The first version uses mock service implementations, but it is not a throwaway prototype. UI and ViewModels depend on service protocols, so real backend, translation, AI, persistence, notifications, friend search, and QR services can replace mocks without rewriting feature screens.

## Product Concept

Users practice a target language inside familiar chat flows.

- A friend writes in their own language.
- The learner reads the translated message in the language they are studying.
- The learner replies in the study language.
- The friend receives the reply translated into their own language.
- If the learner does not know a phrase or makes a mistake, AI helps inside the chat.
- Users can save words, phrases, and grammar notes from real messages into study cards.

The product removes the need to find a separate language partner. Existing friends become natural practice partners.

## First Slice

The first implementation slice builds these app areas on mock data:

- Chats list as the main screen.
- Chat detail screen with Messages-like bubbles, translated/original message display, message analysis, save-to-study actions, and AI writing help entry points.
- Profile screen with avatar, unique nickname, stats, streak, and settings access.
- Study cards screen with saved words, phrases, and grammar items.
- Add friend screen with nickname search, share action, and QR scan entry point.
- Settings screen with native language, learning language or no-learning mode, theme, and notification preferences.

The QR scanner, real account system, real AI calls, real translation, push notifications, and backend storage stay behind protocols and are represented by mocks in this slice.

## Design Principles

The interface should feel close to Apple Messages:

- Use system typography, system colors, SF Symbols, NavigationStack, lists, sheets, menus, and native controls.
- Avoid custom brand palettes and invented fonts in the first slice.
- Keep screens minimal and functional.
- Do not add explanatory marketing text inside the product UI.
- Keep chat and chat list dense, calm, and familiar.
- Use the Grok reference only for the input bar shape and command density: rounded multi-line input, compact tool buttons, microphone, send/assist action.

## Animation Requirements

Motion is a core requirement. Every meaningful state change must animate smoothly unless the user has enabled Reduce Motion.

Create a small motion layer in `DesignSystem/Motion`:

- `AppMotion.messageInsert`
- `AppMotion.bubbleReveal`
- `AppMotion.sheetPresent`
- `AppMotion.listRowTap`
- `AppMotion.inputFocus`
- `AppMotion.scrollBubbleDrift`
- `AppMotion.quickStateChange`

Use the motion layer instead of scattering unrelated `.animation(.default)` calls across feature files.

Required animated behavior:

- Chat rows appear, update, and respond to taps smoothly.
- Navigation and sheets use native animated transitions.
- New chat messages insert with a gentle spring.
- Message bubbles use `scrollTransition` on supported iOS versions to create subtle offset, scale, and opacity movement while scrolling.
- Revealing an original message expands the bubble height smoothly.
- Message analysis sheets appear from a direct user action with a lightweight transition.
- The input bar animates focus, height growth, send state, and AI helper visibility.
- Settings changes animate visible dependent controls, especially when learning mode is disabled.

Reduce Motion behavior:

- Keep layout transitions.
- Shorten or remove scale and drift effects.
- Avoid attention-grabbing spring motion.

## Architecture

Use MVVM with explicit dependency injection.

Views are responsible for layout, local visual state, and calling ViewModel intents.
ViewModels are responsible for screen state, business decisions, async flows, validation, and navigation state.
Services provide data and capabilities through protocols.
Mock services implement the same protocols as future production services.

High-level dependency flow:

```text
SwiftUI Views
  -> Feature ViewModels
    -> Service Protocols
      -> Mock Services now
      -> Live Service Implementations
```

ViewModels must not depend on SwiftData, URLSession, SwiftUI views, concrete mock types, or global singletons. They should be fully testable with fake services.

## App Composition

`huitamApp` creates an `AppDependencyContainer`.

The container exposes service protocol instances:

- `ChatServicing`
- `ProfileServicing`
- `StudyCardServicing`
- `FriendServicing`
- `TranslationServicing`
- `AIAssistServicing`
- `SettingsServicing`

For the first slice, the container returns mock implementations. Later, a runtime configuration can switch to live implementations.

Root navigation starts with `ChatsListView`.

Feature navigation should use simple, typed state:

- Push chat detail from selected chat.
- Present profile, study cards, add friend, and settings as native sheets or navigation destinations.
- Keep sheet selection enum-based rather than using multiple booleans.

## Domain Models

Core value models:

- `AppLanguage`: supported language metadata for the 10 languages.
- `UserProfile`: id, nickname, display name, avatar asset or initials, native language, learning language, stats, streak.
- `LearningLanguageSelection`: selected language or no-learning mode.
- `ChatSummary`: chat id, participant summary, last message preview, timestamp, unread count, language pair.
- `ChatParticipant`: id, nickname, display name, avatar data, native language, learning language.
- `ChatMessage`: id, chat id, sender, timestamp, translated text, original text, direction, delivery state, saved token ids.
- `MessageDirection`: incoming or outgoing.
- `MessageAnalysis`: tokenized words, phrase suggestions, grammar notes.
- `StudyCard`: id, source message id, type, front text, back text, note, language, created date.
- `StudyCardType`: word, phrase, grammar.
- `FriendSearchResult`: id, nickname, display name, avatar, native language, learning language.
- `AppThemePreference`: system, light, dark.
- `NotificationPreference`: enabled or disabled.

Use structs and enums for this slice. Introduce reference types only when a future persistence or identity requirement makes value types insufficient.

## Service Contracts

`ChatServicing`

- Load chat summaries.
- Load messages for a chat.
- Send a message in the learner language and return the translated message state.
- Reveal original text for a message if needed.
- Analyze a message into tokens, translation details, and grammar notes.

`ProfileServicing`

- Load and update the current profile.
- Provide stats and streak values.

`StudyCardServicing`

- Load saved cards.
- Save selected words, phrases, or grammar notes from a message analysis.
- Remove cards.

`FriendServicing`

- Search users by nickname.
- Provide share payload data.
- Provide QR scan entry point result in mock form.

`TranslationServicing`

- Translate outgoing and incoming text between supported languages.
- Keep the protocol independent from any vendor.

`AIAssistServicing`

- Suggest a reply.
- Correct a draft.
- Explain selected text or grammar.

`SettingsServicing`

- Load settings.
- Update native language, learning language, theme, and notification preference.

## Feature Structure

Use this file structure for the first implementation:

```text
huitam/
  App/
    huitamApp.swift
    AppDependencyContainer.swift
    AppEnvironment.swift
  Core/
    Models/
      AppLanguage.swift
      ChatModels.swift
      ProfileModels.swift
      StudyCardModels.swift
      SettingsModels.swift
    Services/
      ChatServicing.swift
      ProfileServicing.swift
      StudyCardServicing.swift
      FriendServicing.swift
      TranslationServicing.swift
      AIAssistServicing.swift
      SettingsServicing.swift
  DesignSystem/
    Components/
      AvatarView.swift
      ToolbarIconButton.swift
      EmptyStateView.swift
    Motion/
      AppMotion.swift
  Features/
    ChatsList/
      ChatsListView.swift
      ChatsListViewModel.swift
      ChatRowView.swift
    Chat/
      ChatView.swift
      ChatViewModel.swift
      MessageBubbleView.swift
      MessageOriginalDisclosureView.swift
      MessageAnalysisSheet.swift
      ChatInputBarView.swift
      AIWritingHelpSheet.swift
    Profile/
      ProfileView.swift
      ProfileViewModel.swift
      ProfileStatRowView.swift
    StudyCards/
      StudyCardsView.swift
      StudyCardsViewModel.swift
      StudyCardRowView.swift
    AddFriend/
      AddFriendView.swift
      AddFriendViewModel.swift
      FriendSearchRowView.swift
    Settings/
      SettingsView.swift
      SettingsViewModel.swift
  Mocks/
    MockAppData.swift
    MockChatService.swift
    MockProfileService.swift
    MockStudyCardService.swift
    MockFriendService.swift
    MockTranslationService.swift
    MockAIAssistService.swift
    MockSettingsService.swift
```

Tests:

```text
huitamTests/
  ChatsListViewModelTests.swift
  ChatViewModelTests.swift
  ProfileViewModelTests.swift
  StudyCardsViewModelTests.swift
  AddFriendViewModelTests.swift
  SettingsViewModelTests.swift
```

## File Size And Responsibility Rules

- Keep each View focused on one screen or one reusable component.
- Split large view sections into child views before a file becomes hard to scan.
- Keep ViewModels free of rendering code.
- Keep service protocols small enough that each one has one reason to change.
- Do not place domain models, mock data, ViewModels, and views in the same file.
- Prefer a focused new file over adding unrelated code to an existing file.

Target file size guidance:

- Component views: 40-120 lines.
- Screen views: 80-180 lines.
- ViewModels: 100-220 lines.
- Mock services: 60-180 lines.
- Model files can group related small value types, but should stay readable.

## Learning Mode Policy

Settings allow the user to choose no-learning mode.

When no-learning mode is active:

- Hide or disable study-specific actions.
- Do not show save-to-cards controls.
- Do not show grammar explanation actions as primary actions.
- Keep normal messaging and friend interactions available.
- ViewModels expose capability flags, such as `canUseStudyFeatures`, so Views do not duplicate policy logic.

## Testing Strategy

Use XCTest for ViewModel tests.

ViewModel tests cover:

- Chat summaries load from `ChatServicing`.
- Chat messages load in expected order.
- Sending a draft calls translation/chat services and inserts the outgoing message.
- Empty drafts cannot be sent.
- Original text reveal updates only the selected message state.
- Message analysis produces selectable tokens.
- Selected tokens save through `StudyCardServicing`.
- AI helper suggestions update draft state.
- Learning mode disables study actions.
- Profile stats and streak are mapped to display state.
- Settings updates persist through `SettingsServicing`.
- Add friend search handles empty query, results, and no results.
- Study cards filter by word, phrase, and grammar.

Tests use fake services with explicit inputs and recorded calls. UI snapshot tests are not required in the first slice.

## Implementation Order

1. Remove default SwiftData sample surface.
2. Add domain models and service protocols.
3. Add mock data and mock services.
4. Add dependency container and app environment.
5. Add motion presets and base design-system components.
6. Build Chats list screen and tests.
7. Build Chat screen, message bubbles, input bar, original reveal, AI helper, and tests.
8. Build Profile and Settings screens with tests.
9. Build Study Cards and Add Friend screens with tests.
10. Run unit tests and simulator build.

## Non-Goals For First Slice

- Real backend.
- Real authentication.
- Real translation provider.
- Real AI provider.
- Real QR camera scanner.
- Push notifications.
- SwiftData persistence.
- Payment or subscription flows.
- Full onboarding.

The architecture must leave room for these features, but the first slice should not implement them.
