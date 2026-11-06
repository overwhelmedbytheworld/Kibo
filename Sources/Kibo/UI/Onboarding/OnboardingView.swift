import AppKit
import SwiftUI
import KiboKit

/// Main presentation view for the Kibo first-launch onboarding experience.
/// Built using the `macos-motion-onboarding` engine: 120Hz MeshGradient, 3D pointer parallax,
/// GPU-accelerated particle emotion graphics, and strict spring physics.
public struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Namespace private var onboardingNamespace

    public init(viewModel: OnboardingViewModel = OnboardingViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Ambient Living Canvas: 120Hz MeshGradient
            AnimatedMeshBackground()

            // Translucent Window Material Backing
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, state: .active)

            VStack(spacing: 0) {
                // Header Bar
                headerBar

                Divider()
                    .opacity(0.3)

                // Dynamic Slide Stage
                ZStack {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeSlideView(namespace: onboardingNamespace)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 1.04)).combined(with: .move(edge: .leading))
                            ))
                    case .emojiMotion:
                        EmojiMotionSlideView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 1.04)).combined(with: .move(edge: .leading))
                            ))
                    case .searchDemo:
                        MockSearchSimulatorView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 1.04)).combined(with: .move(edge: .leading))
                            ))
                    case .expansionDemo:
                        MockExpansionSimulatorView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 1.04)).combined(with: .move(edge: .leading))
                            ))
                    case .permissions:
                        PermissionSlideView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 1.04)).combined(with: .move(edge: .leading))
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)

                Divider()
                    .opacity(0.3)

                // Footer Bar
                footerBar
            }
        }
        .frame(width: 700, height: 490)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .alert("Accessibility Access is Required", isPresented: $viewModel.showDegradedAlert) {
            Button("Stay & Authorize", role: .cancel) {
                viewModel.openSystemAccessibilitySettings()
            }
            Button("Continue in Limited Mode", role: .destructive) {
                viewModel.continueInLimitedMode()
            }
        } message: {
            Text("Without Accessibility access, Kibo cannot detect trigger aliases (:alias:) or paste emojis and snippets automatically into other apps. Core features will not work.")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Traffic light close hook
            Button {
                viewModel.skipOrClose()
            } label: {
                Circle()
                    .fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Close Onboarding")

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Welcome to Kibo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button("Skip") {
                viewModel.skipOrClose()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: 16) {
            // Fluid matched-geometry progress indicators
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule(style: .continuous)
                        .fill(step == viewModel.currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: step == viewModel.currentStep ? 24 : 7, height: 7)
                        .animation(.spatialMorph, value: viewModel.currentStep)
                }
            }

            Spacer()

            // Navigation Controls
            HStack(spacing: 10) {
                if viewModel.currentStep != .welcome {
                    Button("Back") {
                        viewModel.previous()
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                    .controlSize(.regular)
                }

                Button(viewModel.currentStep == .permissions ? "Get Started" : "Continue") {
                    viewModel.next()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

// MARK: - Slide 1: Welcome Slide

private struct WelcomeSlideView: View {
    var namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            // Animated App Badge with 3D Tilt
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.indigo, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.indigo.opacity(0.35), radius: 14, y: 6)

                Image(systemName: "command")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .hoverParallax(maxTiltDegrees: 5.0, specularBorder: true, cornerRadius: 22)

            VStack(spacing: 5) {
                Text("Your Keyboard, With Superpowers")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                Text("Kibo runs quietly in your Menu Bar, giving you universal emoji insertion, instant floating search, and automatic snippet expansions.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // 4 Capability Pillars with 3D Parallax Hover
            HStack(spacing: 10) {
                FeaturePill(
                    icon: "face.smiling.fill",
                    badge: "1,720+",
                    title: "Instant Emojis",
                    subtitle: "Type shortcodes anywhere.",
                    tintColor: .orange
                )

                FeaturePill(
                    icon: "magnifyingglass",
                    badge: "⌘⇧K",
                    title: "Universal Search",
                    subtitle: "Global floating panel.",
                    tintColor: .blue
                )

                FeaturePill(
                    icon: "text.badge.plus",
                    badge: ":alias:",
                    title: "Trigger Aliases",
                    subtitle: "In-place text expansion.",
                    tintColor: .indigo
                )

                FeaturePill(
                    icon: "lock.shield.fill",
                    badge: "Local",
                    title: "100% Private",
                    subtitle: "Zero cloud tracking.",
                    tintColor: .green
                )
            }
            .padding(.top, 4)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Ready in your Menu Bar whenever you need it.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let badge: String
    let title: String
    let subtitle: String
    let tintColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tintColor)

                Spacer()

                Text(badge)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(tintColor.opacity(0.12))
                    )
                    .foregroundStyle(tintColor)
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .hoverParallax(maxTiltDegrees: 4.0, specularBorder: true, cornerRadius: 12)
    }
}

// MARK: - Slide 2: Emoji & Emotion Graphics Slide

private struct EmojiMotionSlideView: View {
    @State private var activeEmoji: String = "🔥"
    @State private var activeAlias: String = ":fire:"
    @State private var searchInput: String = "fire"
    @State private var burstTrigger: Int = 0
    @State private var bounceScale: CGFloat = 1.0

    private struct QuickEmoji: Identifiable {
        let id = UUID()
        let emoji: String
        let alias: String
        let label: String
    }

    private let quickEmojis = [
        QuickEmoji(emoji: "🔥", alias: ":fire:", label: "Lit"),
        QuickEmoji(emoji: "🎉", alias: ":party:", label: "Celebrate"),
        QuickEmoji(emoji: "🚀", alias: ":rocket:", label: "Launch"),
        QuickEmoji(emoji: "🫡", alias: ":salute:", label: "Respect"),
        QuickEmoji(emoji: "❤️‍🔥", alias: ":heart_on_fire:", label: "Passion"),
        QuickEmoji(emoji: "☕️", alias: ":coffee:", label: "Caffeine")
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FEATURE 1: UNIVERSAL EMOJI ENGINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)

                    Text("Express Emotion Anywhere, Instantly")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("1,723+ Emojis")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                )
            }

            // Interactive Emotion Showcase Card with 3D Tilt
            ZStack {
                // Background Particle Burst Emitter
                EmojiParticleBurstEmitter(triggerCount: $burstTrigger, originEmoji: activeEmoji)

                VStack(spacing: 12) {
                    // Simulated App Text Field with Giant Emotion Graphic
                    HStack(spacing: 14) {
                        // Bouncing Hero Emoji
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.orange.opacity(0.2), Color.clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 40
                                    )
                                )
                                .frame(width: 72, height: 72)

                            Text(activeEmoji)
                                .font(.system(size: 44))
                                .scaleEffect(bounceScale)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("In any app (Slack, Xcode, Notes):")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Click any to burst")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.orange)
                            }

                            // Simulated Inline Insertion Field
                            HStack {
                                Text("This release is going to be ")
                                    .font(.system(size: 13, design: .default))
                                    .foregroundStyle(.primary)

                                Text(activeEmoji)
                                    .font(.system(size: 15))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.orange.opacity(0.18))
                                    )

                                Text(activeAlias)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    // Quick-Pick Emotion Chips
                    HStack(spacing: 8) {
                        ForEach(quickEmojis) { item in
                            Button {
                                triggerEmoji(item.emoji, alias: item.alias)
                            } label: {
                                HStack(spacing: 5) {
                                    Text(item.emoji)
                                        .font(.system(size: 14))
                                    Text(item.alias)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(item.emoji == activeEmoji ? .primary : .secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(item.emoji == activeEmoji ? Color.orange.opacity(0.2) : Color.primary.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(item.emoji == activeEmoji ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .hoverParallax(maxTiltDegrees: 4.0, specularBorder: true, cornerRadius: 16)

            Text("Type any shortcode like :fire: or press ⌘⇧K to search by natural keyword (\"fire\", \"salute\", \"coffee\") to insert anywhere on macOS.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func triggerEmoji(_ emoji: String, alias: String) {
        activeEmoji = emoji
        activeAlias = alias
        burstTrigger += 1
        SoundFeedback.playExpansionClick()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            bounceScale = 1.35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                bounceScale = 1.0
            }
        }
    }
}

// MARK: - Slide 3: Mock Search Simulator View

private struct MockSearchSimulatorView: View {
    @State private var query: String = "pr"
    @State private var selectedIndex: Int = 0
    @State private var hasSimulatedInsert: Bool = false

    private struct MockItem: Identifiable {
        let id = UUID()
        let name: String
        let alias: String
        let type: String
    }

    private let allItems = [
        MockItem(name: "PR Code Review Checklist", alias: ":pr:", type: "Code"),
        MockItem(name: "Client Follow-up Proposal", alias: ":client:", type: "Work"),
        MockItem(name: "Team Daily Standup Notes", alias: ":standup:", type: "Prompt"),
        MockItem(name: "Meeting Calendar Link", alias: ":cal:", type: "Link")
    ]

    private var filteredItems: [MockItem] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return allItems
        }
        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.alias.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FEATURE 2: UNIVERSAL INSERTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tint)

                    Text("Floating Search Panel")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                HStack(spacing: 3) {
                    KeyboardKey(symbol: "⌘")
                    KeyboardKey(symbol: "⇧")
                    KeyboardKey(symbol: "K")
                }
            }

            // Simulated Floating Panel Container with 3D Tilt
            VStack(spacing: 8) {
                // Search Input Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.tint)

                    TextField("Type to filter mock snippets…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Filter Demo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // Results list
                VStack(spacing: 4) {
                    ForEach(Array(filteredItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)

                                Text(item.alias)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if index == selectedIndex {
                                Button("↵ Insert") {
                                    simulateInsert()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                                .font(.system(size: 10, weight: .semibold))
                            } else {
                                Text(item.type)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(index == selectedIndex ? Color.accentColor.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedIndex = index
                            simulateInsert()
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .hoverParallax(maxTiltDegrees: 4.0, specularBorder: true, cornerRadius: 14)

            // Insertion Toast Feedback
            if hasSimulatedInsert {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Inserted directly into active application via ⌘V simulation!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text("Pressing Return immediately pastes the snippet into whatever app you were just typing in.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func simulateInsert() {
        withAnimation {
            hasSimulatedInsert = true
        }
        SoundFeedback.playExpansionClick()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                hasSimulatedInsert = false
            }
        }
    }
}

// MARK: - Slide 4: Mock Expansion Simulator View

private struct MockExpansionSimulatorView: View {
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FEATURE 3: IN-PLACE EXPANSION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.indigo)

                    Text("Zero-Click Trigger Aliases")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("Event Tap Active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.indigo.opacity(0.15))
                    )
            }

            // Simulated Text Editor Window with 3D Tilt
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Simulated App (Slack, Mail, Xcode, Terminal):")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Click button to trigger")
                        .font(.system(size: 10))
                        .foregroundStyle(.indigo)
                }

                HStack(spacing: 0) {
                    Text("Join our sync at ")
                        .font(.system(size: 13, design: .monospaced))
                    if isExpanded {
                        Text("https://zoom.us/j/987654321")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.indigo)
                    } else {
                        Text(":zoom:")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.indigo)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isExpanded ? Color.indigo.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )

                // Expansion Action Button
                HStack {
                    Button(isExpanded ? "Reset Simulator" : "Simulate Expansion") {
                        withAnimation(.spatialMorph) {
                            isExpanded.toggle()
                        }
                        if isExpanded {
                            SoundFeedback.playExpansionClick()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.regular)

                    Spacer()

                    if isExpanded {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.indigo)
                            Text("Replaced instantaneously without opening an app!")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .hoverParallax(maxTiltDegrees: 4.0, specularBorder: true, cornerRadius: 14)

            Text("Type any defined :alias: in any application on your Mac, and Kibo instantly backspaces and replaces it with your template.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Slide 5: Permission Slide View

private struct PermissionSlideView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            // Dynamic Shield Icon with Parallax
            ZStack {
                Circle()
                    .fill(viewModel.isAuthorized ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: viewModel.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(viewModel.isAuthorized ? Color.green : Color.orange)
            }
            .hoverParallax(maxTiltDegrees: 5.0, specularBorder: true, cornerRadius: 32)

            VStack(spacing: 4) {
                Text(viewModel.isAuthorized ? "Accessibility Access Granted" : "Grant Accessibility Access")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text("macOS requires Accessibility permission so Kibo can listen for triggers like :alias: and paste snippets and emojis directly into external applications.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            // Status Card
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("System Accessibility")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        if viewModel.isAuthorized {
                            Text("✓ Granted")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.15))
                                )
                        } else {
                            Text("Action Required")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }
                    }

                    Text("System Settings → Privacy & Security → Accessibility")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isVerifyingPermission {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else if !viewModel.isAuthorized {
                    Button("Authorize Now") {
                        viewModel.openSystemAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .hoverParallax(maxTiltDegrees: 3.0, specularBorder: true, cornerRadius: 12)

            if viewModel.isVerifyingPermission {
                Text("Checking permission status with macOS…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("You can review this guide anytime from Help → Welcome to Kibo.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Subcomponents

private struct KeyboardKey: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
    }
}
