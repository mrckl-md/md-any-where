import Foundation
import Darwin

// Compiled with Sources/MDAnyWhereMobile/DocumentStore.swift. These tests exercise the
// production store directly; no storage or conflict logic is reimplemented here.
private struct StoreTestFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw StoreTestFailure(message: message) }
}

private func expectFileError(_ expectedCode: Int, operation: () throws -> Void) throws {
    do {
        try operation()
    } catch let error as NSError {
        try require(error.domain == "MDAnyWhere.File" && error.code == expectedCode,
                    "Expected MDAnyWhere.File \(expectedCode), received \(error)")
        return
    }
    throw StoreTestFailure(message: "Expected MDAnyWhere.File \(expectedCode), but operation succeeded")
}

private final class SaveCompletions: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String?] = []

    func record(_ message: String?) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
    }

    func verify(count: Int) throws {
        lock.lock()
        defer { lock.unlock() }
        try require(messages.count == count, "Queued saves did not all complete before flush returned")
        try require(messages.allSatisfy { $0 == nil }, "A queued save failed: \(messages.compactMap { $0 })")
    }
}

@main
private enum MobileStoreTests {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2 else {
                throw StoreTestFailure(message: "Run scripts/test-mobile-store.sh to provide an isolated temporary directory")
            }
            let testRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
                .appendingPathComponent("fixtures-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: testRoot) }
            try checkStore(at: testRoot)
            print("All 9 mobile document-store checks passed.")
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func checkStore(at root: URL) throws {
        let directory = root.appendingPathComponent("recovery", isDirectory: true)
        let store = try MDAnyWhereDocumentStore(directory: directory)
        try require(try store.load() == nil, "A new store should not contain a session")
        let draft = MDAnyWhereDocument(id: "draft", title: "草稿.md",
            content: "# 尚未保存\n\n数学：α + β，表情 📝，组合字 e\u{301}\n", isDirty: true)
        let saved = MDAnyWhereDocument(id: "saved", title: "已保存.md", content: "Saved text\n",
                                isDirty: false, lastSavedContent: "Saved text\n")
        let original = MDAnyWhereSession(documents: [draft, saved], activeDocumentID: draft.id)
        try store.flush(original)

        // A new store instance proves that recovery comes from disk, not retained objects.
        let restored = try MDAnyWhereDocumentStore(directory: directory).load()
        try require(restored?.documents.first?.content == draft.content,
                    "Unicode draft text did not survive restart")
        try require(restored?.documents.first?.title == draft.title,
                    "Unicode draft title did not survive restart")
        print("PASS 1: unsaved Unicode draft survives store restart")

        try require(restored?.documents.map(\.id) == [draft.id, saved.id], "Document order changed")
        try require(restored?.activeDocumentID == draft.id, "Active tab was lost")
        try require(restored?.documents[0].isDirty == true && restored?.documents[1].isDirty == false,
                    "Dirty and clean states were lost")
        try require(restored?.documents[1].lastSavedContent == saved.content,
                    "The saved-content conflict baseline was lost")
        print("PASS 2: active tab, order, dirty flags, and save baseline survive recovery")

        let completions = SaveCompletions()
        for revision in 0..<8 {
            var olderDraft = draft
            olderDraft.content = "Queued revision \(revision)\n"
            store.save(MDAnyWhereSession(documents: [olderDraft], activeDocumentID: draft.id)) {
                completions.record($0)
            }
        }
        var latestDraft = draft
        latestDraft.content += "最新修改\n"
        let latest = MDAnyWhereSession(documents: [latestDraft, saved], activeDocumentID: draft.id)
        try store.flush(latest)
        try completions.verify(count: 8)
        try require(try store.load()?.documents.first?.content == latestDraft.content,
                    "An older queued snapshot overwrote the final flush")
        print("PASS 3: queued saves finish in order before the final lifecycle flush")

        let sessionURL = directory.appendingPathComponent("session.json")
        let corruptBytes = Data("{invalid recovery bytes\n".utf8)
        try corruptBytes.write(to: sessionURL)
        do {
            _ = try store.load()
            throw StoreTestFailure(message: "Damaged JSON was accepted")
        } catch is DecodingError { /* The production decoder must reject the damaged bytes. */ }
        try store.preserveUnreadableSession()
        try store.flush(latest)
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("unreadable-") }
        try require(backups.count == 1, "Damaged recovery backup is missing")
        try require(try Data(contentsOf: backups[0]) == corruptBytes, "Damaged backup bytes were changed")
        try require(try MDAnyWhereDocumentStore(directory: directory).load()?.documents.first?.content == latestDraft.content,
                    "Fresh drafts could not recover after preserving the damaged session")
        print("PASS 4: damaged recovery is preserved byte-for-byte and new recovery remains usable")

        let encoder = JSONEncoder()
        var unsupported = latest
        unsupported.version = 99
        try encoder.encode(unsupported).write(to: sessionURL)
        try expectFileError(422) { _ = try store.load() }
        let duplicateIDs = MDAnyWhereSession(documents: [draft, draft], activeDocumentID: draft.id)
        try encoder.encode(duplicateIDs).write(to: sessionURL)
        try expectFileError(422) { _ = try store.load() }
        try store.flush(latest)
        print("PASS 5: unsupported session versions and duplicate tab IDs are rejected")

        let file = root.appendingPathComponent("document.md")
        let originalText = "# Original\n\n中文正文\n"
        let editedText = "# Saved\n\n修改后正文\n"
        try originalText.write(to: file, atomically: true, encoding: .utf8)
        try require(try MDAnyWhereDocumentStore.read(file) == originalText, "Coordinated read changed the document")
        try MDAnyWhereDocumentStore.write(editedText, to: file, expectedPreviousContent: originalText)
        try require(try MDAnyWhereDocumentStore.read(file) == editedText, "Coordinated save did not persist the edit")
        print("PASS 6: coordinated reads and saves preserve UTF-8 document contents")

        try expectFileError(409) {
            try MDAnyWhereDocumentStore.write("Stale edit", to: file, expectedPreviousContent: originalText)
        }
        try require(try MDAnyWhereDocumentStore.read(file) == editedText,
                    "A rejected stale save overwrote the external version")
        print("PASS 7: external-change conflict rejects stale writes without modifying the file")

        let invalidUTF8 = Data([0xff, 0xfe, 0x80])
        try invalidUTF8.write(to: file)
        try expectFileError(422) { _ = try MDAnyWhereDocumentStore.read(file) }
        try expectFileError(422) {
            try MDAnyWhereDocumentStore.write("Overwrite", to: file, expectedPreviousContent: editedText)
        }
        try require(try Data(contentsOf: file) == invalidUTF8, "Invalid external bytes were overwritten")
        print("PASS 8: invalid UTF-8 is rejected on open and before overwrite")

        let byteLimit = 16 * 1024 * 1024
        try Data(repeating: 65, count: byteLimit).write(to: file)
        try require(try MDAnyWhereDocumentStore.read(file).utf8.count == byteLimit,
                    "An exactly 16 MiB UTF-8 document should be accepted")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([65]))
        try handle.close()
        try expectFileError(413) { _ = try MDAnyWhereDocumentStore.read(file) }
        print("PASS 9: the 16 MiB boundary is accepted and one excess byte is rejected")
    }
}
