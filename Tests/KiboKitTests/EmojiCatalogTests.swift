import Testing
@testable import KiboKit

@Suite("Emoji Catalog Lookup and Matching")
struct EmojiCatalogTests {
    @Test("Exact match finds emoji")
    func exactMatch() {
        let match = EmojiCatalog.findMatch(in: "hello :fire:")
        #expect(match != nil)
        #expect(match?.emoji == "🔥")
        #expect(match?.alias == ":fire:")
    }

    @Test("Synonym alias finds same emoji")
    func synonymMatch() {
        let match = EmojiCatalog.findMatch(in: ":lit:")
        #expect(match?.emoji == "🔥")
    }

    @Test("Underscore and continuous variations both match")
    func underscoreVariations() {
        let matchWithUnderscore = EmojiCatalog.findMatch(in: ":thumbs_up:")
        let matchNoUnderscore = EmojiCatalog.findMatch(in: ":thumbsup:")
        let matchHyphen = EmojiCatalog.findMatch(in: ":thumbs-up:")

        #expect(matchWithUnderscore?.emoji == "👍")
        #expect(matchNoUnderscore?.emoji == "👍")
        #expect(matchHyphen?.emoji == "👍")
    }

    @Test("Apple-specific modern emojis match")
    func modernEmojis() {
        #expect(EmojiCatalog.findMatch(in: ":salute:")?.emoji == "🫡")
        #expect(EmojiCatalog.findMatch(in: ":melting:")?.emoji == "🫠")
        #expect(EmojiCatalog.findMatch(in: ":mind_blown:")?.emoji == "🤯")
        #expect(EmojiCatalog.findMatch(in: ":heart_on_fire:")?.emoji == "❤️‍🔥")
    }

    @Test("Buffer without trailing colon does not trigger")
    func incompleteBuffer() {
        #expect(EmojiCatalog.findMatch(in: "typing :fire") == nil)
    }

    @Test("Search query finds relevant emojis")
    func searchFiltering() {
        let results = EmojiCatalog.filter(query: "heart")
        #expect(results.contains(where: { $0.emoji == "❤️" }))
        #expect(results.contains(where: { $0.emoji == "😍" }))
    }

    @Test("Search query 'rose' returns 🌹 as top result")
    func searchRosePrioritizesRose() {
        let results = EmojiCatalog.filter(query: "rose")
        #expect(!results.isEmpty)
        #expect(results.first?.emoji == "🌹")
        #expect(results.first?.primaryAlias == ":rose:")
    }

    @Test("Pasting raw emoji '🌹' reverse-engineers code and Unicode hex")
    func reverseEngineerPastedEmoji() {
        let reverse = EmojiCatalog.reverseEngineer(input: "🌹")
        #expect(reverse != nil)
        #expect(reverse?.emoji == "🌹")
        #expect(reverse?.name == "Rose")
        #expect(reverse?.primaryAlias == ":rose:")
        #expect(reverse?.unicodeHex == "U+1F339")
    }

    @Test("Pasting arbitrary Unicode emoji creates valid metadata")
    func reverseEngineerArbitraryEmoji() {
        let reverse = EmojiCatalog.reverseEngineer(input: "🫨")
        #expect(reverse != nil)
        #expect(reverse?.emoji == "🫨")
        #expect(reverse?.unicodeHex.contains("U+1FAE8") == true)
    }

    @Test("Search query 'thumbs up', 'thumbs', 'thumb' finds thumbs up emoji")
    func searchThumbsUpVariations() {
        let resultsFull = EmojiCatalog.filter(query: "thumbs up")
        #expect(resultsFull.first?.emoji == "👍")

        let resultsPlural = EmojiCatalog.filter(query: "thumbs")
        #expect(resultsPlural.first?.emoji == "👍")

        let resultsSingular = EmojiCatalog.filter(query: "thumb")
        #expect(resultsSingular.first?.emoji == "👍")
    }

    @Test("Common queries find correct emojis")
    func commonQueries() {
        #expect(EmojiCatalog.filter(query: "shrug").first?.emoji == "🤷")
        #expect(EmojiCatalog.filter(query: "pray").first?.emoji == "🙏")
        #expect(EmojiCatalog.filter(query: "pray emoji").first?.emoji == "🙏")
        #expect(EmojiCatalog.filter(query: "thumbs up emoji").first?.emoji == "👍")
        #expect(EmojiCatalog.filter(query: "fire emoji").first?.emoji == "🔥")
        #expect(EmojiCatalog.filter(query: "rose emoji").first?.emoji == "🌹")
        #expect(EmojiCatalog.filter(query: "coffee").first?.emoji == "☕")
        #expect(EmojiCatalog.filter(query: "pizza").first?.emoji == "🍕")
        #expect(EmojiCatalog.all.count >= 1700)
    }

    @Test("Category filtering narrows emojis")
    func categoryFiltering() {
        let foodItems = EmojiCatalog.filter(query: "", category: "Food")
        #expect(!foodItems.isEmpty)
        #expect(foodItems.allSatisfy { $0.category == "Food" })
        #expect(foodItems.contains(where: { $0.emoji == "🍕" }))
    }
}
