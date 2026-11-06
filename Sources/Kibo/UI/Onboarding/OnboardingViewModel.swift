import AppKit
import Foundation
import SwiftUI
import Observation

/// The five sequential steps in the Kibo onboarding flow.
public enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome = 0
    case emojiMotion = 1
    case searchDemo = 2
    case expansionDemo = 3
    case permissions = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .emojiMotion: return "Instant Emojis"
        case .searchDemo: return "Search & Insert"
        case .expansionDemo: return "Trigger Expansion"
        case .permissions: return "Permissions"
        }
    }
}

/// Coordinates state, navigation, two-stage skip protection, and permission detection for onboarding.
@MainActor
@Observable
public final class OnboardingViewModel {
    public var currentStep: OnboardingStep = .welcome
    public var showDegradedAlert: Bool = false
    public var isVerifyingPermission: Bool = false
    public var isAuthorized: Bool = false

    /// Closure invoked when onboarding completes or is dismissed to close the window.
    public var onComplete: (() -> Void)?

    @ObservationIgnored
    private nonisolated(unsafe) var activeObserver: NSObjectProtocol?

    public init() {
        self.isAuthorized = checkPermission()
        setupNotificationObserver()
    }

    deinit {
        if let observer = activeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.verifyPermissionWithFeedback()
            }
        }
    }

    /// Direct check for Accessibility permissions via AXIsProcessTrusted.
    public func checkPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Verifies permission status with a brief visual indicator when returning from System Settings.
    public func verifyPermissionWithFeedback() {
        guard currentStep == .permissions else {
            self.isAuthorized = checkPermission()
            return
        }

        isVerifyingPermission = true
        Task {
            // Short 350ms delay so the verification animation is visible and reassuring
            try? await Task.sleep(for: .milliseconds(350))
            self.isAuthorized = self.checkPermission()
            self.isVerifyingPermission = false
        }
    }

    /// Advances to the next slide.
    public func next() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.spatialMorph) {
                currentStep = nextStep
            }
            if currentStep == .permissions {
                verifyPermissionWithFeedback()
            }
        } else {
            finish()
        }
    }

    /// Navigates to the previous slide.
    public func previous() {
        if let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.spatialMorph) {
                currentStep = prevStep
            }
        }
    }

    /// Stage 1 & Stage 2 Skip Protection:
    /// - From Steps 0..3: Jumps directly to the Permission Gate (Stage 1).
    /// - From Step 4: If unauthorized, prompts with the Degraded Alert (Stage 2).
    public func skipOrClose() {
        if currentStep != .permissions {
            withAnimation(.spatialMorph) {
                currentStep = .permissions
            }
            verifyPermissionWithFeedback()
        } else {
            if isAuthorized {
                finish()
            } else {
                showDegradedAlert = true
            }
        }
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openSystemAccessibilitySettings() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// User confirmed continuing in Limited Mode despite the missing permission.
    public func continueInLimitedMode() {
        showDegradedAlert = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "onboarding.completedInLimitedMode")
        onComplete?()
    }

    /// Completes onboarding in normal mode.
    public func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "onboarding.completedInLimitedMode")
        onComplete?()
    }
}
