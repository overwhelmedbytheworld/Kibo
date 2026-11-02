import Testing
@testable import KiboKit

@Suite("Snippet Alias Validation")
struct SnippetAliasTests {
    @Test func validAliases() {
        #expect(SnippetAlias.isValid(":email:"))
        #expect(SnippetAlias.isValid(":debug:"))
        #expect(SnippetAlias.isValid(":prompt1:"))
        #expect(SnippetAlias.isValid(":my-prompt:"))
        #expect(SnippetAlias.isValid(":code123:"))
    }

    @Test func invalidAliases() {
        #expect(!SnippetAlias.isValid("email"))           // no colons
        #expect(!SnippetAlias.isValid(":email"))           // missing trailing colon
        #expect(!SnippetAlias.isValid("email:"))           // missing leading colon
        #expect(!SnippetAlias.isValid("::"))               // empty inside
        #expect(!SnippetAlias.isValid(":a:"))              // too short inside (need >= 3)
        #expect(!SnippetAlias.isValid(":ab:"))             // too short inside
        #expect(!SnippetAlias.isValid(":Email:"))          // uppercase
        #expect(!SnippetAlias.isValid(":my prompt:"))      // space inside
        #expect(!SnippetAlias.isValid(":my_prompt:"))      // underscore not allowed
        #expect(!SnippetAlias.isValid(""))                 // empty
    }

    @Test func cleanProducesValidAlias() {
        #expect(SnippetAlias.clean("email") == ":email:")
        #expect(SnippetAlias.clean(":email:") == ":email:")
        #expect(SnippetAlias.clean("  Email  ") == ":email:")
        #expect(SnippetAlias.clean("PROMPT1") == ":prompt1:")
    }

    @Test func cleanRejectsInvalid() {
        #expect(SnippetAlias.clean("a") == nil)           // too short
        #expect(SnippetAlias.clean("my prompt") == nil)    // space
    }
}
