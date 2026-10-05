import UIKit
import WebKit
import UniformTypeIdentifiers

@main
@MainActor
final class IPadAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Editor", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = IPadSceneDelegate.self
        return configuration
    }
}

@MainActor
final class IPadSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var editor: IPadEditorViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let editor = IPadEditorViewController()
        self.editor = editor
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = editor
        self.window = window
        window.makeKeyAndVisible()
        editor.openFiles(connectionOptions.urlContexts.map(\.url))
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        editor?.openFiles(URLContexts.map(\.url))
    }

    func sceneWillResignActive(_ scene: UIScene) { editor?.flushRecovery() }
    func sceneDidBecomeActive(_ scene: UIScene) { editor?.refreshActiveDocument() }
    func sceneDidEnterBackground(_ scene: UIScene) { editor?.saveInBackground() }
    func sceneDidDisconnect(_ scene: UIScene) { editor?.flushRecovery() }
}

@MainActor
private final class IPadEditorMessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: IPadEditorViewController?
    init(owner: IPadEditorViewController) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.userContentController(userContentController, didReceive: message)
    }
}

@MainActor
final class IPadEditorViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate,
                                      UIDocumentPickerDelegate {
    private var webView: WKWebView!
    private var editorRoot: URL?
    private var isEditorReady = false
    private var documents: [String: IPadDocument] = [:]
    private var documentOrder: [String] = []
    private var activeDocumentID: String?
    private var pendingURLs: [URL] = []
    private var securityScopes: [String: URL] = [:]
    private var loadingFileCounts: [String: Int] = [:]
    private var autosaveTasks: [String: DispatchWorkItem] = [:]
    private var diskSaves: [String: (token: UUID, task: Task<Bool, Never>)] = [:]
    private var closingDocuments = Set<String>()
    private var recoveryTask: DispatchWorkItem?
    private var recoveryStore: IPadDocumentStore?
    private var recoveryFailureShown = false
    private var restoreWarning: String?
    private var exportRequest: (id: String, content: String, directory: URL, closeAfterSave: Bool)?
    private var refreshingDocumentIDs = Set<String>()
    private var refreshedDocumentContent: [String: String] = [:]
    private var isPreparingExport = false
    private let agentService = AgentService()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadRecovery()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(IPadEditorMessageHandler(owner: self), name: "editor")
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.DOTMD_IPAD = true;",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
#if DEBUG
        webView.isInspectable = true
#endif
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Editor", isDirectory: true),
              FileManager.default.fileExists(atPath: root.appendingPathComponent("index.html").path) else {
            showError("无法载入编辑器资源。")
            return
        }
        editorRoot = root.standardizedFileURL
        webView.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
    }

    // MARK: Recovery and file access

    private var currentSession: IPadSession {
        IPadSession(documents: documentOrder.compactMap { documents[$0] }, activeDocumentID: activeDocumentID)
    }

    private func loadRecovery() {
        do {
            let store = try IPadDocumentStore()
            recoveryStore = store
            guard let session = try store.load() else { return }
            for var document in session.documents {
                if let bookmark = document.bookmark {
                    var stale = false
                    if let url = try? URL(resolvingBookmarkData: bookmark, options: [],
                                          relativeTo: nil, bookmarkDataIsStale: &stale) {
                        document.url = url
                        retainAccess(to: url)
                        if stale { document.bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) }
                    } else {
                        document.url = nil
                        document.bookmark = nil
                        document.isDirty = true
                        document.hasSaveConflict = false
                        restoreWarning = "已恢复本机文稿；部分原文件访问权限已失效，请另存为。"
                    }
                } else if let url = document.url { retainAccess(to: url) }
                documents[document.id] = document
                documentOrder.append(document.id)
            }
            activeDocumentID = session.activeDocumentID.flatMap { documents[$0] == nil ? nil : $0 }
                ?? documentOrder.first
        } catch {
            let originalError = error.localizedDescription
            do {
                guard let recoveryStore else { throw error }
                try recoveryStore.preserveUnreadableSession()
                restoreWarning = "无法读取旧的文稿恢复文件，原始副本已保留。新的文稿仍会自动恢复：\(originalError)"
            } catch {
                recoveryStore = nil
                restoreWarning = "无法读取或备份文稿恢复文件。请手动保存新的文稿，避免退出后丢失：\(originalError)"
            }
        }
    }

    /// A recovered clean tab is a cache; the selected file may have changed while
    /// this app was suspended. Never replace edits made while the read is in flight.
    func refreshActiveDocument() {
        guard isEditorReady, let id = activeDocumentID, let snapshot = documents[id],
              let url = snapshot.url, !snapshot.isDirty, diskSaves[id] == nil,
              exportRequest?.id != id, refreshingDocumentIDs.insert(id).inserted else { return }
        Task {
            defer { refreshingDocumentIDs.remove(id) }
            let result = await Task.detached(priority: .utility) {
                Result { try IPadDocumentStore.read(url) }
            }.value
            guard activeDocumentID == id, let current = documents[id], current.url == url,
                  !current.isDirty, current.content == snapshot.content else { return }
            switch result {
            case .success(let content):
                guard content != current.content else { return }
                refreshedDocumentContent[id] = content
                // The JS process may have accepted another keystroke before its
                // change message reaches Swift. Compare and replace atomically there.
                let script = """
                if (document.querySelector('.document-tab.active')?.dataset.id !== documentID ||
                    window.dotmd.getContent() !== previousContent) return false;
                window.dotmd.replaceDocumentFromAgent(documentID, content);
                window.dotmd.markSaved(documentID, title);
                return true;
                """
                do {
                    let applied = try await webView.callAsyncJavaScript(script,
                        arguments: ["documentID": id, "previousContent": current.content,
                                    "content": content, "title": current.title],
                        in: nil, contentWorld: .page) as? Bool ?? false
                    if applied { toast("已载入文件在其他应用中的最新更改") }
                    else { refreshedDocumentContent[id] = nil }
                } catch { refreshedDocumentContent[id] = nil }
            case .failure:
                // Keep the private recovery copy usable even when its provider is offline.
                toast("原文件暂时无法读取，已保留本机副本")
            }
        }
    }

    private func scheduleRecovery() {
        recoveryTask?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.recoveryTask = nil
            self.recoveryStore?.save(self.currentSession) { [weak self] error in
                guard let error else { return }
                Task { @MainActor in self?.reportRecoveryFailure(error) }
            }
        }
        recoveryTask = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    func flushRecovery() {
        recoveryTask?.cancel()
        recoveryTask = nil
        do { try recoveryStore?.flush(currentSession) }
        catch { reportRecoveryFailure(error.localizedDescription) }
    }

    private func reportRecoveryFailure(_ error: String) {
        guard !recoveryFailureShown else { return }
        recoveryFailureShown = true
        showError("本机恢复副本无法保存，请尽快手动保存文稿：\(error)")
    }

    func saveInBackground() {
        flushRecovery()
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save documents") {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        let ids = documentOrder.filter { documents[$0]?.isDirty == true && documents[$0]?.url != nil }
        Task {
            for id in ids { _ = await saveDocument(id) }
            flushRecovery()
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
            backgroundTask = .invalid
        }
    }

    private func retainAccess(to url: URL) {
        let path = url.standardizedFileURL.path
        if securityScopes[path] == nil, url.startAccessingSecurityScopedResource() { securityScopes[path] = url }
    }

    private func releaseUnusedAccess() {
        let needed = Set(documents.values.compactMap { $0.url?.standardizedFileURL.path })
            .union(loadingFileCounts.keys)
        for path in Array(securityScopes.keys) where !needed.contains(path) {
            securityScopes.removeValue(forKey: path)?.stopAccessingSecurityScopedResource()
        }
    }

    func openFiles(_ urls: [URL]) {
        guard isEditorReady else { pendingURLs.append(contentsOf: urls); return }
        let candidates = Array(urls.filter(\.isFileURL).prefix(100))
        candidates.forEach {
            retainAccess(to: $0)
            loadingFileCounts[$0.standardizedFileURL.path, default: 0] += 1
        }
        Task { [weak self] in
            guard let self else { return }
            var remainingBytes = 80 * 1024 * 1024
            for url in candidates {
                if let existing = self.documents.values.first(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) {
                    self.activeDocumentID = existing.id
                    self.invoke("activateTab", [existing.id])
                    continue
                }
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try IPadDocumentStore.read(url) }
                }.value
                do {
                    let content = try result.get()
                    guard content.utf8.count <= remainingBytes else {
                        throw IPadDocumentStore.fileError(413, "本次打开的文稿总量超过 80 MiB。")
                    }
                    remainingBytes -= content.utf8.count
                    // The user can open the same file again while a provider is loading.
                    guard !self.documents.values.contains(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) else { continue }
                    let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let document = IPadDocument(id: UUID().uuidString, url: url, bookmark: bookmark,
                        title: url.lastPathComponent, content: content, isDirty: false, lastSavedContent: content)
                    self.addDocument(document)
                } catch { self.showError("无法打开 \(url.lastPathComponent)：\(error.localizedDescription)") }
            }
            for url in candidates {
                let path = url.standardizedFileURL.path
                let count = (self.loadingFileCounts[path] ?? 1) - 1
                self.loadingFileCounts[path] = count > 0 ? count : nil
            }
            self.releaseUnusedAccess()
            self.flushRecovery()
        }
    }

    private func addDocument(_ document: IPadDocument) {
        documents[document.id] = document
        documentOrder.append(document.id)
        activeDocumentID = document.id
        invoke("addDocument", [document.id, document.title, document.content, document.isDirty])
        scheduleRecovery()
    }

    @objc private func newDocument() {
        let number = documents.values.filter { $0.url == nil }.count + 1
        let title = number == 1 ? "未命名.md" : "未命名 \(number).md"
        addDocument(IPadDocument(id: UUID().uuidString, title: title,
            content: "# 未命名文稿\n\n开始写作…\n", isDirty: false))
    }

    @objc private func openDocument() {
        guard presentedViewController == nil else { return }
        let types: [UTType] = [.plainText, UTType(filenameExtension: "md") ?? .text,
                               UTType(filenameExtension: "markdown") ?? .text]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: Save and close

    private func scheduleAutosave(_ id: String) {
        guard documents[id]?.url != nil, documents[id]?.hasSaveConflict != true,
              exportRequest?.id != id else { return }
        autosaveTasks[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.autosaveTasks[id] = nil
            Task { @MainActor [weak self] in _ = await self?.saveDocument(id) }
        }
        autosaveTasks[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    @objc private func saveActiveDocument() {
        guard let id = activeDocumentID else { return }
        if documents[id]?.url == nil || documents[id]?.hasSaveConflict == true { beginSaveAs(id) }
        else { Task { _ = await saveDocument(id) } }
    }

    @objc private func saveActiveDocumentAs() {
        guard let id = activeDocumentID else { return }
        Task {
            if let saving = diskSaves[id] { _ = await saving.task.value }
            beginSaveAs(id)
        }
    }

    private func saveDocument(_ id: String) async -> Bool {
        autosaveTasks[id]?.cancel()
        autosaveTasks[id] = nil
        // Several callers (autosave, background, Cmd-S) can resume together.
        // Re-check after every await so at most one coordinated write is active.
        while let preceding = diskSaves[id] { _ = await preceding.task.value }
        guard let snapshot = documents[id], let url = snapshot.url, !snapshot.hasSaveConflict,
              exportRequest?.id != id else { return false }
        guard snapshot.isDirty else { return true }
        let token = UUID()
        let task = Task { [weak self] () -> Bool in
            let outcome = await Task.detached(priority: .utility) {
                Result { try IPadDocumentStore.write(snapshot.content, to: url,
                                                     expectedPreviousContent: snapshot.lastSavedContent) }
            }.value
            guard let self else { return false }
            defer { if self.diskSaves[id]?.token == token { self.diskSaves[id] = nil } }
            guard self.documents[id]?.url == url else { return false }
            switch outcome {
            case .success:
                self.documents[id]?.lastSavedContent = snapshot.content
                if self.documents[id]?.content == snapshot.content {
                    self.documents[id]?.isDirty = false
                    self.invoke("markSaved", [id, snapshot.title])
                }
                self.scheduleRecovery()
                return true
            case .failure(let error):
                self.documents[id]?.hasSaveConflict = true // Retry only after explicit save-as; avoid repeated provider alerts.
                self.flushRecovery()
                self.showError("无法保存文稿：\(error.localizedDescription)")
                return false
            }
        }
        diskSaves[id] = (token, task)
        return await task.value
    }

    private func beginSaveAs(_ id: String, closeAfterSave: Bool = false) {
        guard let document = documents[id], presentedViewController == nil, exportRequest == nil else { return }
        autosaveTasks[id]?.cancel()
        autosaveTasks[id] = nil
        do {
            let file = try temporaryFile(title: document.title, extension: "md")
            try document.content.write(to: file, atomically: true, encoding: .utf8)
            exportRequest = (id, document.content, file.deletingLastPathComponent(), closeAfterSave)
            let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
            picker.delegate = self
            picker.shouldShowFileExtensions = true
            present(picker, animated: true)
        } catch { showError("无法准备保存：\(error.localizedDescription)") }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // Delegate delivery does not guarantee that the picker has left the
        // presentation stack. Finish dismissal before opening files or alerts.
        controller.dismiss(animated: true) { [weak self] in self?.finishDocumentSelection(urls) }
    }

    private func finishDocumentSelection(_ urls: [URL]) {
        guard let request = exportRequest else { openFiles(urls); return }
        exportRequest = nil
        defer { try? FileManager.default.removeItem(at: request.directory) }
        guard let url = urls.first, documents[request.id] != nil else { return }
        retainAccess(to: url)
        documents[request.id]?.url = url
        documents[request.id]?.bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        documents[request.id]?.title = url.lastPathComponent
        documents[request.id]?.lastSavedContent = request.content
        documents[request.id]?.hasSaveConflict = false
        let isCurrent = documents[request.id]?.content == request.content
        documents[request.id]?.isDirty = !isCurrent
        if isCurrent { invoke("markSaved", [request.id, url.lastPathComponent]) }
        else { scheduleAutosave(request.id) }
        releaseUnusedAccess()
        flushRecovery()
        if request.closeAfterSave {
            Task {
                if isCurrent { removeDocument(request.id) }
                else { _ = await saveDocument(request.id); closeTab(request.id) }
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let request = exportRequest
        exportRequest = nil
        if let request {
            try? FileManager.default.removeItem(at: request.directory)
            if documents[request.id]?.isDirty == true { scheduleAutosave(request.id) }
        }
    }

    @objc private func closeActiveDocument() { if let id = activeDocumentID { closeTab(id) } }

    private func closeTab(_ id: String) {
        guard closingDocuments.insert(id).inserted else { return }
        autosaveTasks[id]?.cancel()
        autosaveTasks[id] = nil
        Task {
            defer { closingDocuments.remove(id) }
            if let saving = diskSaves[id] { _ = await saving.task.value }
            guard let document = documents[id] else { return }
            if !document.isDirty { removeDocument(id); return }
            let choice = await choose(title: "要保存对“\(document.title)”的更改吗？",
                message: "关闭并不保存会丢弃此标签页的未保存内容。",
                actions: [("保存", .default), ("不保存", .destructive), ("取消", .cancel)])
            switch choice {
            case 0:
                if document.url == nil || document.hasSaveConflict { beginSaveAs(id, closeAfterSave: true) }
                else if await saveDocument(id), documents[id]?.isDirty == false { removeDocument(id) }
            case 1: removeDocument(id)
            default: scheduleAutosave(id)
            }
        }
    }

    private func removeDocument(_ id: String) {
        documents[id] = nil
        documentOrder.removeAll { $0 == id }
        if activeDocumentID == id { activeDocumentID = documentOrder.last }
        invoke("removeTab", [id])
        releaseUnusedAccess()
        if documents.isEmpty { newDocument() }
        flushRecovery()
    }

    // MARK: Export and clipboard

    private func temporaryFile(title: String, extension suffix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let basename = URL(fileURLWithPath: title).deletingPathExtension().lastPathComponent
        let safeName = basename.isEmpty ? "文稿" : String(basename.prefix(100))
        return directory.appendingPathComponent(safeName).appendingPathExtension(suffix)
    }

    private var activeTitle: String { activeDocumentID.flatMap { documents[$0]?.title } ?? "未命名.md" }

    private func shareFile(_ url: URL) {
        guard presentedViewController == nil else {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            toast("请先关闭当前弹窗，再次导出或分享")
            return
        }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = shareAnchor
        sheet.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        present(sheet, animated: true)
    }

    @objc private func shareDocument() {
        guard let id = activeDocumentID, let document = documents[id] else { return }
        do {
            let file = try temporaryFile(title: document.title, extension: "md")
            try document.content.write(to: file, atomically: true, encoding: .utf8)
            shareFile(file)
        } catch { showError(error.localizedDescription) }
    }

    @objc private func exportHTML() {
        let title = activeTitle
        webView.evaluateJavaScript("window.dotmd.exportHTML()") { [weak self] result, error in
            guard let self else { return }
            guard error == nil, let html = result as? String else { self.showError("无法生成 HTML。"); return }
            do {
                let file = try self.temporaryFile(title: title, extension: "html")
                try html.write(to: file, atomically: true, encoding: .utf8)
                self.shareFile(file)
            } catch { self.showError(error.localizedDescription) }
        }
    }

    @objc private func exportPDF() {
        guard !isPreparingExport, presentedViewController == nil else { return }
        isPreparingExport = true
        view.endEditing(true)
        webView.isUserInteractionEnabled = false
        let title = activeTitle
        let prepare = """
        window.dotmd.preparePrint();
        await document.fonts.ready;
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        let pageSize = 'a4';
        try { if (JSON.parse(localStorage.docxLayout || '{}').pageSize === 'letter') pageSize = 'letter'; } catch (_) {}
        return pageSize;
        """
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.webView.callAsyncJavaScript(prepare, arguments: [:], in: nil, contentWorld: .page)
                let rawSize = result as? String ?? "a4"
                let paperSize = MobilePDFRenderer.PaperSize(rawValue: rawSize) ?? .a4
                let data = try MobilePDFRenderer(paperSize: paperSize).makePDF(from: self.webView, title: title)
                let file = try self.temporaryFile(title: title, extension: "pdf")
                try data.write(to: file, options: .atomic)
                self.finishPrintPreparation()
                self.shareFile(file)
            } catch {
                self.finishPrintPreparation()
                self.showError("无法导出 PDF：\(error.localizedDescription)")
            }
        }
    }

    @objc private func printDocument() {
        guard !isPreparingExport, presentedViewController == nil else { return }
        isPreparingExport = true
        webView.isUserInteractionEnabled = false
        webView.evaluateJavaScript("window.dotmd.preparePrint()") { [weak self] _, error in
            guard let self else { return }
            guard error == nil else { self.finishPrintPreparation(); self.showError("无法准备打印。"); return }
            let controller = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = self.activeTitle
            info.outputType = .general
            controller.printInfo = info
            controller.printFormatter = self.webView.viewPrintFormatter()
            let completion: UIPrintInteractionController.CompletionHandler = { [weak self] _, _, error in
                self?.finishPrintPreparation()
                if let error { self?.showError("无法打印：\(error.localizedDescription)") }
            }
            let presented: Bool
            if self.traitCollection.userInterfaceIdiom == .pad {
                presented = controller.present(from: self.shareAnchor, in: self.view, animated: true,
                                               completionHandler: completion)
            } else {
                presented = controller.present(animated: true, completionHandler: completion)
            }
            if !presented { self.finishPrintPreparation(); self.showError("此设备当前无法打开打印面板。") }
        }
    }

    private var shareAnchor: CGRect {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        return CGRect(x: max(safeFrame.minX, safeFrame.maxX - 40), y: safeFrame.minY + 16, width: 1, height: 1)
    }

    private func finishPrintPreparation() {
        invoke("finishPrint", [])
        webView.isUserInteractionEnabled = true
        isPreparingExport = false
    }

    private func exportDOCX(_ body: [String: Any]) {
        guard let id = body["id"] as? String, id == activeDocumentID, let document = documents[id],
              let rawBlocks = body["blocks"], let rawSettings = body["settings"],
              JSONSerialization.isValidJSONObject(rawBlocks), JSONSerialization.isValidJSONObject(rawSettings),
              let blockData = try? JSONSerialization.data(withJSONObject: rawBlocks),
              let settingsData = try? JSONSerialization.data(withJSONObject: rawSettings),
              let blocks = try? JSONDecoder().decode([DocxBlock].self, from: blockData),
              let layout = try? JSONDecoder().decode(DocxLayout.self, from: settingsData) else {
            toast("导出内容或排版设置无效"); return
        }
        Task {
            do {
                let file = try temporaryFile(title: document.title, extension: "docx")
                try await Task.detached(priority: .userInitiated) {
                    try DocxExporter(layout: layout, sourceURL: document.url)
                        .exportDocument(blocks: blocks, title: document.title, to: file)
                }.value
                invoke("docxExported", [])
                shareFile(file)
            } catch { showError("无法导出 DOCX：\(error.localizedDescription)") }
        }
    }

    private func copyFormula(_ body: [String: Any]) {
        let latex = body["latex"] as? String ?? ""
        let mathML = body["mathML"] as? String ?? ""
        let svg = body["svg"] as? String ?? ""
        let target = body["target"] as? String ?? "word"
        let text = target == "mathml" ? mathML : (target == "svg" ? svg : latex)
        var item: [String: Any] = [UTType.utf8PlainText.identifier: Data(text.utf8)]
        if !mathML.isEmpty {
            item[UTType.html.identifier] = Data("<html><body>\(mathML)</body></html>".utf8)
            item["application/mathml+xml"] = Data(mathML.utf8)
        }
        if !svg.isEmpty { item["public.svg-image"] = Data(svg.utf8) }
        UIPasteboard.general.setItems([item])
        toast("公式已复制，可粘贴到目标软件")
    }

    private func pasteClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { toast("剪贴板中没有可粘贴的文本"); return }
        invoke("insertClipboardText", [text])
    }

    // MARK: JavaScript bridge

    private func invoke(_ function: String, _ arguments: [Any] = []) {
        guard isEditorReady, let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.dotmd.\(function).apply(window.dotmd, \(json))")
    }

    private func toast(_ message: String) { invoke("showToast", [message]) }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "editor", message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        let id = body["id"] as? String
        switch type {
        case "ready":
            isEditorReady = true
            // Current editor versions may initialize a welcome tab; replace it with recovery state.
            if let id { invoke("removeTab", [id]) }
            if documents.isEmpty { newDocument() }
            else {
                let entries: [[Any]] = documentOrder.compactMap { id in
                    documents[id].map { [$0.id, $0.title, $0.content, $0.isDirty] }
                }
                invoke("addDocuments", [entries, activeDocumentID ?? ""])
            }
            sendAgentProfiles()
            invoke("configureAgentConsole", [["enabled": false, "access": "read", "helperPath": ""]])
            let urls = pendingURLs; pendingURLs.removeAll(); openFiles(urls)
            if let restoreWarning { showError(restoreWarning); self.restoreWarning = nil }
            refreshActiveDocument()
        case "change":
            guard let id, documents[id] != nil, let content = body["content"] as? String else { return }
            if refreshedDocumentContent.removeValue(forKey: id) == content {
                documents[id]?.content = content
                documents[id]?.lastSavedContent = content
                documents[id]?.isDirty = false
                documents[id]?.hasSaveConflict = false
                scheduleRecovery()
                invoke("markSaved", [id, documents[id]?.title ?? "未命名.md"])
                return
            }
            documents[id]?.content = content
            documents[id]?.isDirty = true
            if documents[id]?.url == nil, let title = body["title"] as? String { documents[id]?.title = title }
            scheduleRecovery(); scheduleAutosave(id)
        case "activate":
            if let id, documents[id] != nil {
                activeDocumentID = id; scheduleRecovery(); refreshActiveDocument()
            }
        case "close": if let id { closeTab(id) }
        case "new": newDocument()
        case "newWithContent":
            let rawTitle = (body["title"] as? String ?? "Agent 总结.md").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = rawTitle.isEmpty ? "Agent 总结.md" : (rawTitle.lowercased().hasSuffix(".md") ? rawTitle : rawTitle + ".md")
            addDocument(IPadDocument(id: UUID().uuidString, title: title,
                content: body["content"] as? String ?? "", isDirty: true))
        case "open": openDocument()
        case "save": saveActiveDocument()
        case "saveAs": saveActiveDocumentAs()
        case "share": shareDocument()
        case "exportHTML": exportHTML()
        case "exportPDF": exportPDF()
        case "print": printDocument()
        case "exportDOCX": exportDOCX(body)
        case "pasteRequest": pasteClipboard()
        case "copySelection", "copyText":
            UIPasteboard.general.string = body["text"] as? String ?? ""
            if type == "copyText" { toast("已复制") }
        case "copyFormula": copyFormula(body)
        case "saveAgentProfiles": saveAgentProfiles(body)
        case "agentRun": runAgents(body)
        case "agentPlanWorkflow": planAgentWorkflow(body)
        case "agentWorkflowRun": runAgentWorkflow(body)
        case "agentFormat": suggestDOCXLayout(body)
        default: break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "about", url.absoluteString == "about:blank" { decisionHandler(.allow); return }
        if url.isFileURL, let root = editorRoot,
           url.standardizedFileURL.path.hasPrefix(root.path + "/") { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        flushRecovery()
        refreshedDocumentContent.removeAll()
        isPreparingExport = false
        webView.isUserInteractionEnabled = true
        isEditorReady = false
        webView.reload()
    }

    // MARK: Agent calls; remote transfer requires a visible decision for every run.

    private func sendAgentProfiles() {
        guard let data = try? JSONEncoder().encode(agentService.loadProfiles()),
              let object = try? JSONSerialization.jsonObject(with: data) else { return }
        invoke("configureAgents", [object])
    }

    private func saveAgentProfiles(_ body: [String: Any]) {
        guard let raw = body["profiles"], JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let profiles = try? JSONDecoder().decode([AgentProfile].self, from: data) else {
            toast("Agent 配置格式无效"); return
        }
        do {
            try agentService.saveProfiles(profiles, keys: body["keys"] as? [String: String] ?? [:])
            sendAgentProfiles(); toast("Agent 配置已安全保存")
        } catch { showError("无法保存到钥匙串：\(error.localizedDescription)") }
    }

    private func confirmTransfer(profileIDs: [String], description: String) async -> Bool {
        let remote = agentService.loadProfiles().filter { profile in
            let host = URLComponents(string: profile.endpoint)?.host?.lowercased() ?? ""
            return profile.enabled && profileIDs.contains(profile.id)
                && host != "localhost" && host != "127.0.0.1" && host != "::1"
        }
        guard !remote.isEmpty else { return true }
        let recipients = remote.map { "• \($0.name) — \(URLComponents(string: $0.endpoint)?.host ?? "自定义地址")" }.joined(separator: "\n")
        let choice = await choose(title: "本次将向第三方 Agent 发送内容",
            message: "接收方：\n\(recipients)\n\n发送范围：\(description)。多 Agent 模式会分别发送给多个服务。请勿发送不允许外传的资料，仅本次执行有效。",
            actions: [("同意本次发送", .default), ("取消", .cancel)])
        return choice == 0
    }

    private func runAgents(_ body: [String: Any]) {
        let ids = body["profileIDs"] as? [String] ?? []
        let instruction = body["instruction"] as? String ?? "修正选中内容"
        let selection = body["selection"] as? String ?? ""
        let context = body["context"] as? String ?? ""
        let mode = body["mode"] as? String ?? "single"
        let purpose = body["purpose"] as? String ?? "edit"
        Task {
            guard await confirmTransfer(profileIDs: mode == "single" ? Array(ids.prefix(1)) : ids,
                description: "任务要求、选中文字（\(selection.count) 字）及文稿上下文（\(context.count) 字）") else { return }
            invoke("setAgentBusy", [true])
            let answers = await agentService.runSelectedAgents(profileIDs: ids, instruction: instruction,
                selection: selection, context: context, mode: mode)
            invoke("setAgentBusy", [false])
            guard let data = try? JSONEncoder().encode(answers), let object = try? JSONSerialization.jsonObject(with: data) else {
                toast("Agent 返回结果无法解析"); return
            }
            invoke("showAgentResults", [object, purpose])
        }
    }

    private func planAgentWorkflow(_ body: [String: Any]) {
        let id = body["profileID"] as? String ?? ""
        let goal = body["goal"] as? String ?? ""
        guard !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, goal.count <= 1500 else {
            toast("请写一句不超过 1500 字的目标。"); return
        }
        Task {
            guard await confirmTransfer(profileIDs: [id], description: "工作流程目标（\(goal.count) 字）与已启用的 Agent 名称；不含文稿正文") else { return }
            invoke("setWorkflowPlanning", [true])
            let answer = await agentService.designWorkflow(profileID: id, goal: goal)
            invoke("setWorkflowPlanning", [false])
            invoke("showWorkflowProposal", [answer.text, answer.error ?? ""])
        }
    }

    private func runAgentWorkflow(_ body: [String: Any]) {
        guard let raw = body["workflow"], JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let workflow = try? JSONDecoder().decode(AgentWorkflow.self, from: data) else {
            toast("工作流程格式无效；没有发送文稿。"); return
        }
        let selection = body["selection"] as? String ?? ""
        let context = body["context"] as? String ?? ""
        let purpose = body["purpose"] as? String ?? "edit"
        Task {
            let ids = Array(Set(workflow.stages.flatMap(\.profileIDs)))
            guard await confirmTransfer(profileIDs: ids,
                description: "工作流程要求、选中文字（\(selection.count) 字）、文稿上下文（\(context.count) 字），以及步骤之间的 Agent 答案") else { return }
            invoke("setAgentBusy", [true])
            let results = await agentService.runWorkflow(workflow, selection: selection, context: context)
            invoke("setAgentBusy", [false])
            guard let data = try? JSONEncoder().encode(results), let object = try? JSONSerialization.jsonObject(with: data) else {
                toast("工作流结果无法解析"); return
            }
            invoke("showWorkflowResults", [object, purpose])
        }
    }

    private func suggestDOCXLayout(_ body: [String: Any]) {
        let id = body["profileID"] as? String ?? ""
        let prompt = body["prompt"] as? String ?? ""
        let settings = body["settings"] as? [String: Any] ?? [:]
        guard !id.isEmpty, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              JSONSerialization.isValidJSONObject(settings),
              let data = try? JSONSerialization.data(withJSONObject: settings),
              let settingsJSON = String(data: data, encoding: .utf8) else {
            invoke("showDocxAgentSuggestion", ["", "请先输入排版要求并选择 Agent。"]); return
        }
        Task {
            guard await confirmTransfer(profileIDs: [id], description: "排版要求（\(prompt.count) 字）与当前排版设置；不含文稿正文") else {
                invoke("showDocxAgentSuggestion", ["", "您取消了本次发送。"]); return
            }
            let answer = await agentService.suggestExportLayout(profileID: id, requestText: prompt,
                                                                 currentSettingsJSON: settingsJSON)
            invoke("showDocxAgentSuggestion", [answer.text, answer.error ?? ""])
        }
    }

    // MARK: Presentation and hardware keyboard

    private func choose(title: String, message: String,
                        actions: [(String, UIAlertAction.Style)]) async -> Int {
        guard presentedViewController == nil else { toast("请先关闭当前弹窗后重试"); return -1 }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            for (index, action) in actions.enumerated() {
                alert.addAction(UIAlertAction(title: action.0, style: action.1) { [weak alert] _ in
                    guard let alert else { continuation.resume(returning: index); return }
                    // A save-as picker may be presented immediately by the caller.
                    // Resume only when this alert has left the presentation stack.
                    alert.dismiss(animated: true) { continuation.resume(returning: index) }
                })
            }
            present(alert, animated: true)
        }
    }

    private func showError(_ message: String) {
        guard isViewLoaded, view.window != nil, presentedViewController == nil else { toast(message); return }
        let alert = UIAlertController(title: "DOT MD", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        let definitions: [(String, UIKeyModifierFlags, Selector, String)] = [
            ("n", .command, #selector(newDocument), "新建文稿"),
            ("t", .command, #selector(newDocument), "新建标签页"),
            ("o", .command, #selector(openDocument), "打开文稿"),
            ("s", .command, #selector(saveActiveDocument), "保存"),
            ("s", [.command, .shift], #selector(saveActiveDocumentAs), "另存为"),
            ("w", .command, #selector(closeActiveDocument), "关闭标签页"),
            ("p", .command, #selector(printDocument), "打印"),
            ("p", [.command, .shift], #selector(exportPDF), "导出 PDF"),
            ("e", [.command, .shift], #selector(exportHTML), "导出 HTML"),
            ("f", .command, #selector(findText), "查找与替换"),
            (",", .command, #selector(openSettings), "设置"),
            ("\t", .control, #selector(nextTab), "下一个标签页"),
            ("\t", [.control, .shift], #selector(previousTab), "上一个标签页")
        ]
        return definitions.map { input, flags, action, title in
            let command = UIKeyCommand(input: input, modifierFlags: flags, action: action)
            command.discoverabilityTitle = title
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }

    @objc private func findText() { invoke("openSearchTools") }
    @objc private func openSettings() { invoke("openSettings") }
    @objc private func nextTab() { invoke("cycleTab", [1]) }
    @objc private func previousTab() { invoke("cycleTab", [-1]) }
}
