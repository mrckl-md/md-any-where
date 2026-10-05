#if canImport(DOTMDLocalization)
import DOTMDLocalization
#endif
import AppKit
import Foundation

private enum ConsoleError: LocalizedError {
    case usage(String)
    case transport(String)
    var errorDescription: String? {
        switch self { case .usage(let value), .transport(let value): return value }
    }
}

private func jsonData(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
}

private func writeAll(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return }
        var written = 0
        while written < data.count {
            let count = Darwin.write(descriptor, base.advanced(by: written), data.count - written)
            guard count > 0 else { throw POSIXError(.EIO) }
            written += count
        }
    }
}

private func readExactly(_ count: Int, from descriptor: Int32) throws -> Data {
    var data = Data(count: count)
    var offset = 0
    try data.withUnsafeMutableBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return }
        while offset < count {
            let received = Darwin.read(descriptor, base.advanced(by: offset), count - offset)
            guard received > 0 else { throw POSIXError(.ECONNRESET) }
            offset += received
        }
    }
    return data
}

private func connectToDOTMD() -> Int32? {
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return nil }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(57_361).bigEndian
    inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)
    let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else { Darwin.close(descriptor); return nil }
    return descriptor
}

private func callDOTMD(command: String, arguments: [String: Any]) throws -> [String: Any] {
    let requestID = UUID().uuidString
    let request: [String: Any] = ["version": 1, "state": "request", "id": requestID,
                                  "command": command, "arguments": arguments]
    let requestData = try jsonData(request)

    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let appURL = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard appURL.pathExtension == "app" else {
        throw ConsoleError.transport(L("native.helper.appRequired"))
    }
    let deadline = Date().addingTimeInterval(15)
    var didRequestLaunch = false
    while Date() < deadline {
        if let descriptor = connectToDOTMD() {
            defer { Darwin.close(descriptor) }
            var networkLength = UInt32(requestData.count).bigEndian
            var frame = Data(bytes: &networkLength, count: MemoryLayout<UInt32>.size)
            frame.append(requestData)
            try writeAll(frame, to: descriptor)
            let header = try readExactly(4, from: descriptor)
            let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length <= 10_000_000 else {
                throw ConsoleError.transport(L("native.helper.invalidResponse"))
            }
            let data = try readExactly(Int(length), from: descriptor)
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  value["state"] as? String == "response" else {
                throw ConsoleError.transport(L("native.helper.invalidResponse"))
            }
            return value
        }
        if !didRequestLaunch,
           NSRunningApplication.runningApplications(withBundleIdentifier: "app.dotmd.editor").isEmpty {
            didRequestLaunch = true
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
        }
        Thread.sleep(forTimeInterval: 0.10)
    }
    throw ConsoleError.transport(L("native.helper.timeout"))
}

private let tools: [[String: Any]] = [
    ["name":"dotmd_status", "description":L("native.helper.toolDescription1"),
     "inputSchema":["type":"object", "properties":[:]], "annotations":["readOnlyHint":true]],
    ["name":"dotmd_list_documents", "description":L("native.helper.toolDescription2"),
     "inputSchema":["type":"object", "properties":[:]], "annotations":["readOnlyHint":true]],
    ["name":"dotmd_read_document", "description":L("native.helper.toolDescription3"),
     "inputSchema":["type":"object", "properties":["document_id":["type":"string"], "max_chars":["type":"integer", "minimum":1, "maximum":200000]]], "annotations":["readOnlyHint":true]],
    ["name":"dotmd_create_document", "description":L("native.helper.toolDescription4"),
     "inputSchema":["type":"object", "properties":["title":["type":"string"], "content":["type":"string"]], "required":["content"]], "annotations":["readOnlyHint":false, "destructiveHint":false]],
    ["name":"dotmd_replace_document", "description":L("native.helper.toolDescription5"),
     "inputSchema":["type":"object", "properties":["document_id":["type":"string"], "content":["type":"string"]], "required":["content"]], "annotations":["readOnlyHint":false, "destructiveHint":true]],
    ["name":"dotmd_append_text", "description":L("native.helper.toolDescription6"),
     "inputSchema":["type":"object", "properties":["document_id":["type":"string"], "text":["type":"string"]], "required":["text"]], "annotations":["readOnlyHint":false, "destructiveHint":false]],
    ["name":"dotmd_insert_diagram", "description":L("native.helper.toolDescription7"),
     "inputSchema":["type":"object", "properties":["document_id":["type":"string"], "title":["type":"string"], "diagram":["type":"string", "description":L("native.helper.toolDescription8")]], "required":["diagram"]], "annotations":["readOnlyHint":false, "destructiveHint":false]],
    ["name":"dotmd_find_replace", "description":L("native.helper.toolDescription9"),
     "inputSchema":["type":"object", "properties":["document_id":["type":"string"], "find":["type":"string"], "replace":["type":"string"], "all":["type":"boolean"]], "required":["find","replace"]], "annotations":["readOnlyHint":false, "destructiveHint":true]],
    ["name":"dotmd_save_document", "description":L("native.helper.toolDescription10"),
     "inputSchema":["type":"object", "properties":["document_id":["type":"string"]]], "annotations":["readOnlyHint":false, "destructiveHint":false]]
]

