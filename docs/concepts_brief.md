# Kibo First-Launch Onboarding (`OnboardingWindow`)

* **Author:** Ayaansh & EGM Swarm
* **Date:** 2026-11-06
* **Status:** Finalized Concept Specification

## Overview

A dedicated, standalone native macOS window (680×460 pt) that activates automatically on Kibo's first launch. While Kibo primarily operates as an `LSUIElement` menu bar utility, this standalone window ensures the user experiences Kibo's core workflows—Universal Search (`⌘⇧K`) and Zero-Click Trigger Expansion (`:alias:`)—in interactive sandboxed previews, before resolving the mandatory macOS Accessibility (`AXIsProcessTrusted`) permission requirement.

## Analysis & Architectural Solutions

### 1. Window Presentation & Seamless Activation Policy
* **Launch Behavior:** On launch, if `@AppStorage("hasCompletedOnboarding") == false`, Kibo sets `NSApp.setActivationPolicy(.regular)`. This displays Kibo as a full foreground app with key window focus and temporary Dock representation.
* **Transition to Menu Bar:** Upon completion or dismissal, the onboarding window fades out via `NSAnimationContext.runAnimationGroup`. Only after the window orders out does Kibo invoke `NSApp.setActivationPolicy(.accessory)`, preventing any Dock jump or visual flicker on modern macOS releases (macOS 15 Sequoia, 16 Tahoe, and 17 Golden Gate).
* **Secondary Access:** Users can re-open the onboarding guide at any time from **Help → Welcome to Kibo** or from Settings.

### 2. Sandbox Previews (Live SwiftUI Components)
* **Slide 1: Welcome & Core Purpose**
  * Explains keyboard-first utility shape, local privacy, and menu bar operation.
* **Slide 2: Universal Floating Search (`⌘⇧K`)**
  * Interactive sandboxed search box with autofocus.
  * Real-time filtering across sample snippets (`:prreview:`, `:client:`) with instant substring highlighting and Return-key insert simulation.
* **Slide 3: Zero-Click Trigger Expansion (`:alias:`)**
  * Interactive inline text simulation.
  * Typing `:zoom:` or `:email:` triggers inline expansion with subtle accent pulse and haptic feedback.
  * Entirely isolated from production `GlobalTriggerEngine` and `CGEventTap`.

### 3. Strict 2-Stage Skip Protection
* **Stage 1 Skip (From Slides 1–3 via Skip Button or `Esc`):**
  * Intercepts dismissal and jumps immediately to **Slide 4 (Accessibility Permissions)**.
* **Stage 2 Skip / Window Close Attempt (From Slide 4):**
  * If `AXIsProcessTrusted() == false`, presents a native modal confirmation alert:
    * **Title:** *"Accessibility Access Is Required"*
    * **Body:** *"Without Accessibility permission, Kibo cannot detect trigger aliases (:alias:) or paste snippets into your active apps. Kibo's core capabilities will not work."*
    * **Action 1 (Default):** *"Authorize Now"* (Remains on Slide 4 and deep-links to System Settings).
    * **Action 2 (Destructive/Secondary):** *"Continue in Limited Mode"* (Completes onboarding, flags degraded state, closes window).

### 4. Permission Verification & Polling Architecture
* **Dual-Trigger Verification:**
  * Active Combine / Task loop polling at 0.5s intervals while Slide 4 is visible.
  * Immediate re-verification triggered by `NSApplication.didBecomeActiveNotification`.
* **Verification Loader Animation:**
  * When refocusing from System Settings, a transient 300ms verification spinner appears ("Checking permission status…") before resolving smoothly to the green checkmark (`✓ Granted`) or warning state.

### 5. Limited Mode Menu Bar Status Contract
* If the user insists on continuing without granting Accessibility:
  * Kibo marks `hasCompletedOnboarding = true` and enters Menu Bar mode.
  * The Menu Bar dropdown prominently displays an alert row:
    `⚠️ Accessibility: Not Granted (Triggers Inactive)`
  * Selecting this row immediately re-opens the Accessibility permission sheet or System Settings to restore full functionality.

## Goals vs. Non-Goals

* **In-Scope Goals:**
  * Native 680×460 pt liquid glass window conforming to Apple 4 pt grid rules.
  * Full keyboard navigation (`Return`, `Esc`, `⌘→`, `⌘←`, `Tab`).
  * 2-stage skip protection preventing silent feature failure.
  * Real-time permission checking with transient verification spinner.
  * Menu Bar warning row when operating in degraded mode.

* **Out-of-Scope Non-Goals:**
  * Forced app termination when permissions are refused (respects user agency).
  * Static raster assets (100% vector SF Symbols and reactive SwiftUI code).
  * Cloud accounts or network telemetry.

## Alternatives Weighed

* **Attached Sheet on Main Window (Rejected):** Incompatible with Kibo's primary menu bar utility shape; forces unnecessary window clutter on launch.
* **Immediate Process Termination (Rejected):** Violates Apple HIG Agency principles; allows basic manual snippet lookup in degraded mode.
* **Static PNG Screenshots (Rejected):** High maintenance burden across theme and appearance updates; replaced with lightweight live SwiftUI mini-components.

## Key Decisions & Staging for Next Steps

1. **Onboarding Window & Controller:** `OnboardingWindowController` handling window lifecycle, centering, and activation policy morphing.
2. **View State Machine:** `OnboardingViewModel` coordinating step navigation, 2-stage skip logic, and degraded alert presentation.
3. **Interactive Previews:** `MockSearchSimulatorView` and `MockExpansionSimulatorView`.
4. **Menu Bar Status Integration:** Exposing Accessibility authorization status in `MenuBarMenu`.
