import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: OnboardingStep = .hook
    @FocusState private var isNicknameFocused: Bool

    let viewModel: OnboardingViewModel
    let container: AppDependencyContainer

    private var canMoveForward: Bool {
        switch step {
        case .nickname:
            viewModel.isNicknameValid
        case .hook, .howItWorks, .nativeLanguage, .learningLanguage, .notifications:
            true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumScreenBackground(glowPosition: .bottom, intensity: 0.86, isAnimated: true)
                    .ignoresSafeArea()

                ZStack(alignment: .top) {
                    scrollingContent

                    OnboardingProgressView(step: step)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .padding(.bottom, 18)
                        .background(alignment: .top) {
                            TopProgressFade()
                        }
                        .zIndex(2)

                    VStack {
                        Spacer()
                        BottomControlsFade()
                            .frame(height: viewModel.errorMessage == nil ? 126 : 178)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)

                    VStack {
                        Spacer()
                        bottomControls
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                            .id("controls-\(step.rawValue)")
                            .premiumEntrance(delay: 0.34, edge: .bottom)
                    }
                    .zIndex(2)
                }
            }
            .navigationTitle("Huitam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .task {
                isNicknameFocused = step == .nickname
            }
            .onChange(of: step) { _, newStep in
                isNicknameFocused = newStep == .nickname
            }
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.isNicknameValid)
            .animation(AppMotion.quickStateChange(reduceMotion: reduceMotion), value: viewModel.errorMessage)
        }
    }

    @ViewBuilder
    private var scrollingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: step == .nickname ? 28 : 22) {
                OnboardingAnimatedHeader(step: step, isCompact: step != .nickname)
                    .id("header-\(step.rawValue)")

                stepFields
                    .id(step)
                    .transition(stepTransition)
            }
            .padding(.horizontal, 24)
            .padding(.top, 82)
            .padding(.bottom, viewModel.errorMessage == nil ? 126 : 178)
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 72)

                Rectangle()
                    .fill(.black)

                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 122)
            }
        }
        .animation(AppMotion.sheetPresent(reduceMotion: reduceMotion), value: step)
    }

    @ViewBuilder
    private var stepFields: some View {
        switch step {
        case .hook:
            OnboardingHookStepView()
        case .howItWorks:
            HowItWorksStepView()
        case .nickname:
            NicknameStepView(viewModel: viewModel, isFocused: $isNicknameFocused)
        case .nativeLanguage:
            LanguageStepView(
                selectedLanguage: Binding(
                    get: { viewModel.nativeLanguage },
                    set: { viewModel.nativeLanguage = $0 }
                ),
                highlightedLanguage: nil
            )
        case .learningLanguage:
            LearningLanguageStepView(viewModel: viewModel)
        case .notifications:
            NotificationPermissionStepView()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if let errorMessage = viewModel.errorMessage {
                OnboardingErrorBanner(message: errorMessage)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                if step != .hook {
                    Button {
                        moveBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(PremiumTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(PremiumTheme.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Button {
                    moveForward()
                } label: {
                    HStack(spacing: 10) {
                        Text(primaryButtonTitle)
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: step == .notifications ? "bell.badge.fill" : "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(canMoveForward ? 1 : 0.42)
                }
                .buttonStyle(.plain)
                .disabled(canMoveForward == false || viewModel.isLoading)
            }
        }
    }

    private var primaryButtonTitle: String {
        if step == .notifications {
            return "Turn on notifications"
        }
        guard step == .learningLanguage else {
            return step.buttonTitle
        }
        return viewModel.learningSelection.isEnabled ? "Start practicing" : "Start chatting"
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.97)),
            removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.98))
        )
    }

    private func moveBack() {
        guard let previous = step.previous else { return }
        withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
            step = previous
        }
    }

    private func moveForward() {
        guard canMoveForward else { return }
        if let next = step.next {
            withAnimation(AppMotion.sheetPresent(reduceMotion: reduceMotion)) {
                step = next
                isNicknameFocused = false
            }
            return
        }

        Task {
            await viewModel.completeLearningChoice(requestNotifications: true)
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case hook
    case howItWorks
    case nickname
    case nativeLanguage
    case learningLanguage
    case notifications

    var title: String {
        switch self {
        case .hook: "Your language partner is already here"
        case .howItWorks: "How huitam works"
        case .nickname: "Choose your nickname"
        case .nativeLanguage: "Your language"
        case .learningLanguage: "Language to practice"
        case .notifications: "Stay in the conversation"
        }
    }

    var subtitle: String {
        switch self {
        case .hook:
            "Stop forcing practice into fake AI chats or awkward stranger calls."
        case .howItWorks:
            "Real messages become daily practice without making your friends study."
        case .nickname:
            "This is what friends see when you invite them."
        case .nativeLanguage:
            "Messages from friends can stay natural on your side."
        case .learningLanguage:
            "Every real chat becomes daily practice in this language."
        case .notifications:
            "We will only use notifications for replies, invites, and moments that keep your practice alive."
        }
    }

    var symbolName: String {
        switch self {
        case .hook: "message.badge.waveform"
        case .howItWorks: "arrow.triangle.2.circlepath"
        case .nickname: "person.text.rectangle"
        case .nativeLanguage: "globe.europe.africa.fill"
        case .learningLanguage: "sparkles"
        case .notifications: "bell.badge.fill"
        }
    }

    var buttonTitle: String {
        switch self {
        case .hook: "Show me"
        case .howItWorks, .nickname, .nativeLanguage: "Next"
        case .learningLanguage: "Start practicing"
        case .notifications: "Turn on notifications"
        }
    }

    var next: OnboardingStep? {
        Self(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        Self(rawValue: rawValue - 1)
    }
}

private struct OnboardingProgressView: View {
    let step: OnboardingStep

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let count = CGFloat(OnboardingStep.allCases.count)
            let segmentWidth = (proxy.size.width - spacing * (count - 1)) / count
            let completedCount = CGFloat(step.rawValue + 1)
            let progressWidth = segmentWidth * completedCount + spacing * max(0, completedCount - 1)

            ZStack(alignment: .leading) {
                progressMask
                    .fill(Color.white.opacity(0.10))

                PremiumTheme.calmGradient
                    .frame(width: proxy.size.width, height: 4)
                    .mask(progressMask)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: progressWidth)
                    }
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var progressMask: some Shape {
        OnboardingProgressMask(segmentCount: OnboardingStep.allCases.count, spacing: 8)
    }
}

private struct OnboardingProgressMask: Shape {
    let segmentCount: Int
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = CGFloat(segmentCount)
        let segmentWidth = (rect.width - spacing * (count - 1)) / count

        for index in 0..<segmentCount {
            let x = CGFloat(index) * (segmentWidth + spacing)
            let segmentRect = CGRect(x: x, y: rect.minY, width: segmentWidth, height: rect.height)
            path.addPath(
                RoundedRectangle(cornerRadius: rect.height / 2, style: .continuous)
                    .path(in: segmentRect)
            )
        }

        return path
    }
}

