import Foundation

/// Rules for snippet aliases. Logic lives in this library so tests can run
/// it without the app.
public enum SnippetAlias {
    /// Result of evaluating an alias string.
    public enum ValidationResult: Equatable, Sendable {
        case valid
        case empty
        case missingColons
        case tooShort
        case invalidCharacters

        public var message: String {
            switch self {
            case .valid:
                return "Valid trigger alias"
            case .empty:
                return "Alias cannot be empty"
            case .missingColons:
                return "Must start and end with colons (e.g. :email:)"
            case .tooShort:
                return "Must have at least 2 characters between colons (e.g. :ai:)"
            case .invalidCharacters:
                return "Use only lowercase letters, numbers, hyphens (-), and underscores (_)"
            }
        }
    }

    /// Validates an alias with a detailed result.
    public static func validate(_ alias: String) -> ValidationResult {
        let trimmed = alias.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.hasPrefix(":") && trimmed.hasSuffix(":") && trimmed.count >= 2 else {
            return .missingColons
        }
        let inner = trimmed.dropFirst().dropLast()
        guard inner.count >= 2 else { return .tooShort }

        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-_"))

        guard inner.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return .invalidCharacters
        }
        return .valid
    }

    /// Returns true if the alias meets all syntax rules.
    public static func isValid(_ alias: String) -> Bool {
        validate(alias) == .valid
    }

    /// Normalises an alias: trims whitespace, lowercases, and wraps in colons.
    /// Returns nil if the resulting string is still invalid.
    public static func clean(_ text: String) -> String? {
        var alias = text
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        if !alias.hasPrefix(":") { alias = ":" + alias }
        if !alias.hasSuffix(":") { alias = alias + ":" }
        return isValid(alias) ? alias : nil
    }
}