private func mcpResponse(id: Any, result: Any? = nil, error: [String: Any]? = nil) -> [String: Any] {
    var value: [String: Any] = ["jsonrpc":"2.0", "id":id]
    if let result { value["result"] = result }
    if let error { value["error"] = error }
    return value
}

@MainActor private func runMCP() {
    while let line = readLine() {
        guard let data = line.data(using: .utf8),
              let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = request["method"] as? String else { continue }
        let id = request["id"] ?? NSNull()
        if method.hasPrefix("notifications/") { continue }
        let response: [String: Any]
        switch method {
        case "initialize":
            response = mcpResponse(id: id, result: ["protocolVersion":"2025-06-18",
                "capabilities":["tools":["listChanged":false]],
                "serverInfo":["name":"DOT MD", "title":"md any where", "version":"1.0.0"]])
        case "ping": response = mcpResponse(id: id, result: [:])
        case "tools/list": response = mcpResponse(id: id, result: ["tools":tools])
        case "tools/call":
            let params = request["params"] as? [String: Any] ?? [:]
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            let command = String(name.dropFirst(name.hasPrefix("dotmd_") ? 6 : 0))
            do {
                let bridge = try callDOTMD(command: command, arguments: args)
                let ok = bridge["ok"] as? Bool == true
                let payload = bridge[ok ? "result" : "error"] ?? NSNull()
                let text = String(data: try jsonData(payload), encoding: .utf8) ?? "{}"
                response = mcpResponse(id: id, result: ["content":[["type":"text", "text":text]], "isError":!ok])
            } catch {
                response = mcpResponse(id: id, result: ["content":[["type":"text", "text":error.localizedDescription]], "isError":true])
            }
        default: response = mcpResponse(id: id, error: ["code":-32601, "message":L("native.helper.methodNotFound")])
        }
        if let output = try? jsonData(response), let text = String(data: output, encoding: .utf8) {
            print(text); fflush(stdout)
        }
    }
}

private func stdinText() -> String { String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? "" }

@MainActor private func runCLI(_ arguments: [String]) throws {
    guard let verb = arguments.first else { throw ConsoleError.usage(L("native.helper.usage")) }
    if verb == "mcp" { runMCP(); return }
    var command = verb, payload: [String: Any] = [:]
    switch verb {
    case "status": break
    case "list": command = "list_documents"
    case "read": command = "read_document"; if arguments.count > 1 { payload["document_id"] = arguments[1] }
    case "new": command = "create_document"; payload["title"] = arguments.count > 1 ? arguments[1] : L("native.agent.documentTitle"); payload["content"] = stdinText()
    case "replace": command = "replace_document"; if arguments.count > 1 { payload["document_id"] = arguments[1] }; payload["content"] = stdinText()
    case "append": command = "append_text"; if arguments.count > 1 { payload["document_id"] = arguments[1] }; payload["text"] = stdinText()
    case "diagram": command = "insert_diagram"; if arguments.count > 1 { payload["document_id"] = arguments[1] }; payload["diagram"] = stdinText()
    case "find-replace":
        guard arguments.count >= 3 else { throw ConsoleError.usage(L("native.helper.findUsage")) }
        command = "find_replace"; payload["find"] = arguments[1]; payload["replace"] = arguments[2]; payload["all"] = true
        if arguments.count > 3 { payload["document_id"] = arguments[3] }
    case "save": command = "save_document"; if arguments.count > 1 { payload["document_id"] = arguments[1] }
    case "call":
        guard arguments.count >= 2 else { throw ConsoleError.usage(L("native.helper.callUsage")) }
        command = arguments[1]
        if arguments.count > 2, let data = arguments[2].data(using: .utf8),
           let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] { payload = value }
    default: throw ConsoleError.usage(L("native.helper.unknownCommand", verb))
    }
    let response = try callDOTMD(command: command, arguments: payload)
    FileHandle.standardOutput.write(try jsonData(response)); print()
    if response["ok"] as? Bool != true { exit(2) }
}

do { try MainActor.assumeIsolated { try runCLI(Array(CommandLine.arguments.dropFirst())) } }
catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
