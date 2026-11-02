import AppKit
import AudioToolbox

/// Audio feedback manager for keyboard expansion actions.
public enum SoundFeedback {
    public static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "kibo.sound.enabled") == nil {
                return true // Enabled by default
            }
            return UserDefaults.standard.bool(forKey: "kibo.sound.enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kibo.sound.enabled")
        }
    }

    /// Plays a subtle, satisfying click/pop when a snippet or emoji expands.
    public static func playExpansionClick() {
        guard isEnabled else { return }
        // Subtle system keyboard tick / pop sound (ID 1057)
        AudioServicesPlaySystemSound(1057)
    }
}
