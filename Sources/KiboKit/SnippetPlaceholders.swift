import Foundation

/// Parser and substitute engine for template placeholders like `{{name}}` or `{{name:default}}`.
public enum SnippetPlaceholders {
    public struct Placeholder: Identifiable, Hashable, Sendable {
        public var id: String { key }
        public let key: String
        public let defaultValue: String?

        public init(key: String, defaultValue: String? = nil) {
            self.key = key
            self.defaultValue = defaultValue
        }
    }

    /// Regular expression pattern matching `{{key}}` or `{{key:default}}`.
    private static let placeholderRegex: NSRegularExpression = {
        // Matches {{key}} or {{key:default}}
        try! NSRegularExpression(pattern: #"\{\{\s*([a-zA-Z0-9_\-]+)(?:\s*:\s*([^}]*))?\s*\}\}"#)
    }()

    /// Extracts unique placeholders in order of appearance.
    public static func extract(from text: String) -> [Placeholder] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = placeholderRegex.matches(in: text, range: range)

        var seenKeys = Set<String>()
        var placeholders: [Placeholder] = []

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let keyRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let key = String(text[keyRange])

            var defaultValue: String? = nil
            if match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound,
               let defaultRange = Range(match.range(at: 2), in: text) {
                defaultValue = String(text[defaultRange]).trimmingCharacters(in: .whitespaces)
            }

            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                placeholders.append(Placeholder(key: key, defaultValue: defaultValue))
            }
        }
        return placeholders
    }

    /// Returns true if text contains at least one placeholder.
    public static func hasPlaceholders(_ text: String) -> Bool {
        !extract(from: text).isEmpty
    }

    /// Replaces all placeholders with the provided values (or default value if missing).
    public static func substitute(template: String, with values: [String: String]) -> String {
        let placeholders = extract(from: template)
        var result = template

        for p in placeholders {
            let replacement = values[p.key] ?? p.defaultValue ?? ""
            // Replace {{p.key}} and {{p.key:default}}
            let pattern = #"\{\{\s*"# + NSRegularExpression.escapedPattern(for: p.key) + #"(?:\s*:\s*[^}]*)?\s*\}\}"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
            }
        }
        return result
    }
}