private struct OnboardingAnimatedHeader: View {
    let step: OnboardingStep
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 14 : 18) {
            OnboardingIcon(
                symbolName: step.symbolName,
                size: isCompact ? 58 : 78,
                symbolSize: isCompact ? 24 : 31
            )
                .premiumEntrance(delay: 0.02, edge: .top)

            VStack(spacing: isCompact ? 6 : 8) {
                Text(step.title)
                    .font(.system(size: isCompact ? 28 : 31, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .premiumEntrance(delay: 0.12, edge: .bottom)

                Text(step.subtitle)
                    .font(.system(size: isCompact ? 15 : 16, weight: .regular, design: .rounded))
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .premiumEntrance(delay: 0.22, edge: .bottom)
            }
        }
    }
}

private struct OnboardingIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let symbolName: String
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 1 + CGFloat(sin(time * 1.35)) * 0.035

            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.white.opacity(0.16 - Double(index) * 0.035), lineWidth: 1)
                        .scaleEffect(pulse + CGFloat(index) * 0.18)
                }

                Circle()
                    .fill(PremiumTheme.surfaceStrong)
                    .overlay {
                        Circle()
                            .stroke(PremiumTheme.hairline, lineWidth: 1)
                    }

                Image(systemName: symbolName)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: reduceMotion ? .default : .repeating, value: reduceMotion ? 0 : Int(time))
            }
            .frame(width: size, height: size)
            .shadow(color: PremiumTheme.blue.opacity(0.22), radius: 24, y: 12)
        }
        .accessibilityHidden(true)
    }
}

