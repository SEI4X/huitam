# Language Chat Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first production-ready SwiftUI foundation for the language chat app using mock services behind real protocols.

**Architecture:** MVVM with explicit dependency injection. Views call testable ViewModels, ViewModels depend only on service protocols, and mock services can be replaced by live services without changing feature UI.

**Tech Stack:** SwiftUI, XCTest, async/await, system iOS components, SF Symbols, Xcode project file-system synchronized groups.

---

## File Structure

Create focused files under `huitam/App`, `huitam/Core`, `huitam/DesignSystem`, `huitam/Features`, and `huitam/Mocks`. Replace the default SwiftData sample files with the app shell.

Create tests under `huitamTests` for ViewModel behavior. UI views are verified by compiler and simulator build in this slice.

## Task 1: Core Contracts And Tests

**Files:**
- Create: `huitam/Core/Models/AppLanguage.swift`
- Create: `huitam/Core/Models/ChatModels.swift`
- Create: `huitam/Core/Models/ProfileModels.swift`
- Create: `huitam/Core/Models/StudyCardModels.swift`
- Create: `huitam/Core/Models/SettingsModels.swift`
- Create: `huitam/Core/Services/*.swift`
- Create: `huitamTests/ChatViewModelTests.swift`
- Create: `huitamTests/SettingsViewModelTests.swift`

- [ ] Write failing tests for chat loading, draft sending, original reveal, message analysis, saving cards, and learning-mode gating.
- [ ] Run targeted tests and verify they fail because production types do not exist.
- [ ] Add domain models and service protocols.
- [ ] Add ViewModel shells needed by the tests.
- [ ] Run targeted tests and keep iterating until they pass.

## Task 2: Mock Services And Dependency Container

**Files:**
- Create: `huitam/App/AppDependencyContainer.swift`
- Create: `huitam/App/AppEnvironment.swift`
- Create: `huitam/Mocks/MockAppData.swift`
- Create: `huitam/Mocks/Mock*.swift`
- Modify: `huitam/huitamApp.swift`

- [ ] Write failing tests for settings persistence and study card mutation through mock services.
- [ ] Implement mock services as protocol-conforming in-memory services.
- [ ] Add `AppDependencyContainer.mock()`.
- [ ] Wire the app entrypoint to the dependency container.
- [ ] Run targeted tests.

## Task 3: Motion And Shared Components

**Files:**
- Create: `huitam/DesignSystem/Motion/AppMotion.swift`
- Create: `huitam/DesignSystem/Components/AvatarView.swift`
- Create: `huitam/DesignSystem/Components/ToolbarIconButton.swift`
- Create: `huitam/DesignSystem/Components/EmptyStateView.swift`

- [ ] Add centralized motion presets with Reduce Motion support.
- [ ] Add small system-style components used by multiple screens.
- [ ] Build the app target to catch SwiftUI composition errors.

## Task 4: Chats List

**Files:**
- Create: `huitam/Features/ChatsList/ChatsListView.swift`
- Create: `huitam/Features/ChatsList/ChatsListViewModel.swift`
- Create: `huitam/Features/ChatsList/ChatRowView.swift`
- Create: `huitamTests/ChatsListViewModelTests.swift`
- Modify: `huitam/ContentView.swift`

- [ ] Write failing tests for loading chat summaries and sheet routing.
- [ ] Implement `ChatsListViewModel`.
- [ ] Build `ChatsListView` with profile, cards, and add-friend toolbar buttons.
- [ ] Use animated row transitions and system navigation.
- [ ] Run tests.

## Task 5: Chat Detail

**Files:**
- Create: `huitam/Features/Chat/ChatView.swift`
- Create: `huitam/Features/Chat/ChatViewModel.swift`
- Create: `huitam/Features/Chat/MessageBubbleView.swift`
- Create: `huitam/Features/Chat/MessageOriginalDisclosureView.swift`
- Create: `huitam/Features/Chat/MessageAnalysisSheet.swift`
- Create: `huitam/Features/Chat/ChatInputBarView.swift`
- Create: `huitam/Features/Chat/AIWritingHelpSheet.swift`

- [ ] Extend failing tests for send, AI suggestion, analysis, token selection, and save-to-cards.
- [ ] Implement `ChatViewModel`.
- [ ] Build Messages-like chat UI with animated bubbles, scroll transitions, original reveal, analysis sheet, and Grok-like input bar.
- [ ] Run tests and app build.

## Task 6: Profile, Settings, Study Cards, Add Friend

**Files:**
- Create: `huitam/Features/Profile/*.swift`
- Create: `huitam/Features/Settings/*.swift`
- Create: `huitam/Features/StudyCards/*.swift`
- Create: `huitam/Features/AddFriend/*.swift`
- Create: `huitamTests/ProfileViewModelTests.swift`
- Create: `huitamTests/StudyCardsViewModelTests.swift`
- Create: `huitamTests/AddFriendViewModelTests.swift`

- [ ] Write failing ViewModel tests for each feature.
- [ ] Implement ViewModels against service protocols.
- [ ] Build minimal, system-style screens with animated state changes.
- [ ] Run tests.

## Task 7: Verification

**Files:**
- No new files expected.

- [ ] Run `xcodebuild test -project huitam.xcodeproj -scheme huitam -destination 'platform=iOS Simulator,name=iPhone 17'`.
- [ ] If simulator name is unavailable, use XcodeBuildMCP to list simulators and run against an available iOS simulator.
- [ ] Run simulator build.
- [ ] Launch the app and capture a screenshot if simulator tooling is available.
- [ ] Fix any failures before reporting completion.

## Self-Review

Spec coverage:

- MVVM, service protocols, mocks, motion, chat list, chat screen, profile, settings, study cards, add friend, and tests are covered.

Placeholder scan:

- No implementation placeholders are intentionally left in the plan.

Type consistency:

- Feature names and service names match the design document.
