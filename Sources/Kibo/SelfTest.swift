import AppKit
import SwiftData
import KiboKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Kibo-self.store ~/Applications/Kibo.app/Contents/MacOS/Kibo --selftest
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let context = model.container.mainContext
            func fetchSnippets() -> [Snippet] {
                (try? context.fetch(FetchDescriptor<Snippet>())) ?? []
            }

            let initialCount = fetchSnippets().count

            // 1. Creation
            model.addSnippet(
                name: "Test Email Prompt",
                alias: ":test-email:",
                content: "Hello World from Kibo",
                category: "Work"
            )
            let afterAdd = fetchSnippets()
            check("addSnippet increases count", afterAdd.count == initialCount + 1)
            check("new snippet is selected", model.selection != nil)

            guard let testSnippet = afterAdd.first(where: { $0.id == model.selection }) else {
                check("retrieved added snippet", false)
                finish(code: 1)
                return
            }
            check("snippet name matches", testSnippet.name == "Test Email Prompt")
            check("snippet alias matches", testSnippet.alias == ":test-email:")
            check("snippet category matches", testSnippet.category == "Work")

            // 2. Duplication
            model.duplicateSnippet(testSnippet)
            let afterDup = fetchSnippets()
            check("duplicateSnippet increases count", afterDup.count == initialCount + 2)
            if let dup = afterDup.first(where: { $0.id == model.selection }) {
                check("duplicated snippet has copy name", dup.name == "Test Email Prompt Copy")
                check("duplicated snippet has copy alias", dup.alias == ":test-email-copy:")
                check("duplicated snippet retains content", dup.content == "Hello World from Kibo")
                model.deleteSnippet(dup)
            }

            // 3. Favouriting
            check("initially not favourite", !testSnippet.isFavourite)
            model.toggleFavourite(testSnippet)
            check("toggleFavourite stars snippet", testSnippet.isFavourite)

            // 4. Copy to Clipboard
            model.copyToClipboard(testSnippet)
            let pasteboardAfter = NSPasteboard.general.string(forType: .string) ?? ""
            check("copyToClipboard updates system pasteboard", pasteboardAfter == "Hello World from Kibo")
            check("copyToClipboard increments usage count", testSnippet.usageCount == 1)
            check("copyToClipboard sets lastUsedAt", testSnippet.lastUsedAt != nil)

            // 5. Search & Filtering
            let searchResults = SnippetSearch.filter(items: fetchSnippets(), query: "test-email") {
                ($0.name, $0.alias, $0.category, $0.content)
            }
            check("search query finds snippet by alias", searchResults.contains(where: { $0.id == testSnippet.id }))

            let categoryResults = SnippetSearch.filter(items: fetchSnippets(), query: "", categoryFilter: "Work") {
                ($0.name, $0.alias, $0.category, $0.content)
            }
            check("category filter finds snippet in Work", categoryResults.contains(where: { $0.id == testSnippet.id }))

            // 6. Alias Validation Logic
            check("valid alias :email:", SnippetAlias.isValid(":email:"))
            check("valid alias :ai:", SnippetAlias.isValid(":ai:"))
            check("invalid alias without colons", !SnippetAlias.isValid("email"))
            check("invalid alias too short", !SnippetAlias.isValid(":a:"))
            check("clean wraps and lowercases", SnippetAlias.clean("  MY_PROMPT ") == ":my_prompt:")

            // 7. Dynamic Variable Substitution
            let template = "Hi, my name is {{name}} and I study {{subject:CS}}."
            check("detects placeholders in template", SnippetPlaceholders.hasPlaceholders(template))
            let placeholders = SnippetPlaceholders.extract(from: template)
            check("extracts exactly 2 placeholders", placeholders.count == 2)
            check("first placeholder is name", placeholders.first?.key == "name")
            let filled = SnippetPlaceholders.substitute(template: template, with: ["name": "John"])
            check("substitutes variable with default fallback", filled == "Hi, my name is John and I study CS.")

            // 8. Clipboard History Monitoring & Operations
            func fetchClippings() -> [ClipboardEntry] {
                (try? context.fetch(FetchDescriptor<ClipboardEntry>())) ?? []
            }
            let initialClippingsCount = fetchClippings().count

            model.recordClipboardCopy(content: "Testing Kibo Clipboard Monitor")
            let clippingsAfter = fetchClippings()
            check("recordClipboardCopy adds entry", clippingsAfter.count == initialClippingsCount + 1)
            guard let clip = clippingsAfter.first(where: { $0.content == "Testing Kibo Clipboard Monitor" }) else {
                check("retrieved added clipping", false)
                finish(code: 1)
                return
            }
            check("clipping charCount matches", clip.charCount == 30)
            check("clipping title generated", clip.title == "Testing Kibo Clipboard Monitor")
            check("clipping initially unpinned", !clip.isPinned)

            // Test image clipping recording
            let fakeImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
            model.recordClipboardImage(data: fakeImageData, text: "Sample Copied Image")
            let withImage = fetchClippings()
            check("recordClipboardImage stores data", withImage.contains(where: { $0.imageData == fakeImageData }))
            if let imgEntry = withImage.first(where: { $0.imageData == fakeImageData }) {
                model.deleteClipboardEntry(imgEntry)
            }

            model.togglePinClipboardEntry(clip)
            check("togglePinClipboardEntry pins item", clip.isPinned)

            model.convertClipboardEntryToSnippet(clip)
            let snippetsAfterConvert = fetchSnippets()
            check("convertClipboardEntryToSnippet creates new snippet", snippetsAfterConvert.contains(where: { $0.content == "Testing Kibo Clipboard Monitor" }))

            model.deleteClipboardEntry(clip)
            check("deleteClipboardEntry removes entry", fetchClippings().count == initialClippingsCount)

            // 9. Emoji Catalog, Multi-Alias Matching & Reverse-Engineering
            check("emoji lookup :fire: -> 🔥", EmojiCatalog.findMatch(in: ":fire:")?.emoji == "🔥")
            check("emoji lookup :thumbs_up: -> 👍", EmojiCatalog.findMatch(in: ":thumbs_up:")?.emoji == "👍")
            check("emoji lookup :thumbsup: -> 👍", EmojiCatalog.findMatch(in: ":thumbsup:")?.emoji == "👍")
            check("modern apple emoji :salute: -> 🫡", EmojiCatalog.findMatch(in: ":salute:")?.emoji == "🫡")
            check("modern apple emoji :heart_on_fire: -> ❤️‍🔥", EmojiCatalog.findMatch(in: ":heart_on_fire:")?.emoji == "❤️‍🔥")
            check("emoji search 'rose' ranks 🌹 first", EmojiCatalog.filter(query: "rose").first?.emoji == "🌹")
            check("emoji search 'rose emoji' ranks 🌹 first", EmojiCatalog.filter(query: "rose emoji").first?.emoji == "🌹")
            check("emoji search 'thumbs up' finds 👍 first", EmojiCatalog.filter(query: "thumbs up").first?.emoji == "👍")
            check("emoji search 'thumbs up emoji' finds 👍 first", EmojiCatalog.filter(query: "thumbs up emoji").first?.emoji == "👍")
            check("emoji search 'pray' finds 🙏 first", EmojiCatalog.filter(query: "pray").first?.emoji == "🙏")
            check("emoji search 'pray emoji' finds 🙏 first", EmojiCatalog.filter(query: "pray emoji").first?.emoji == "🙏")
            check("emoji search 'fire emoji' finds 🔥 first", EmojiCatalog.filter(query: "fire emoji").first?.emoji == "🔥")
            check("emoji search 'shrug' finds 🤷", EmojiCatalog.filter(query: "shrug").first?.emoji == "🤷")
            check("emoji catalog has full dataset >= 1700", EmojiCatalog.all.count >= 1700)
            check("emoji reverse-engineer pasted '🌹' succeeds", EmojiCatalog.reverseEngineer(input: "🌹")?.emoji == "🌹")
            check("emoji reverse-engineer arbitrary emoji '🫨' succeeds", EmojiCatalog.reverseEngineer(input: "🫨") != nil)
            check("emojis tab defined in sidebar", SidebarPage.allCases.contains(.emojis))

            // 10. Frequency Tracking, Inline Suggestions, App Exclusions & Audio Feedback
            EmojiUsageTracker.shared.recordUsage(emoji: "🔥")
            check("emoji usage records count", EmojiUsageTracker.shared.usageCount(for: "🔥") > 0)
            check("topEmojis includes fire", EmojiUsageTracker.shared.topEmojis(limit: 5).contains(where: { $0.emoji == "🔥" }))
            check("sound feedback enabled by default", SoundFeedback.isEnabled)
            check("inline suggestion controller instantiated", !InlineSuggestionController.shared.isVisible)
            check("inline suggestions excluded in WhatsApp by default", InlineSuggestionController.isAppExcluded(bundleID: "net.whatsapp.WhatsApp", appName: "WhatsApp"))
            check("inline suggestions excluded in Discord by default", InlineSuggestionController.isAppExcluded(bundleID: "com.hnc.Discord", appName: "Discord"))
            check("inline suggestions excluded in Slack by default", InlineSuggestionController.isAppExcluded(bundleID: "com.tinyspeck.slackmacgap", appName: "Slack"))
            check("inline suggestions enabled in Safari by default", !InlineSuggestionController.isAppExcluded(bundleID: "com.apple.Safari", appName: "Safari"))

            // 10. Insights / Statistics & Dynamic Direct-Input HUD
            check("stats page defined in sidebar", SidebarPage.allCases.contains(.stats))

            let promptTest = PlaceholderPromptState(snippetName: "Hello", template: "Hi, my name is {{name}}", backspaces: 0)
            check("placeholder prompt extracts placeholder", promptTest.placeholders.count == 1 && promptTest.placeholders.first?.key == "name")
            promptTest.appendText("John")
            check("direct input appendText updates substituted value", promptTest.substituted == "Hi, my name is John")
            promptTest.backspace()
            check("direct input backspace works", promptTest.substituted == "Hi, my name is Joh")

            // 11. Deletion & Cleanup
            if let converted = snippetsAfterConvert.first(where: { $0.content == "Testing Kibo Clipboard Monitor" }) {
                model.deleteSnippet(converted)
            }
            model.deleteSnippet(testSnippet)
            let finalCount = fetchSnippets().count
            check("deleteSnippet restores initial count", finalCount == initialCount)
            check("selection cleared after deleting active snippet", model.selection == nil)

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