private struct OnboardingHookStepView: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HookPill(text: "No partner search", symbolName: "magnifyingglass")
                    .premiumEntrance(delay: 0.12, edge: .bottom)
                HookPill(text: "No fake topics", symbolName: "text.bubble")
                    .premiumEntrance(delay: 0.18, edge: .bottom)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Practice should not start with scheduling a stranger.")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("huitam turns the chats you already care about into language practice: real people, real context, real reasons to reply.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumSurface(cornerRadius: 28, strength: 1.08)
            .premiumEntrance(delay: 0.26, edge: .bottom)
        }
    }
}

private struct HookPill: View {
    let text: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay {
            Capsule()
                .stroke(PremiumTheme.hairline, lineWidth: 1)
        }
    }
}

private struct HowItWorksStepView: View {
    private let items = [
        HowItWorksItem(
            title: "Your friend writes normally",
            body: "They can use their own language. They do not need to learn anything.",
            symbolName: "bubble.left.and.bubble.right.fill"
        ),
        HowItWorksItem(
            title: "You practice in your target language",
            body: "Read and reply in the language you want to train every day.",
            symbolName: "globe"
        ),
        HowItWorksItem(
            title: "AI helps only when you need it",
            body: "Get a phrase, fix a mistake, or understand a message without leaving the chat.",
            symbolName: "sparkles"
        )
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.title) { index, item in
                HowItWorksRow(item: item, index: index + 1)
                    .premiumEntrance(delay: 0.12 + Double(index) * 0.16, edge: .bottom)
            }
        }
    }
}

private struct HowItWorksItem {
    let title: String
    let body: String
    let symbolName: String
}

private struct HowItWorksRow: View {
    let item: HowItWorksItem
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(PremiumTheme.calmGradient)
                Text("\(index)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: item.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)

                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text(item.body)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumSurface(cornerRadius: 22, strength: 1)
    }
}

private struct NotificationPermissionStepView: View {
    var body: some View {
        VStack(spacing: 14) {
        NotificationReasonCard(
            title: "Replies should not wait",
            detail: "When a friend answers, you can continue the real conversation while the context is still alive.",
            symbolName: "message.badge.fill"
        )
            .premiumEntrance(delay: 0.12, edge: .bottom)

        NotificationReasonCard(
            title: "Invites need a clean handoff",
            detail: "If someone joins from your link or QR code, you will know the chat is ready.",
            symbolName: "person.badge.plus.fill"
        )
            .premiumEntrance(delay: 0.24, edge: .bottom)

            Text("You can change this later in Settings.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(PremiumTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
                .premiumEntrance(delay: 0.36, edge: .bottom)
        }
    }
}

private struct NotificationReasonCard: View {
    let title: String
    let detail: String
    let symbolName: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(PremiumTheme.surfaceStrong, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(PremiumTheme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumSurface(cornerRadius: 22, strength: 1)
    }
}

private struct NicknameStepView: View {
    let viewModel: OnboardingViewModel
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("alex_2026", text: Binding(
                    get: { viewModel.nickname },
                    set: { viewModel.nickname = $0 }
                ))
                .focused(isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 18)
                .frame(height: 72)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(viewModel.isNicknameValid ? PremiumTheme.blue.opacity(0.65) : PremiumTheme.hairline, lineWidth: 1)
                }

                NicknameRuleRow(
                    isValid: viewModel.isNicknameValid,
                    text: viewModel.nicknameValidationMessage
                )
            }
            .padding(16)
            .premiumSurface(cornerRadius: 28, strength: 1.12)
            .premiumEntrance(delay: 0.16, edge: .bottom)

