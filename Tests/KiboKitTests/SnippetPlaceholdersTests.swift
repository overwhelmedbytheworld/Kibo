import Testing
@testable import KiboKit

@Suite("Snippet Placeholders Parsing and Substitution")
struct SnippetPlaceholdersTests {
    @Test func extractSinglePlaceholder() {
        let text = "Hi, my name is {{name}}."
        let placeholders = SnippetPlaceholders.extract(from: text)
        #expect(placeholders.count == 1)
        #expect(placeholders.first?.key == "name")
        #expect(placeholders.first?.defaultValue == nil)
    }

    @Test func extractMultiplePlaceholdersWithDefaults() {
        let text = "Hello {{name:John}}, please review {{doc:Report.pdf}} by {{date}}."
        let placeholders = SnippetPlaceholders.extract(from: text)
        #expect(placeholders.count == 3)
        #expect(placeholders[0].key == "name")
        #expect(placeholders[0].defaultValue == "John")
        #expect(placeholders[1].key == "doc")
        #expect(placeholders[1].defaultValue == "Report.pdf")
        #expect(placeholders[2].key == "date")
        #expect(placeholders[2].defaultValue == nil)
    }

    @Test func extractDeduplicatesIdenticalKeys() {
        let text = "{{name}} is great because {{name}} always helps."
        let placeholders = SnippetPlaceholders.extract(from: text)
        #expect(placeholders.count == 1)
        #expect(placeholders.first?.key == "name")
    }

    @Test func substituteReplacesVariables() {
        let template = "Hi, my name is {{name}} and I work on {{project}}."
        let result = SnippetPlaceholders.substitute(
            template: template,
            with: ["name": "Ayaansh", "project": "Kibo"]
        )
        #expect(result == "Hi, my name is Ayaansh and I work on Kibo.")
    }

    @Test func substituteFallsBackToDefaults() {
        let template = "Welcome to {{city:Tokyo}}, {{name}}!"
        let result = SnippetPlaceholders.substitute(
            template: template,
            with: ["name": "Sarah"]
        )
        #expect(result == "Welcome to Tokyo, Sarah!")
    }

    @Test func hasPlaceholdersCheck() {
        #expect(SnippetPlaceholders.hasPlaceholders("Hello {{name}}"))
        #expect(!SnippetPlaceholders.hasPlaceholders("Hello {name}"))
        #expect(!SnippetPlaceholders.hasPlaceholders("Plain text without variables"))
    }
}
