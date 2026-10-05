#if canImport(DOTMDLocalization)
import DOTMDLocalization
#endif
import AppKit
import Darwin
import Network
import UniformTypeIdentifiers
import WebKit

@MainActor
private final class TitlebarDragOverlay: NSView {
    var interactiveRegions: [NSRect] = []
    var isDragEnabled = false
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isDragEnabled, let superview else { return nil }
        let local = convert(point, from: superview)
        guard bounds.contains(local), local.y < 84,
              (local.y >= 52 || local.x >= 80),
              !interactiveRegions.contains(where: { $0.contains(local) }) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        window.performDrag(with: event)
    }
}

// WKUserContentController retains message handlers. A weak forwarding handler
// prevents a web view -> controller -> AppDelegate -> web view retain cycle.
@MainActor
private final class WeakEditorMessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: AppDelegate?

    init(owner: AppDelegate) { self.owner = owner }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        owner?.userContentController(userContentController, didReceive: message)
    }
}

private struct LoadedMarkdownFile: Sendable {
    let url: URL
    let content: String?
    let errorMessage: String?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    // Native state mirrors each tab's content for autosave and close prompts.
    // The JavaScript editor owns cursor positions, rendering and undo history.
    private struct DocumentState: Sendable {
        let id: String
        var url: URL?
        var title: String
        var content: String
        var isDirty: Bool
        var lastSavedContent: String? = nil
        var hasSaveConflict: Bool = false
    }

    private var window: NSWindow!
    private var webView: WKWebView!
    private var materialView: NSView!
    private var titlebarDragOverlay: TitlebarDragOverlay!
    private var documents: [String: DocumentState] = [:]
    private var activeDocumentID: String?
    private var recentlyClosedDocuments: [DocumentState] = []
    private var pendingAutosaveTasks: [String: DispatchWorkItem] = [:]
    private var activeDiskSaves: [String: (token: UUID, task: Task<Void, Never>)] = [:]
    private var pendingCloseTabIDs = Set<String>()
    private var waitingToCloseWindow = false
    private var waitingToTerminate = false
    private var pendingMarkdownURLs: [URL] = []
    private var pendingAgentCommandURLs: [URL] = []
    private var securityScopedFileURLs: [String: URL] = [:]
    private var editorResourceURL: URL?
    private var isEditorReady = false
    private var editorMessageHandler: WeakEditorMessageHandler?
    private var agentConsoleListener: NWListener?
    private var approvedWindowClose = false
    private let agentService = AgentService()

