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

            // 8. Deletion & Cleanup
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
