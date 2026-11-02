import AppKit
import SwiftData
import KiboKit

/// Self-test for agents: runs the app's real functions on a test store,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_STORE=/tmp/Kibo-self.store ~/Applications/Kibo.app/Contents/MacOS/Kibo --selftest
/// (tools/selftest.sh does this.) Add a check for every story with logic.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Print each line at once, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp")
            finish(code: 1)
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            let context = model.container.mainContext
            func snippets() -> [Snippet] { (try? context.fetch(FetchDescriptor<Snippet>())) ?? [] }

            let before = snippets().count
            model.addSnippet()
            let afterAdd = snippets()
            check("New Snippet adds one snippet", afterAdd.count == before + 1)
            check("the new snippet is selected", model.selection != nil)

            if let snippet = afterAdd.first(where: { $0.id == model.selection }) {
                snippet.isFavourite.toggle()
                check("favouriting a snippet marks it", snippet.isFavourite)
                context.delete(snippet)
                try? context.save()
                check("deleting the snippet removes it", snippets().count == before)
            }

            // Alias validation
            check("valid alias :email:", SnippetAlias.isValid(":email:"))
            check("valid alias :my-prompt:", SnippetAlias.isValid(":my-prompt:"))
            check("invalid alias without colons", !SnippetAlias.isValid("email"))
            check("invalid alias too short", !SnippetAlias.isValid(":ab:"))
            check("alias clean normalises", SnippetAlias.clean("Email") == ":email:")

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