    // MARK: - Application and window lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenus()
        createMainWindow()
        loadEditorResources()
        updateAgentConsoleListener()
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let commandURLs = urls.filter { $0.pathExtension == "dotmd-agent-command" }
        let markdownURLs = urls.filter { $0.pathExtension != "dotmd-agent-command" }
        if isEditorReady {
            commandURLs.forEach(handleAgentCommandFile)
            openMarkdownFiles(markdownURLs)
        } else {
            pendingAgentCommandURLs.append(contentsOf: commandURLs)
            pendingMarkdownURLs.append(contentsOf: markdownURLs)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "editor")
        agentConsoleListener?.cancel()
        agentConsoleListener = nil
        pendingAutosaveTasks.values.forEach { $0.cancel() }
        pendingAutosaveTasks.removeAll()
        securityScopedFileURLs.values.forEach { $0.stopAccessingSecurityScopedResource() }
        securityScopedFileURLs.removeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func createMainWindow() {
        let configuration = WKWebViewConfiguration()
        let messageHandler = WeakEditorMessageHandler(owner: self)
        editorMessageHandler = messageHandler
        configuration.userContentController.add(messageHandler, name: "editor")
        configuration.userContentController.addUserScript(WKUserScript(
            source: InterfaceLocalization.initialJavaScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = .clear

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 850),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 780, height: 540)
        let root = NSView(frame: .zero)
        root.wantsLayer = true
        materialView = createWindowMaterialView()
        titlebarDragOverlay = TitlebarDragOverlay(frame: .zero)
        materialView.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        titlebarDragOverlay.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(materialView)
        root.addSubview(webView)
        root.addSubview(titlebarDragOverlay)
        NSLayoutConstraint.activate([
            materialView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            materialView.topAnchor.constraint(equalTo: root.topAnchor),
            materialView.heightAnchor.constraint(equalToConstant: 138),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.topAnchor.constraint(equalTo: root.topAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            titlebarDragOverlay.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            titlebarDragOverlay.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            titlebarDragOverlay.topAnchor.constraint(equalTo: root.topAnchor),
            titlebarDragOverlay.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        window.contentView = root
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        updateWindowTitle()
    }

    private func createWindowMaterialView() -> NSView {
        // NSGlassEffectView is available on macOS 26. Resolve it dynamically so
        // md any where can still be built with the compatibility SDK used by this project.
        if #available(macOS 26.0, *),
           let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassType.init(frame: .zero)
            glass.isHidden = true
            return glass
        }
        let effect = NSVisualEffectView(frame: .zero)
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.isHidden = true
        return effect
    }

    private func setLiquidGlassEnabled(_ enabled: Bool) {
        materialView?.isHidden = !enabled
        webView?.underPageBackgroundColor = enabled ? .clear : .windowBackgroundColor
        window?.backgroundColor = .windowBackgroundColor
    }

    private func loadEditorResources() {
        let packagedResources = Bundle.main.resourceURL?.appendingPathComponent("Editor", isDirectory: true)
        let resourceURL: URL?
        if let packagedResources, FileManager.default.fileExists(atPath: packagedResources.appendingPathComponent("index.html").path) {
            resourceURL = packagedResources
        } else {
            let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
            let developmentResources = executableDirectory?
                .appendingPathComponent("DOTMD_DOTMD.bundle", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
            if let developmentResources,
               FileManager.default.fileExists(atPath: developmentResources.appendingPathComponent("index.html").path) {
                resourceURL = developmentResources
            } else {
                resourceURL = nil
            }
        }
        guard let resourceURL else { showErrorAlert(L("native.error.editorLoad")); return }
        editorResourceURL = resourceURL.standardizedFileURL
        webView.loadFileURL(resourceURL.appendingPathComponent("index.html"), allowingReadAccessTo: resourceURL)
    }

    // MARK: - Menus and document commands

    private func configureApplicationMenus() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("native.menu.about"), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("native.menu.settings"), action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("native.menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(); main.addItem(fileItem)
        let file = NSMenu(title: L("native.menu.file"))
        addMenuCommand(file, L("native.menu.newTab"), #selector(newDocument), "t")
        addMenuCommand(file, L("native.menu.openMultiple"), #selector(openDocument), "o")
        addMenuCommand(file, L("native.menu.openFolder"), #selector(openFolder), "o", [.command, .shift])
        addMenuCommand(file, L("native.menu.closeTab"), #selector(closeCurrentTab), "w")
        addMenuCommand(file, L("native.menu.reopenTab"), #selector(reopenClosedTab), "t", [.command, .shift])
        file.addItem(.separator())
        addMenuCommand(file, L("native.save"), #selector(saveDocument), "s")
        addMenuCommand(file, L("native.menu.saveAs"), #selector(saveAsDocument), "S")
        file.addItem(.separator())
        addMenuCommand(file, L("native.menu.exportHTML"), #selector(exportHTML), "e", [.command, .shift])
        addMenuCommand(file, L("native.menu.exportPDF"), #selector(exportPDF), "p", [.command, .shift])
        addMenuCommand(file, L("native.menu.exportWord"), #selector(showDocxTools), "d", [.command, .shift])
        fileItem.submenu = file

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: L("native.menu.edit"))
        addMenuCommand(edit, L("native.menu.undo"), #selector(undoAction), "z")
        addMenuCommand(edit, L("native.menu.redo"), #selector(redoAction), "z", [.command, .shift])
        addMenuCommand(edit, L("native.menu.history"), #selector(showHistoryTools), "z", [.command, .option])
        edit.addItem(.separator())
        addMenuCommand(edit, L("native.menu.cut"), #selector(NSText.cut(_:)), "x", responderChain: true)
        addMenuCommand(edit, L("native.menu.copy"), #selector(NSText.copy(_:)), "c", responderChain: true)
        addMenuCommand(edit, L("native.menu.paste"), #selector(NSText.paste(_:)), "v", responderChain: true)
        addMenuCommand(edit, L("native.menu.selectAll"), #selector(NSText.selectAll(_:)), "a", responderChain: true)
        addMenuCommand(edit, L("native.menu.deselect"), #selector(clearSelection), "d")
        addMenuCommand(edit, L("native.menu.find"), #selector(showSearchTools), "f")
        addMenuCommand(edit, L("native.menu.replace"), #selector(showReplaceTools), "f", [.command, .option])
        editItem.submenu = edit

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let view = NSMenu(title: L("native.menu.view"))
        addMenuCommand(view, L("native.menu.editor"), #selector(showEditor), "1", [.command, .shift])
        addMenuCommand(view, L("native.menu.split"), #selector(showSplit), "2", [.command, .shift])
        addMenuCommand(view, L("native.menu.preview"), #selector(showPreview), "3", [.command, .shift])
        view.addItem(.separator())
        addMenuCommand(view, L("native.menu.outline"), #selector(toggleOutline), "l", [.command, .shift])
        addMenuCommand(view, L("native.menu.fullScreen"), #selector(toggleFullScreen), "f", [.command, .control])
        viewItem.submenu = view

        let agentItem = NSMenuItem(); main.addItem(agentItem)
        let agentMenu = NSMenu(title: L("native.menu.ai"))
        addMenuCommand(agentMenu, L("native.menu.agent"), #selector(showAgentTools), "a", [.command, .shift])
        addMenuCommand(agentMenu, L("native.menu.formula"), #selector(showFormulaTools), "m", [.command, .option])
        agentItem.submenu = agentMenu

        let windowItem = NSMenuItem(); main.addItem(windowItem)
        let windowMenu = NSMenu(title: L("native.menu.window"))
        windowMenu.addItem(withTitle: L("native.menu.minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(.separator())
        addMenuCommand(windowMenu, L("native.menu.nextTab"), #selector(nextTab), "\t", [.control])
        addMenuCommand(windowMenu, L("native.menu.previousTab"), #selector(previousTab), "\t", [.control, .shift])
        windowItem.submenu = windowMenu
        NSApp.mainMenu = main
    }

    private func addMenuCommand(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String,
                     _ modifiers: NSEvent.ModifierFlags = [.command], responderChain: Bool = false) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = responderChain ? nil : self
        menu.addItem(item)
    }

    @objc private func newDocument() {
        let id = UUID().uuidString
        let number = documents.values.filter { $0.url == nil }.count + 1
        let title = number == 1 ? L("native.untitled") : L("native.untitledNumber", number)
        let text = L("native.newContent")
        documents[id] = DocumentState(id: id, url: nil, title: title, content: text, isDirty: false)
        activeDocumentID = id
        invokeEditorJavaScript("addDocument", [id, title, text, false])
        updateWindowTitle()
    }

    private func createGeneratedDocument(title requestedTitle: String, content: String) {
        let id = UUID().uuidString
        let cleanTitle = requestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleanTitle.isEmpty ? L("native.agent.summaryTitle") : (cleanTitle.lowercased().hasSuffix(".md") ? cleanTitle : cleanTitle + ".md")
        documents[id] = DocumentState(id: id, url: nil, title: title, content: content, isDirty: true)
        activeDocumentID = id
        invokeEditorJavaScript("addDocument", [id, title, content, true])
        updateWindowTitle()
    }

    @objc private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md")!]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { openMarkdownFiles(panel.urls) }
    }

    @objc private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L("native.folder.authorize")
        panel.message = L("native.folder.scope")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        retainSecurityScope(for: folder)

        let extensions = Set(["md", "markdown", "mdown"])
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        // Do not enumerate and retain an arbitrarily large directory tree when
        // the UI intentionally opens at most 100 documents at a time.
        var markdownFiles: [URL] = []
        var reachedLimit = false
        if let enumerator {
            for case let url as URL in enumerator {
                guard extensions.contains(url.pathExtension.lowercased()),
                      (try? url.resourceValues(forKeys: Set(keys)).isRegularFile) == true else { continue }
                if markdownFiles.count == 100 { reachedLimit = true; break }
                markdownFiles.append(url)
            }
        }
        markdownFiles.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        guard !markdownFiles.isEmpty else {
            showErrorAlert(L("native.folder.empty"))
            return
        }
        openMarkdownFiles(markdownFiles)
        if reachedLimit {
            invokeEditorJavaScript("showToast", [L("native.folder.limit")])
        }
    }

    private func retainSecurityScope(for url: URL) {
        let resource = url.standardizedFileURL
        guard securityScopedFileURLs[resource.path] == nil,
              resource.startAccessingSecurityScopedResource() else { return }
        securityScopedFileURLs[resource.path] = resource
    }

    private func releaseUnusedSecurityScopes() {
        let openPaths = documents.values.compactMap { $0.url?.standardizedFileURL.path }
        for (path, resource) in securityScopedFileURLs {
            let isDirectory = (try? resource.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let needed = openPaths.contains { openPath in
                openPath == path || (isDirectory && openPath.hasPrefix(path + "/"))
            }
            if !needed {
                resource.stopAccessingSecurityScopedResource()
                securityScopedFileURLs.removeValue(forKey: path)
            }
        }
    }

    nonisolated private static func readCoordinatedMarkdown(at url: URL) throws -> String {
        var coordinationError: NSError?
        var readError: Error?
        var content: String?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
            do {
                let limit = 16 * 1024 * 1024
                let handle = try FileHandle(forReadingFrom: readableURL)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: limit + 1) ?? Data()
                guard data.count <= limit else {
                    throw NSError(domain: "DOTMD.File", code: 413,
                                  userInfo: [NSLocalizedDescriptionKey:L("native.error.fileTooLarge")])
                }
                guard let decoded = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "DOTMD.File", code: 422,
                                  userInfo: [NSLocalizedDescriptionKey:L("native.error.invalidUTF8")])
                }
                content = decoded
            }
            catch { readError = error }
        }
        if let error = coordinationError ?? readError { throw error }
        guard let content else { throw CocoaError(.fileReadUnknown) }
        return content
    }

    nonisolated private static func writeCoordinatedMarkdown(_ content: String, to url: URL,
                                                              expectedPreviousContent: String?) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing,
                                       error: &coordinationError) { writableURL in
            do {
                if let expectedPreviousContent {
                    let current = try readCoordinatedMarkdownWithoutNesting(at: writableURL)
                    guard current == expectedPreviousContent else {
                        throw NSError(domain: "DOTMD.File", code: 409, userInfo: [
                            NSLocalizedDescriptionKey:L("native.error.diskConflict")
                        ])
                    }
                }
                try content.write(to: writableURL, atomically: true, encoding: .utf8)
            }
            catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    nonisolated private static func readCoordinatedMarkdownWithoutNesting(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: 16 * 1024 * 1024 + 1) ?? Data()
        guard bytes.count <= 16 * 1024 * 1024,
              let text = String(data: bytes, encoding: .utf8) else {
            throw NSError(domain: "DOTMD.File", code: 409,
                          userInfo: [NSLocalizedDescriptionKey:L("native.error.diskChanged")])
        }
        return text
    }

    // File reads happen off the UI thread. One bridge call and one preview
    // render then install the loaded tabs in the original selection order.
    private func openMarkdownFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let alreadyOpen = Set(documents.values.compactMap { $0.url?.standardizedFileURL.path })
        var scheduled = Set<String>()
        let toLoad = urls.filter { url in
            let path = url.standardizedFileURL.path
            return !alreadyOpen.contains(path) && scheduled.insert(path).inserted
        }
        if toLoad.isEmpty {
            if let last = urls.last,
               let existing = documents.values.first(where: { $0.url?.standardizedFileURL == last.standardizedFileURL }) {
                activeDocumentID = existing.id
                invokeEditorJavaScript("activateTab", [existing.id])
                updateWindowTitle()
            }
            return
        }
        toLoad.forEach { retainSecurityScope(for: $0) }
        Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                var remainingBytes = 80 * 1024 * 1024
                return toLoad.map { url -> LoadedMarkdownFile in
                    do {
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= remainingBytes else {
                            throw NSError(domain: "DOTMD.File", code: 413,
                                          userInfo: [NSLocalizedDescriptionKey:L("native.error.totalTooLarge")])
                        }
                        let content = try Self.readCoordinatedMarkdown(at: url)
                        guard content.utf8.count <= remainingBytes else {
                            throw NSError(domain: "DOTMD.File", code: 413,
                                          userInfo: [NSLocalizedDescriptionKey:L("native.error.totalTooLarge")])
                        }
                        remainingBytes -= content.utf8.count
                        return LoadedMarkdownFile(url: url,
                                                  content: content,
                                                  errorMessage: nil)
                    } catch {
                        return LoadedMarkdownFile(url: url, content: nil,
                                                  errorMessage: error.localizedDescription)
                    }
                }
            }.value
            self?.installLoadedMarkdownFiles(loaded, selectedURLs: urls)
        }
    }

    private func installLoadedMarkdownFiles(_ loaded: [LoadedMarkdownFile], selectedURLs: [URL]) {
        let byPath = Dictionary(uniqueKeysWithValues: loaded.map { ($0.url.standardizedFileURL.path, $0) })
        var additions: [[Any]] = []
        var lastID: String?
        for url in selectedURLs {
            if let existing = documents.values.first(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) {
                lastID = existing.id
                continue
            }
            guard let file = byPath[url.standardizedFileURL.path] else { continue }
            guard let text = file.content else {
                showErrorAlert(L("native.error.openDocument", url.lastPathComponent, file.errorMessage ?? L("native.error.unknown")))
                continue
            }
            let id = UUID().uuidString
            let title = url.lastPathComponent
            documents[id] = DocumentState(id: id, url: url, title: title, content: text,
                                          isDirty: false, lastSavedContent: text)
            additions.append([id, title, text, false])
            lastID = id
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }
        if !additions.isEmpty { invokeEditorJavaScript("addDocuments", [additions, lastID ?? ""]) }
        else if let lastID { invokeEditorJavaScript("activateTab", [lastID]) }
        releaseUnusedSecurityScopes()
        activeDocumentID = lastID ?? activeDocumentID
        updateWindowTitle()
    }

    @objc private func saveDocument() {
        guard let id = activeDocumentID else { return }
        if documents[id]?.url == nil { _ = saveAs(id) }
        else {
            pendingAutosaveTasks[id]?.cancel()
            pendingAutosaveTasks[id] = nil
            enqueueDiskSave(for: id)
        }
    }

    @objc private func saveAsDocument() {
        guard let id = activeDocumentID else { return }
        if let saving = activeDiskSaves[id] {
            Task { [weak self] in
                await saving.task.value
                guard let self, self.documents[id] != nil else { return }
                _ = self.saveAs(id)
            }
        } else {
            _ = saveAs(id)
        }
    }

    private func saveAs(_ id: String) -> Bool {
        guard let document = documents[id] else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
        panel.nameFieldStringValue = document.title
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        retainSecurityScope(for: url)
        documents[id]?.url = url
        documents[id]?.title = url.lastPathComponent
        documents[id]?.lastSavedContent = nil // NSSavePanel handles explicit overwrite approval.
        documents[id]?.hasSaveConflict = false
        let saved = writeDocumentToDisk(id)
        if !saved {
            documents[id]?.url = document.url
            documents[id]?.title = document.title
            documents[id]?.lastSavedContent = document.lastSavedContent
            documents[id]?.hasSaveConflict = document.hasSaveConflict
        }
        releaseUnusedSecurityScopes()
        return saved
    }

    // MARK: - Save, close and export

    @discardableResult private func writeDocumentToDisk(_ id: String) -> Bool {
        guard let document = documents[id], let url = document.url else { return false }
        do {
            try Self.writeCoordinatedMarkdown(document.content, to: url,
                                              expectedPreviousContent: document.lastSavedContent)
            documents[id]?.isDirty = false
            documents[id]?.lastSavedContent = document.content
            documents[id]?.hasSaveConflict = false
            documents[id]?.title = url.lastPathComponent
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            invokeEditorJavaScript("markSaved", [id, url.lastPathComponent])
            updateWindowTitle()
            return true
        } catch {
            if (error as NSError).domain == "DOTMD.File", (error as NSError).code == 409 {
                documents[id]?.hasSaveConflict = true
            }
            showErrorAlert(L("native.error.saveDocument", error.localizedDescription))
            return false
        }
    }

    private func scheduleDocumentAutosave(for id: String) {
        guard documents[id]?.url != nil, documents[id]?.hasSaveConflict != true else { return }
        pendingAutosaveTasks[id]?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.pendingAutosaveTasks[id] = nil
            self?.enqueueDiskSave(for: id)
        }
        pendingAutosaveTasks[id] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
    }

    private func enqueueDiskSave(for id: String) {
        guard documents[id]?.url != nil, documents[id]?.hasSaveConflict != true else { return }
        let preceding = activeDiskSaves[id]?.task
        let token = UUID()
        let task = Task { [weak self] in
            await preceding?.value
            guard let self, let document = self.documents[id], let url = document.url,
                  !document.hasSaveConflict else {
                self?.finishDiskSave(id: id, token: token, snapshot: nil, errorMessage: nil, isConflict: false)
                return
            }
            let outcome = await Task.detached(priority: .utility) { () -> (String?, Bool) in
                do {
                    try Self.writeCoordinatedMarkdown(document.content, to: url,
                                                      expectedPreviousContent: document.lastSavedContent)
                    return (nil, false)
                } catch {
                    let cocoaError = error as NSError
                    return (error.localizedDescription,
                            cocoaError.domain == "DOTMD.File" && cocoaError.code == 409)
                }
            }.value
            self.finishDiskSave(id: id, token: token, snapshot: document,
                                errorMessage: outcome.0, isConflict: outcome.1)
        }
        activeDiskSaves[id] = (token, task)
    }

    private func finishDiskSave(id: String, token: UUID, snapshot: DocumentState?,
                                errorMessage: String?, isConflict: Bool) {
        defer {
            if activeDiskSaves[id]?.token == token { activeDiskSaves[id] = nil }
        }
        guard let snapshot, let url = snapshot.url,
              documents[id]?.url?.standardizedFileURL == url.standardizedFileURL else { return }
        if let errorMessage {
            if isConflict { documents[id]?.hasSaveConflict = true }
            showErrorAlert(L("native.error.saveDocument", errorMessage))
            return
        }
        documents[id]?.lastSavedContent = snapshot.content
        if documents[id]?.content == snapshot.content {
            documents[id]?.isDirty = false
            documents[id]?.title = url.lastPathComponent
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            invokeEditorJavaScript("markSaved", [id, url.lastPathComponent])
            updateWindowTitle()
        }
    }

    @objc private func closeCurrentTab() {
        guard let id = activeDocumentID else { return }
        closeTab(id)
    }

    private func closeTab(_ id: String) {
        pendingAutosaveTasks[id]?.cancel()
        pendingAutosaveTasks[id] = nil
        if let saving = activeDiskSaves[id] {
            guard pendingCloseTabIDs.insert(id).inserted else { return }
            Task { [weak self] in
                await saving.task.value
                self?.pendingCloseTabIDs.remove(id)
                self?.closeTab(id)
            }
            return
        }
        guard let document = documents[id], confirmClose(document) else {
            if documents[id]?.isDirty == true { scheduleDocumentAutosave(for: id) }
            return
        }
        recentlyClosedDocuments.append(document)
        if recentlyClosedDocuments.count > 12 { recentlyClosedDocuments.removeFirst() }
        documents[id] = nil
        releaseUnusedSecurityScopes()
        invokeEditorJavaScript("removeTab", [id])
        if documents.isEmpty { newDocument() }
    }

    @objc private func reopenClosedTab() {
        guard var document = recentlyClosedDocuments.popLast() else { return }
        let id = UUID().uuidString
        document = DocumentState(id: id, url: document.url, title: document.title,
                                 content: document.content, isDirty: document.isDirty,
                                 lastSavedContent: document.lastSavedContent,
                                 hasSaveConflict: document.hasSaveConflict)
        if let url = document.url { retainSecurityScope(for: url) }
        documents[id] = document
        activeDocumentID = id
        invokeEditorJavaScript("addDocument", [id, document.title, document.content, document.isDirty])
        updateWindowTitle()
    }

    @objc private func nextTab() { invokeEditorJavaScript("cycleTab", [1]) }
    @objc private func previousTab() { invokeEditorJavaScript("cycleTab", [-1]) }

    @objc private func exportHTML() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.html]
        let title = activeDocumentID.flatMap { documents[$0]?.title } ?? L("native.untitled")
        panel.nameFieldStringValue = URL(fileURLWithPath: title).deletingPathExtension().lastPathComponent + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        webView.evaluateJavaScript("window.dotmd.exportHTML()") { result, error in
            guard error == nil, let html = result as? String else { self.showErrorAlert(L("native.error.generateHTML")); return }
            Task { [weak self] in
                let message = await Task.detached(priority: .userInitiated) { () -> String? in
                    do { try Self.writeCoordinatedMarkdown(html, to: url, expectedPreviousContent: nil); return nil }
                    catch { return error.localizedDescription }
                }.value
                if let message { self?.showErrorAlert(L("native.error.exportHTML", message)) }
            }
        }
    }

    @objc private func exportPDF() {
        webView.evaluateJavaScript("window.dotmd.preparePrint()") { _, _ in
            let operation = self.webView.printOperation(with: NSPrintInfo.shared)
            operation.showsPrintPanel = true; operation.showsProgressPanel = true; operation.run()
            self.webView.evaluateJavaScript("window.dotmd.finishPrint()")
        }
    }

    @objc private func showDocxTools() { invokeEditorJavaScript("openDocxTools", []) }

    private func exportDOCX(_ body: [String: Any]) {
        guard let id = body["id"] as? String, id == activeDocumentID,
              let document = documents[id], let rawBlocks = body["blocks"],
              let rawSettings = body["settings"],
              JSONSerialization.isValidJSONObject(rawBlocks),
              JSONSerialization.isValidJSONObject(rawSettings),
              let blockData = try? JSONSerialization.data(withJSONObject: rawBlocks),
              let settingsData = try? JSONSerialization.data(withJSONObject: rawSettings),
              let blocks = try? JSONDecoder().decode([DocxBlock].self, from: blockData),
              let layout = try? JSONDecoder().decode(DocxLayout.self, from: settingsData) else {
            invokeEditorJavaScript("showToast", [L("native.error.exportSettings")])
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
        panel.nameFieldStringValue = URL(fileURLWithPath: document.title)
            .deletingPathExtension().lastPathComponent + ".docx"
        panel.prompt = L("native.exportDOCX")
        panel.message = L("native.exportDOCX.scope")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let title = document.title
        let sourceURL = document.url
        Task { [weak self] in
            let message = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    try DocxExporter(layout: layout, sourceURL: sourceURL)
                        .exportDocument(blocks: blocks, title: title, to: url)
                    return nil
                } catch { return error.localizedDescription }
            }.value
            if let message { self?.showErrorAlert(L("native.error.exportDOCX", message)) }
            else { self?.invokeEditorJavaScript("docxExported", []) }
        }
    }

    private func suggestDOCXLayout(_ body: [String: Any]) {
        let profileID = body["profileID"] as? String ?? ""
        let prompt = body["prompt"] as? String ?? ""
        let settings = body["settings"] as? [String: Any] ?? [:]
        let settingsJSON: String
        if JSONSerialization.isValidJSONObject(settings),
           let data = try? JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            settingsJSON = text
        } else { settingsJSON = "{}" }
        guard !profileID.isEmpty, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            invokeEditorJavaScript("showDocxAgentSuggestion", ["", L("native.agent.layoutRequired")])
            return
        }
        guard confirmThirdPartyAgentTransfer(profileIDs: [profileID],
                                             description: L("native.agent.layoutScope", prompt.count)) else {
            invokeEditorJavaScript("showDocxAgentSuggestion", ["", L("native.agent.cancelled")])
            return
        }
        Task {
            let answer = await agentService.suggestExportLayout(
                profileID: profileID, requestText: prompt, currentSettingsJSON: settingsJSON)
            invokeEditorJavaScript("showDocxAgentSuggestion", [answer.text, answer.error ?? ""])
        }
    }

    // MARK: - JavaScript bridge and Agent requests

    @objc private func showEditor() { invokeEditorJavaScript("setMode", ["editor"]) }
    @objc private func showSplit() { invokeEditorJavaScript("setMode", ["split"]) }
    @objc private func showPreview() { invokeEditorJavaScript("setMode", ["preview"]) }
    @objc private func toggleOutline() { invokeEditorJavaScript("toggleOutline", []) }
    @objc private func toggleFullScreen() { window.toggleFullScreen(nil) }
    @objc private func showSettings() { invokeEditorJavaScript("openSettings", []) }
    @objc private func showAgentTools() { invokeEditorJavaScript("openAgentTools", []) }
    @objc private func showFormulaTools() { invokeEditorJavaScript("openFormulaTools", []) }
    @objc private func showSearchTools() { invokeEditorJavaScript("openSearchTools", []) }
    @objc private func showReplaceTools() { invokeEditorJavaScript("openSearchTools", [true]) }
    @objc private func clearSelection() { invokeEditorJavaScript("clearSelection", []) }
    @objc private func undoAction() { invokeEditorJavaScript("stepHistory", [-1]) }
    @objc private func redoAction() { invokeEditorJavaScript("stepHistory", [1]) }
    @objc private func showHistoryTools() { invokeEditorJavaScript("openHistoryTools", []) }

    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L("native.version.development")
        let alert = NSAlert()
        alert.messageText = "md any where"
        alert.informativeText = L("native.about.details", version)
        alert.addButton(withTitle: L("native.ok"))
        alert.runModal()
    }

    private func invokeEditorJavaScript(_ functionName: String, _ arguments: [Any]) {
        guard isEditorReady else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.dotmd.\(functionName).apply(window.dotmd, \(json))")
    }

    private func updateWindowTitle() {
        guard let id = activeDocumentID, let document = documents[id] else {
            window?.title = "md any where"; window?.representedURL = nil; return
        }
        window?.title = "\(document.isDirty ? "● " : "")\(document.title) — md any where"
        window?.representedURL = document.url
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "editor", message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        let id = body["id"] as? String
        switch type {
        case "ready":
            isEditorReady = true
            synchronizeInterfaceLanguage()
            if let id, let content = body["content"] as? String, let title = body["title"] as? String {
                documents[id] = DocumentState(id: id, url: nil, title: title, content: content, isDirty: false)
                activeDocumentID = id
            }
            openMarkdownFiles(pendingMarkdownURLs); pendingMarkdownURLs.removeAll(); updateWindowTitle()
            pendingAgentCommandURLs.forEach(handleAgentCommandFile); pendingAgentCommandURLs.removeAll()
            sendAgentProfiles()
            sendAgentConsoleConfiguration()
        case "changeInterfaceLanguage":
            guard let language = body["language"] as? String, InterfaceLocalization.setLanguage(language) else { return }
            configureApplicationMenus()
            synchronizeInterfaceLanguage()
        case "change":
            guard let id, let content = body["content"] as? String else { return }
            documents[id]?.content = content; documents[id]?.isDirty = true
            if documents[id]?.url == nil, let title = body["title"] as? String { documents[id]?.title = title }
            if id == activeDocumentID { updateWindowTitle() }
            scheduleDocumentAutosave(for: id)
        case "activate":
            if let id, documents[id] != nil { activeDocumentID = id; updateWindowTitle() }
        case "close": if let id { closeTab(id) }
        case "new": newDocument()
        case "newWithContent":
            createGeneratedDocument(title: body["title"] as? String ?? L("native.agent.summaryTitle"),
                                    content: body["content"] as? String ?? "")
        case "open": openDocument()
        case "save": saveDocument()
        case "pasteRequest": pasteClipboardIntoEditor()
        case "copySelection":
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(body["text"] as? String ?? "", forType: .string)
        case "dragRegions":
            let regions = body["regions"] as? [[String: Double]] ?? []
            titlebarDragOverlay.interactiveRegions = regions.map { region in
                NSRect(x: region["x"] ?? 0, y: region["y"] ?? 0,
                       width: region["width"] ?? 0, height: region["height"] ?? 0)
            }
            titlebarDragOverlay.isDragEnabled = body["enabled"] as? Bool ?? false
        case "liquidGlass": setLiquidGlassEnabled(body["enabled"] as? Bool ?? false)
        case "agentConsole": updateAgentConsoleConfiguration(body)
        case "saveAgentProfiles": saveAgentProfiles(body)
        case "agentRun": runAgents(body)
        case "agentPlanWorkflow": planAgentWorkflow(body)
        case "agentWorkflowRun": runAgentWorkflow(body)
        case "agentFormat": suggestDOCXLayout(body)
        case "exportDOCX": exportDOCX(body)
        case "copyFormula":
            FormulaClipboard.copyFormulaToPasteboard(latex: body["latex"] as? String ?? "",
                                  mathML: body["mathML"] as? String ?? "",
                                  svg: body["svg"] as? String ?? "",
                                  target: body["target"] as? String ?? "word")
            invokeEditorJavaScript("showToast", [L("native.copiedFormula")])
        case "copyText":
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(body["text"] as? String ?? "", forType: .string)
            invokeEditorJavaScript("showToast", [L("native.copied")])
        default: break
        }
    }

    private func synchronizeInterfaceLanguage() {
        guard isEditorReady else { return }
        webView.evaluateJavaScript(InterfaceLocalization.synchronizationJavaScript)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureApplicationMenus()
        synchronizeInterfaceLanguage()
    }

    private func pasteClipboardIntoEditor() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            invokeEditorJavaScript("showToast", [L("native.clipboard.empty")])
            return
        }
        invokeEditorJavaScript("insertClipboardText", [text])
    }

    private func sendAgentProfiles() {
        guard let data = try? JSONEncoder().encode(agentService.loadProfiles()),
              let object = try? JSONSerialization.jsonObject(with: data) else { return }
        invokeEditorJavaScript("configureAgents", [object])
    }

    // MARK: - Local console / MCP bridge

    private var agentConsoleEnabled: Bool { UserDefaults.standard.bool(forKey: "agentConsole.enabled") }
    private var agentConsoleAccess: String {
        UserDefaults.standard.string(forKey: "agentConsole.access") == "edit" ? "edit" : "read"
    }

    private func updateAgentConsoleConfiguration(_ body: [String: Any]) {
        UserDefaults.standard.set(body["enabled"] as? Bool ?? false, forKey: "agentConsole.enabled")
        UserDefaults.standard.set(body["access"] as? String == "edit" ? "edit" : "read",
                                  forKey: "agentConsole.access")
        updateAgentConsoleListener()
        sendAgentConsoleConfiguration()
    }

    private func updateAgentConsoleListener() {
        agentConsoleListener?.cancel()
        agentConsoleListener = nil
        guard agentConsoleEnabled, let port = NWEndpoint.Port(rawValue: 57_361) else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.receiveAgentConsoleRequest(on: connection) }
            }
            listener.start(queue: .main)
            agentConsoleListener = listener
        } catch { }
    }

    private func receiveAgentConsoleRequest(on connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, _, error in
            guard error == nil, let header, header.count == 4 else { connection.cancel(); return }
            let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length <= 10_000_000 else { connection.cancel(); return }
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) {
                [weak self] data, _, _, error in
                guard error == nil, let data, data.count == Int(length) else {
                    connection.cancel(); return
                }
                Task { @MainActor in self?.respondToAgentConsoleRequest(data, on: connection) }
            }
        }
    }

    private func respondToAgentConsoleRequest(_ data: Data, on connection: NWConnection) {
        var requestID = UUID().uuidString
        let response: [String: Any]
        do {
            guard let request = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  request["state"] as? String == "request",
                  let id = request["id"] as? String,
                  let command = request["command"] as? String else {
                throw NSError(domain: "DOTMDAgent", code: 400,
                              userInfo: [NSLocalizedDescriptionKey:L("native.console.invalidCommand")])
            }
            requestID = id
            let arguments = request["arguments"] as? [String: Any] ?? [:]
            let result = try executeAgentConsoleCommand(command, arguments: arguments)
            response = ["version":1, "state":"response", "id":requestID,
                        "ok":true, "result":result]
        } catch {
            response = ["version":1, "state":"response", "id":requestID,
                        "ok":false, "error":["message":error.localizedDescription]]
        }
        guard let payload = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]) else {
            connection.cancel(); return
        }
        var networkLength = UInt32(payload.count).bigEndian
        var frame = Data(bytes: &networkLength, count: MemoryLayout<UInt32>.size)
        frame.append(payload)
        connection.send(content: frame, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func sendAgentConsoleConfiguration() {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/dotmd-agent").path
        invokeEditorJavaScript("configureAgentConsole", [[
            "enabled": agentConsoleEnabled,
            "access": agentConsoleAccess,
            "helperPath": helper
        ]])
    }

    private func writeAgentCommandResponse(_ value: [String: Any], to handle: FileHandle) {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { return }
        do { try handle.truncate(atOffset: 0); try handle.seek(toOffset: 0); try handle.write(contentsOf: data) }
        catch { }
    }

    private func handleAgentCommandFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let handle = try? FileHandle(forUpdating: url) else { return }
        defer { try? handle.close() }
        var requestID = UUID().uuidString
        var response: [String: Any]
        do {
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            let commandPath = url.standardizedFileURL.path
            let isSystemTemporaryPath = (commandPath.hasPrefix("/var/folders/") ||
                                         commandPath.hasPrefix("/private/var/folders/")) &&
                                        commandPath.contains("/T/")
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first?.standardizedFileURL.path ?? ""
            let agentBridgePath = applicationSupport + "/DOT MD/AgentBridge/"
            let isAgentBridgePath = !applicationSupport.isEmpty && commandPath.hasPrefix(agentBridgePath)
            var fileStatus = stat()
            guard fstat(handle.fileDescriptor, &fileStatus) == 0,
                  (isSystemTemporaryPath || isAgentBridgePath),
                  url.pathExtension == "dotmd-agent-command", resource.isRegularFile == true,
                  resource.isSymbolicLink != true, (fileStatus.st_mode & S_IFMT) == S_IFREG,
                  fileStatus.st_uid == getuid(), fileStatus.st_nlink == 1,
                  fileStatus.st_size <= 10_000_000, fileStatus.st_mode & 0o077 == 0 else {
                throw NSError(domain: "DOTMDAgent", code: 403,
                              userInfo: [NSLocalizedDescriptionKey:L("native.console.unsafeFile")])
            }
            try handle.seek(toOffset: 0)
            let data = try handle.readToEnd() ?? Data()
            guard let request = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  request["state"] as? String == "request",
                  let id = request["id"] as? String,
                  let command = request["command"] as? String else {
                throw NSError(domain: "DOTMDAgent", code: 400,
                              userInfo: [NSLocalizedDescriptionKey:L("native.console.invalidCommand")])
            }
            requestID = id
            let arguments = request["arguments"] as? [String: Any] ?? [:]
            let result = try executeAgentConsoleCommand(command, arguments: arguments)
            response = ["version":1, "state":"response", "id":requestID, "ok":true, "result":result]
        } catch {
            response = ["version":1, "state":"response", "id":requestID, "ok":false,
                        "error":["message":error.localizedDescription]]
        }
        writeAgentCommandResponse(response, to: handle)
    }

    private func agentConsoleDocument(_ arguments: [String: Any]) throws -> (String, DocumentState) {
        let id = (arguments["document_id"] as? String).flatMap { documents[$0] != nil ? $0 : nil }
            ?? activeDocumentID
        guard let id, let document = documents[id] else {
            throw NSError(domain: "DOTMDAgent", code: 404,
                          userInfo: [NSLocalizedDescriptionKey:L("native.console.noDocument")])
        }
        return (id, document)
    }

    private func requireAgentConsoleEditAccess() throws {
        guard agentConsoleAccess == "edit" else {
            throw NSError(domain: "DOTMDAgent", code: 403,
                          userInfo: [NSLocalizedDescriptionKey:L("native.console.readOnly")])
        }
    }

    // A loopback socket is reachable by other local processes. Require a visible
    // decision for every document operation; never treat localhost as identity.
    private func approveAgentConsoleRequest(_ command: String, arguments: [String: Any]) -> Bool {
        let documentID = arguments["document_id"] as? String ?? activeDocumentID
        let title = documentID.flatMap { documents[$0]?.title } ?? L("native.console.currentDocument")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("native.console.confirmTitle", command)
        alert.informativeText = L("native.console.confirmBody", title)
        alert.addButton(withTitle: L("native.console.allowOnce"))
        alert.addButton(withTitle: L("native.console.deny"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func executeAgentConsoleCommand(_ command: String, arguments: [String: Any]) throws -> Any {
        if command == "status" {
            let active = activeDocumentID.flatMap { documents[$0] }
            return ["enabled":agentConsoleEnabled, "access":agentConsoleAccess,
                    "active_document":active.map { ["id":$0.id, "title":$0.title, "dirty":$0.isDirty] } ?? NSNull()]
        }
        guard agentConsoleEnabled else {
            throw NSError(domain: "DOTMDAgent", code: 403,
                          userInfo: [NSLocalizedDescriptionKey:L("native.console.disabled")])
        }
        guard approveAgentConsoleRequest(command, arguments: arguments) else {
            throw NSError(domain: "DOTMDAgent", code: 403,
                          userInfo: [NSLocalizedDescriptionKey:L("native.console.denied")])
        }
        switch command {
        case "list_documents":
            return documents.values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                .map { ["id":$0.id, "title":$0.title, "dirty":$0.isDirty, "saved":$0.url != nil] }
        case "read_document":
            let (id, document) = try agentConsoleDocument(arguments)
            let requestedLimit = arguments["max_chars"] as? Int ?? 50_000
            let limit = max(1, min(requestedLimit, 200_000))
            let truncated = document.content.count > limit
            return ["id":id, "title":document.title,
                    "content":String(document.content.prefix(limit)), "truncated":truncated]
        case "create_document":
            try requireAgentConsoleEditAccess()
            let text = arguments["content"] as? String ?? ""
            guard text.count <= 2_000_000 else { throw NSError(domain:"DOTMDAgent", code:413, userInfo:[NSLocalizedDescriptionKey:L("native.console.documentTooLong")])}
            let id = UUID().uuidString
            let requested = (arguments["title"] as? String ?? L("native.agent.documentTitle")).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = requested.lowercased().hasSuffix(".md") ? requested : requested + ".md"
            documents[id] = DocumentState(id:id, url:nil, title:title, content:text, isDirty:true)
            activeDocumentID = id; invokeEditorJavaScript("addDocument", [id, title, text, true]); updateWindowTitle()
            return ["id":id, "title":title, "created":true]
        case "insert_diagram":
            try requireAgentConsoleEditAccess()
            let (id, document) = try agentConsoleDocument(arguments)
            let diagram = (arguments["diagram"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = diagram.split(whereSeparator: \Character.isNewline).first.map(String.init) ?? ""
            let header = try NSRegularExpression(pattern: "^(?:flowchart|graph)\\s+(?:TD|TB|BT|LR|RL)$", options: .caseInsensitive)
            let headerRange = NSRange(firstLine.startIndex..<firstLine.endIndex, in: firstLine)
            guard header.firstMatch(in: firstLine, range: headerRange) != nil else {
                throw NSError(domain:"DOTMDAgent", code:400, userInfo:[NSLocalizedDescriptionKey:L("native.console.diagramDirection")])
            }
            guard diagram.count <= 100_000, !diagram.contains("```") else {
                throw NSError(domain:"DOTMDAgent", code:413, userInfo:[NSLocalizedDescriptionKey:L("native.console.diagramTooLong")])
            }
            let heading = (arguments["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sectionTitle = heading.flatMap { $0.isEmpty ? nil : "### \($0)\n\n" } ?? ""
            let separator = document.content.isEmpty || document.content.hasSuffix("\n\n") ? "" : (document.content.hasSuffix("\n") ? "\n" : "\n\n")
            let content = document.content + separator + sectionTitle + "```mermaid\n" + diagram + "\n```\n"
            guard content.count <= 2_000_000 else { throw NSError(domain:"DOTMDAgent", code:413, userInfo:[NSLocalizedDescriptionKey:L("native.console.editedTooLong")])}
            documents[id]?.content = content; documents[id]?.isDirty = true; activeDocumentID = id
            invokeEditorJavaScript("replaceDocumentFromAgent", [id, content]); updateWindowTitle()
            return ["id":id, "title":document.title, "changed":true, "kind":"mermaid"]
        case "replace_document", "append_text", "find_replace":
            try requireAgentConsoleEditAccess()
            let (id, document) = try agentConsoleDocument(arguments)
            var content = document.content
            var replacements = 0
            if command == "replace_document" { content = arguments["content"] as? String ?? "" }
            else if command == "append_text" { content += arguments["text"] as? String ?? "" }
            else {
                let needle = arguments["find"] as? String ?? ""
                let replacement = arguments["replace"] as? String ?? ""
                guard !needle.isEmpty else { throw NSError(domain:"DOTMDAgent", code:400, userInfo:[NSLocalizedDescriptionKey:L("native.console.findRequired")])}
                if arguments["all"] as? Bool == false {
                    if let range = content.range(of: needle) { content.replaceSubrange(range, with: replacement); replacements = 1 }
                } else {
                    var searchStart = content.startIndex
                    while let range = content.range(of: needle, range: searchStart..<content.endIndex) {
                        replacements += 1; searchStart = range.upperBound
                    }
                    content = content.replacingOccurrences(of: needle, with: replacement)
                }
            }
            guard content.count <= 2_000_000 else { throw NSError(domain:"DOTMDAgent", code:413, userInfo:[NSLocalizedDescriptionKey:L("native.console.editedTooLong")])}
            if content == document.content {
                return ["id":id, "title":document.title, "changed":false, "replacements":replacements]
            }
            documents[id]?.content = content; documents[id]?.isDirty = true; activeDocumentID = id
            invokeEditorJavaScript("replaceDocumentFromAgent", [id, content]); updateWindowTitle()
            return ["id":id, "title":document.title, "changed":true, "replacements":replacements]
        case "save_document":
            try requireAgentConsoleEditAccess()
            let (id, document) = try agentConsoleDocument(arguments)
            guard document.url != nil else { throw NSError(domain:"DOTMDAgent", code:409, userInfo:[NSLocalizedDescriptionKey:L("native.console.unsaved")])}
            guard activeDiskSaves[id] == nil else { throw NSError(domain:"DOTMDAgent", code:409, userInfo:[NSLocalizedDescriptionKey:L("native.console.saving")])}
            guard writeDocumentToDisk(id) else { throw NSError(domain:"DOTMDAgent", code:500, userInfo:[NSLocalizedDescriptionKey:L("native.error.saveFailed")])}
            return ["id":id, "title":documents[id]?.title ?? document.title, "saved":true]
        default:
            throw NSError(domain:"DOTMDAgent", code:404, userInfo:[NSLocalizedDescriptionKey:L("native.console.unsupported", command)])
        }
    }

    private func saveAgentProfiles(_ body: [String: Any]) {
        guard let raw = body["profiles"], JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let profiles = try? JSONDecoder().decode([AgentProfile].self, from: data) else {
            invokeEditorJavaScript("showToast", [L("native.agent.invalidProfiles")]); return
        }
        do {
            try agentService.saveProfiles(profiles, keys: body["keys"] as? [String: String] ?? [:])
            sendAgentProfiles(); invokeEditorJavaScript("showToast", [L("native.agent.profilesSaved")])
        } catch { invokeEditorJavaScript("showToast", [L("native.error.keychain", error.localizedDescription)]) }
    }

    private func runAgents(_ body: [String: Any]) {
        let ids = body["profileIDs"] as? [String] ?? []
        let instruction = body["instruction"] as? String ?? L("native.agent.defaultInstruction")
        let selection = body["selection"] as? String ?? ""
        let context = body["context"] as? String ?? ""
        let mode = body["mode"] as? String ?? "single"
        let purpose = body["purpose"] as? String ?? "edit"
        let selectedIDs = mode == "single" ? Array(ids.prefix(1)) : ids
        guard confirmThirdPartyAgentTransfer(profileIDs: selectedIDs,
                                             description: L("native.agent.editScope", selection.count, context.count)) else { return }
        invokeEditorJavaScript("setAgentBusy", [true])
        Task {
            let answers = await agentService.runSelectedAgents(profileIDs: ids, instruction: instruction,
                                                 selection: selection, context: context, mode: mode)
            guard let data = try? JSONEncoder().encode(answers),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                invokeEditorJavaScript("setAgentBusy", [false]); invokeEditorJavaScript("showToast", [L("native.agent.invalidResult")]); return
            }
            invokeEditorJavaScript("setAgentBusy", [false]); invokeEditorJavaScript("showAgentResults", [object, purpose])
        }
    }

    private func planAgentWorkflow(_ body: [String: Any]) {
        let profileID = body["profileID"] as? String ?? ""
        let goal = body["goal"] as? String ?? ""
        guard !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, goal.count <= 1500 else {
            invokeEditorJavaScript("showToast", [L("native.agent.goalRequired")]); return
        }
        guard confirmThirdPartyAgentTransfer(profileIDs: [profileID],
                                             description: L("native.agent.workflowScope", goal.count)) else { return }
        invokeEditorJavaScript("setWorkflowPlanning", [true])
        Task {
            let answer = await agentService.designWorkflow(profileID: profileID, goal: goal)
            invokeEditorJavaScript("setWorkflowPlanning", [false])
            invokeEditorJavaScript("showWorkflowProposal", [answer.text, answer.error ?? ""])
        }
    }

    private func runAgentWorkflow(_ body: [String: Any]) {
        guard let raw = body["workflow"],
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let workflow = try? JSONDecoder().decode(AgentWorkflow.self, from: data) else {
            invokeEditorJavaScript("showToast", [L("native.agent.invalidWorkflow")]); return
        }
        let selection = body["selection"] as? String ?? ""
        let context = body["context"] as? String ?? ""
        let purpose = body["purpose"] as? String ?? "edit"
        let profileIDs = Array(Set(workflow.stages.flatMap(\.profileIDs))).sorted()
        guard confirmThirdPartyAgentTransfer(profileIDs: profileIDs,
                                             description: L("native.agent.workflowRunScope", selection.count, context.count)) else { return }
        invokeEditorJavaScript("setAgentBusy", [true])
        Task {
            let results = await agentService.runWorkflow(workflow, selection: selection, context: context)
            guard let data = try? JSONEncoder().encode(results),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                invokeEditorJavaScript("setAgentBusy", [false]); invokeEditorJavaScript("showToast", [L("native.agent.invalidWorkflowResult")]); return
            }
            invokeEditorJavaScript("setAgentBusy", [false])
            invokeEditorJavaScript("showWorkflowResults", [object, purpose])
        }
    }

    private func confirmThirdPartyAgentTransfer(profileIDs: [String], description: String) -> Bool {
        let selected = agentService.loadProfiles().filter { $0.enabled && profileIDs.contains($0.id) }
        let remote = selected.filter { profile in
            let host = URLComponents(string: profile.endpoint)?.host?.lowercased() ?? ""
            return host != "localhost" && host != "127.0.0.1" && host != "::1"
        }
        guard !remote.isEmpty else { return true }
        let recipients = remote.map { profile in
            let host = URLComponents(string: profile.endpoint)?.host ?? L("native.agent.customEndpoint")
            return "• \(profile.name) — \(host)"
        }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = L("native.agent.transferTitle")
        alert.informativeText = L("native.agent.transferBody", recipients, description)
        alert.addButton(withTitle: L("native.agent.allowTransfer"))
        alert.addButton(withTitle: L("native.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if approvedWindowClose { return .terminateNow }
        if !activeDiskSaves.isEmpty {
            guard !waitingToTerminate else { return .terminateLater }
            waitingToTerminate = true
            Task { [weak self] in
                guard let self else { return }
                await self.waitForDiskSaves()
                self.waitingToTerminate = false
                NSApp.reply(toApplicationShouldTerminate: self.confirmCloseAllDocuments())
            }
            return .terminateLater
        }
        return confirmCloseAllDocuments() ? .terminateNow : .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if !activeDiskSaves.isEmpty {
            guard !waitingToCloseWindow else { return false }
            waitingToCloseWindow = true
            Task { [weak self, weak sender] in
                guard let self else { return }
                await self.waitForDiskSaves()
                self.waitingToCloseWindow = false
                sender?.performClose(nil)
            }
            return false
        }
        let approved = confirmCloseAllDocuments()
        approvedWindowClose = approved
        return approved
    }

    private func waitForDiskSaves() async {
        while let save = activeDiskSaves.values.first {
            await save.task.value
        }
    }

    private func confirmCloseAllDocuments() -> Bool {
        for document in documents.values where document.isDirty {
            guard confirmClose(document) else { return false }
        }
        pendingAutosaveTasks.values.forEach { $0.cancel() }
        pendingAutosaveTasks.removeAll()
        return true
    }

    private func confirmClose(_ document: DocumentState) -> Bool {
        guard document.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = L("native.close.title", document.title)
        alert.informativeText = L("native.close.discardWarning")
        alert.addButton(withTitle: L("native.save")); alert.addButton(withTitle: L("native.cancel")); alert.addButton(withTitle: L("native.dontSave"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: return document.url == nil ? saveAs(document.id) : writeDocumentToDisk(document.id)
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = message; alert.runModal()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "about" { decisionHandler(.allow); return }
        if url.isFileURL, let root = editorResourceURL,
           url.standardizedFileURL.path.hasPrefix(root.path + "/") {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}
