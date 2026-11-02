import Testing
@testable import KiboKit

@Suite("Snippet Alias Validation")
struct SnippetAliasTests {
    @Test func validAliases() {
        #expect(SnippetAlias.isValid(":email:"))
        #expect(SnippetAlias.isValid(":debug:"))
        #expect(SnippetAlias.isValid(":ai:"))
        #expect(SnippetAlias.isValid(":prompt1:"))
        #expect(SnippetAlias.isValid(":my-prompt:"))
        #expect(SnippetAlias.isValid(":code_review:"))
        #expect(SnippetAlias.isValid(":code123:"))
    }

    @Test func invalidAliases() {
        #expect(!SnippetAlias.isValid("email"))           // no colons
        #expect(!SnippetAlias.isValid(":email"))           // missing trailing colon
        #expect(!SnippetAlias.isValid("email:"))           // missing leading colon
        #expect(!SnippetAlias.isValid("::"))               // empty inside
        #expect(!SnippetAlias.isValid(":a:"))              // too short (need >= 2 inside)
        #expect(!SnippetAlias.isValid(":Email:"))          // uppercase not allowed
        #expect(!SnippetAlias.isValid(":my prompt:"))      // spaces not allowed
        #expect(!SnippetAlias.isValid(""))                 // empty
    }

    @Test func validationMessages() {
        #expect(SnippetAlias.validate(":email:") == .valid)
        #expect(SnippetAlias.validate("") == .empty)
        #expect(SnippetAlias.validate("email") == .missingColons)
        #expect(SnippetAlias.validate(":a:") == .tooShort)
        #expect(SnippetAlias.validate(":my prompt:") == .invalidCharacters)
    }

    @Test func cleanProducesValidAlias() {
        #expect(SnippetAlias.clean("email") == ":email:")
        #expect(SnippetAlias.clean(":email:") == ":email:")
        #expect(SnippetAlias.clean("  Email  ") == ":email:")
        #expect(SnippetAlias.clean("PROMPT1") == ":prompt1:")
        #expect(SnippetAlias.clean("my-prompt") == ":my-prompt:")
        #expect(SnippetAlias.clean("my_prompt") == ":my_prompt:")
    }

    @Test func cleanRejectsInvalid() {
        #expect(SnippetAlias.clean("a") == nil)            // too short inside
        #expect(SnippetAlias.clean("my prompt") == nil)    // space
    }
}
