#if canImport(MDAnyWhereLocalization)
import MDAnyWhereLocalization
#endif
import Foundation

struct MDAnyWhereDocument: Codable, Sendable {
    var id: String
    var url: URL?
    var bookmark: Data?
    var title: String
    var content: String
    var isDirty: Bool
    var lastSavedContent: String?
    var hasSaveConflict = false
}

struct MDAnyWhereSession: Codable, Sendable {
    var version = 1
    var documents: [MDAnyWhereDocument]
    var activeDocumentID: String?
}

/// A private, protected recovery copy is independent of the user's file provider.
/// Writes are serialized so an older snapshot cannot replace a newer snapshot.
final class MDAnyWhereDocumentStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.mdanywhere.mobile.recovery", qos: .utility)
    private let sessionURL: URL

    init(directory requestedDirectory: URL? = nil) throws {
        let directory: URL
        if let requestedDirectory { directory = requestedDirectory }
        else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask, appropriateFor: nil, create: true)
            directory = support.appendingPathComponent("DocumentRecovery", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        sessionURL = directory.appendingPathComponent("session.json")
    }

    func load() throws -> MDAnyWhereSession? {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
            let session = try JSONDecoder().decode(MDAnyWhereSession.self, from: Data(contentsOf: sessionURL))
            guard session.version == 1,
                  Set(session.documents.map(\.id)).count == session.documents.count else {
                throw Self.fileError(422, L("native.recovery.invalid"))
            }
            return session
        }
    }

    /// Preserve unreadable bytes before allowing a new session to be saved.
    /// A failed copy leaves recovery disabled instead of overwriting the only copy.
    func preserveUnreadableSession() throws {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: sessionURL.path) else { return }
            let backupURL = sessionURL.deletingLastPathComponent()
                .appendingPathComponent("unreadable-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: sessionURL, to: backupURL)
        }
    }

    func save(_ session: MDAnyWhereSession, completion: @escaping @Sendable (String?) -> Void) {
        queue.async {
            do { try self.write(session); completion(nil) }
            catch { completion(error.localizedDescription) }
        }
    }

    /// Called as the scene resigns active, before iOS is allowed to suspend it.
    func flush(_ session: MDAnyWhereSession) throws {
        try queue.sync { try write(session) }
    }

    private func write(_ session: MDAnyWhereSession) throws {
        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func read(_ url: URL) throws -> String {
        var coordinationError: NSError?
        var result: Result<String, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
            coordinatedURL in
            result = Result { try readWithoutCoordination(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    private static func readWithoutCoordination(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16 * 1024 * 1024 + 1) ?? Data()
        guard data.count <= 16 * 1024 * 1024 else {
            throw fileError(413, L("native.error.fileTooLarge"))
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw fileError(422, L("native.error.utf8Required"))
        }
        return content
    }

    static func write(_ content: String, to url: URL, expectedPreviousContent: String?) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing,
                                       error: &coordinationError) { coordinatedURL in
            do {
                if let expectedPreviousContent {
                    guard try readWithoutCoordination(coordinatedURL) == expectedPreviousContent else {
                        throw fileError(409, L("native.error.mobileConflict"))
                    }
                }
                try content.write(to: coordinatedURL, atomically: true, encoding: .utf8)
            } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    static func fileError(_ code: Int, _ description: String) -> NSError {
        NSError(domain: "MDAnyWhere.File", code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
