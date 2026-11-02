import Testing
@testable import KiboKit

@Suite("Snippet Search and Ranking")
struct SnippetSearchTests {
    struct TestItem {
        let name: String
        let alias: String
        let category: String
        let content: String
    }

    let items = [
        TestItem(name: "Email Writer", alias: ":email:", category: "Work", content: "Professional email template for clients."),
        TestItem(name: "Debate Prep", alias: ":debate:", category: "Study", content: "Arguments and counter-arguments for topics."),
        TestItem(name: "Coding Helper", alias: ":code:", category: "Dev", content: "Write clean Swift code with error handling."),
        TestItem(name: "Emoji React", alias: ":react:", category: "Personal", content: "Quick replies and reactions.")
    ]

    @Test func exactAliasMatchTakesTopRank() {
        let results = SnippetSearch.filter(items: items, query: ":email:") {
            ($0.name, $0.alias, $0.category, $0.content)
        }
        #expect(!results.isEmpty)
        #expect(results.first?.name == "Email Writer")
    }

    @Test func aliasPrefixMatch() {
        let results = SnippetSearch.filter(items: items, query: ":deb") {
            ($0.name, $0.alias, $0.category, $0.content)
        }
        #expect(results.count == 1)
        #expect(results.first?.name == "Debate Prep")
    }

    @Test func contentSearchFindsKeywords() {
        let results = SnippetSearch.filter(items: items, query: "swift") {
            ($0.name, $0.alias, $0.category, $0.content)
        }
        #expect(results.count == 1)
        #expect(results.first?.name == "Coding Helper")
    }

    @Test func categoryFilterNarrowsResults() {
        let results = SnippetSearch.filter(items: items, query: "", categoryFilter: "Work") {
            ($0.name, $0.alias, $0.category, $0.content)
        }
        #expect(results.count == 1)
        #expect(results.first?.name == "Email Writer")
    }

    @Test func emptyQueryReturnsAll() {
        let results = SnippetSearch.filter(items: items, query: "") {
            ($0.name, $0.alias, $0.category, $0.content)
        }
        #expect(results.count == items.count)
    }
}