            Text("Your nickname must be unique. We will use it for search, invites, and QR links.")
                .font(.footnote)
                .foregroundStyle(PremiumTheme.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
                .premiumEntrance(delay: 0.28, edge: .bottom)
        }
    }
}

private struct NicknameRuleRow: View {
    let isValid: Bool
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isValid ? .green : .orange)
                .padding(.top, 2)

            Text(text)
                .font(.footnote)
                .foregroundStyle(isValid ? PremiumTheme.textSecondary : .orange.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LanguageStepView: View {
    @Binding var selectedLanguage: AppLanguage
    let highlightedLanguage: AppLanguage?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, language in
                LanguageChoiceButton(
                    language: language,
                    isSelected: selectedLanguage == language,
                    isHighlighted: highlightedLanguage == language
                ) {
                    withAnimation(.smooth(duration: 0.24)) {
                        selectedLanguage = language
                    }
                }
                .premiumEntrance(delay: 0.08 + Double(index) * 0.045, edge: .bottom)
            }
        }
    }
}

private struct LearningLanguageStepView: View {
    let viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 10) {
            NoLearningChoiceButton(isSelected: viewModel.learningSelection == .none) {
                withAnimation(.smooth(duration: 0.24)) {
                    viewModel.selectNoLearning()
                }
            }
            .premiumEntrance(delay: 0.08, edge: .bottom)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, language in
                    LanguageChoiceButton(
                        language: language,
                        isSelected: viewModel.learningSelection == .language(language),
                        isHighlighted: language == .english
                    ) {
                        withAnimation(.smooth(duration: 0.24)) {
                            viewModel.selectLearningLanguage(language)
                        }
                    }
                    .premiumEntrance(delay: 0.12 + Double(index) * 0.045, edge: .bottom)
                }
            }
        }
    }
}

private struct NoLearningChoiceButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "message")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .black : .white)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.white : Color.white.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("I'm not learning")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Use huitam as a regular private chat.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.78) : PremiumTheme.textSecondary)
                }

                Spacer(minLength: 10)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : PremiumTheme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                isSelected ? AnyShapeStyle(PremiumTheme.calmGradient) : AnyShapeStyle(PremiumTheme.surface),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.30) : PremiumTheme.hairline, lineWidth: 1)
            }
            .shadow(color: isSelected ? PremiumTheme.blue.opacity(0.18) : .black.opacity(0.18), radius: 16, y: 8)
            .scaleEffect(isSelected ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("I am not learning a language")
    }
}

private struct TopProgressFade: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.92),
                Color.black.opacity(0.58),
                Color.black.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 104)
        .ignoresSafeArea(edges: .top)
        .blur(radius: 10)
    }
}

private struct BottomControlsFade: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0),
                Color.black.opacity(0.58),
                Color.black.opacity(0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 8)
    }
}

private struct LanguageChoiceButton: View {
    let language: AppLanguage
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(language.shortCode)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .black : PremiumTheme.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.white : Color.white.opacity(0.08), in: Capsule())

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : PremiumTheme.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                }

                Text(language.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if isHighlighted {
                    Text("Default")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PremiumTheme.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(
                isSelected ? AnyShapeStyle(PremiumTheme.calmGradient) : AnyShapeStyle(PremiumTheme.surface),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.30) : PremiumTheme.hairline, lineWidth: 1)
            }
            .shadow(color: isSelected ? PremiumTheme.blue.opacity(0.18) : .black.opacity(0.18), radius: 16, y: 8)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.displayName)
    }
}

private struct OnboardingErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.42))
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.22, green: 0.04, blue: 0.06).opacity(0.64), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 1, green: 0.28, blue: 0.34).opacity(0.22), lineWidth: 1)
        }
    }
}

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(
            onboardingService: MockOnboardingService(),
            settingsService: MockSettingsService(),
            profileService: MockProfileService()
        ),
        container: .mock()
    )
}
