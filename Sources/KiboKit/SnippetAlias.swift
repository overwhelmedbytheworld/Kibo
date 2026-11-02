import Foundation

/// Rules for snippet aliases. Logic lives in this library so tests can run
/// it without the app.
public enum SnippetAlias {
    /// Validates an alias: must start and end with `:`, contain only
    /// lowercase letters, digits, and hyphens between the colons, and be
    /// at least 3 characters inside (e.g. `:abc:`).
    public static func isValid(_ alias: String) -> Bool {
        let trimmed = alias.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 5,
              trimmed.hasPrefix(":"),
              trimmed.hasSuffix(":") else { return false }
        let inner = trimmed.dropFirst().dropLast()
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        return inner.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Cleans an alias: lowercases, trims whitespace, and wraps in colons
    /// if not already present. Returns nil if the result is invalid.
    public static func clean(_ text: String) -> String? {
        var alias = text
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        if !alias.hasPrefix(":") { alias = ":" + alias }
        if !alias.hasSuffix(":") { alias = alias + ":" }
        return isValid(alias) ? alias : nil
    }
}
