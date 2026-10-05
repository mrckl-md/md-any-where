import Foundation
import Security

struct AgentProfile: Codable, Sendable {
    var id: String
    var name: String
    var kind: String
    var endpoint: String
    var model: String
    var enabled: Bool
    var keyPresent: Bool = false
}

struct AgentAnswer: Codable, Sendable {
    var profileID: String
    var name: String
    var text: String
    var error: String?
}

struct AgentWorkflowStage: Codable, Sendable {
    var title: String
    var prompt: String
    var mode: String
    var profileIDs: [String]
}

struct AgentWorkflow: Codable, Sendable {
    var title: String
    var goal: String
    var stages: [AgentWorkflowStage]
}

struct AgentWorkflowResult: Codable, Sendable {
    var title: String
    var answers: [AgentAnswer]
}

// Stateless wrapper: all mutable storage belongs to the system Keychain.
final class KeychainStore: @unchecked Sendable {
    private let service = "app.dotmd.editor.agents"

    func saveSecret(_ value: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            return
        }
        let secret = Data(value.utf8)
        let updateStatus = SecItemUpdate(query as CFDictionary,
                                        [kSecValueData as String: secret] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }
        var item = query
        item[kSecValueData as String] = secret
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    func secret(for account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// Agent calls run concurrently, but this service stores no mutable instance
// state; profiles are loaded from UserDefaults and secrets from Keychain.
final class AgentService: @unchecked Sendable {
    private let defaultsKey = "agentProfiles.v1"
    private let keychain = KeychainStore()

    func loadProfiles() -> [AgentProfile] {
        let saved: [AgentProfile]
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([AgentProfile].self, from: data) { saved = decoded }
        else { saved = Self.defaultProfiles }
        return saved.map { profile in
            var copy = profile
            copy.keyPresent = keychain.secret(for: profile.id) != nil || profile.kind == "local"
            return copy
        }
    }

    func saveProfiles(_ profiles: [AgentProfile], keys: [String: String]) throws {
        for (profileID, apiKey) in keys {
            try keychain.saveSecret(apiKey, account: profileID)
        }
        var profilesWithoutSecretFlags = profiles
        for index in profilesWithoutSecretFlags.indices {
            profilesWithoutSecretFlags[index].keyPresent = false
        }
        UserDefaults.standard.set(try JSONEncoder().encode(profilesWithoutSecretFlags), forKey: defaultsKey)
    }

    func runSelectedAgents(profileIDs: [String], instruction: String, selection: String, context: String,
             mode: String) async -> [AgentAnswer] {
        let selectedProfiles = loadProfiles().filter { profileIDs.contains($0.id) && $0.enabled }
        guard !selectedProfiles.isEmpty else {
            return [AgentAnswer(profileID: "", name: "Agent", text: "", error: "请至少启用并选择一个 Agent。")]
        }
        let system = """
        You are an expert academic Markdown and mathematical notation editor. Preserve factual meaning. When the task concerns a formula, return the final LaTeX only, without dollar delimiters or a code fence, unless the user explicitly asks for explanation. Never invent citations.
        """
        let prompt = """
        用户任务：\(instruction)

        选中内容：
        \(selection.isEmpty ? "（无；请根据上下文处理）" : selection)

        文稿上下文：
        \(context)
        """
        let chosenProfiles = mode == "single" ? Array(selectedProfiles.prefix(1)) : selectedProfiles
        let answers = await withTaskGroup(of: AgentAnswer.self, returning: [AgentAnswer].self) { group in
            for profile in chosenProfiles {
                group.addTask { await self.requestAgentCompletion(profile, system: system, prompt: prompt) }
            }
            var values: [AgentAnswer] = []
            for await answer in group { values.append(answer) }
            return chosenProfiles.compactMap { profile in values.first { $0.profileID == profile.id } }
        }
        guard mode == "consensus", answers.filter({ $0.error == nil }).count > 1,
              let chairProfile = chosenProfiles.first else { return answers }
        let candidates = answers.filter { $0.error == nil }.map { "[\($0.name)]\n\($0.text)" }.joined(separator: "\n\n")
        let mergePrompt = """
        Act as the chair of an editing panel. Compare the candidate answers, correct notation errors, and return one final answer. For formula tasks output LaTeX only.

        Original task: \(instruction)
        Candidates:
        \(candidates)
        """
        let merged = await requestAgentCompletion(chairProfile, system: system, prompt: mergePrompt)
        return answers + [AgentAnswer(profileID: "consensus", name: "集群共识", text: merged.text, error: merged.error)]
    }

    func designWorkflow(profileID: String, goal: String) async -> AgentAnswer {
        let enabled = loadProfiles().filter(\.enabled)
        guard let planner = enabled.first(where: { $0.id == profileID }) else {
            return AgentAnswer(profileID: profileID, name: "流程设计 Agent", text: "", error: "请先启用设计流程的 Agent。")
        }
        let choices = enabled.map { "\($0.name):\($0.id)" }.joined(separator: ", ")
        let system = """
        Design a simple academic text-editing workflow. Return only a JSON object, no Markdown fence: {"title":"短标题","stages":[{"title":"步骤名称","mode":"single或parallel","profileIDs":["已给出的ID"],"prompt":"清楚具体的中文任务"}]}. Use 2 to 5 sequential stages. In parallel stages, listed agents review independently. A final single stage should synthesize the prior answers. Use only listed Agent IDs, never invent an ID. Do not include document content, code, URLs, keys, or special workflow syntax. The user will review the proposal before it runs.
        """
        let prompt = "用户目标：\(goal.prefix(1500))\n可用 Agent（显示名:ID）：\(choices)"
        return await requestAgentCompletion(planner, system: system, prompt: prompt)
    }

    func runWorkflow(_ workflow: AgentWorkflow, selection: String, context: String) async -> [AgentWorkflowResult] {
        let enabled = loadProfiles().filter(\.enabled)
        var profileMap: [String: AgentProfile] = [:]
        for profile in enabled { profileMap[profile.id] = profile }
        guard (1...5).contains(workflow.stages.count), workflow.title.count <= 80,
              workflow.goal.count <= 1500, selection.count <= 100_000, context.count <= 100_000 else {
            return [.init(title: "流程检查", answers: [.init(profileID: "", name: "Agent", text: "", error: "流程或文稿过长；最多 5 步、10 万字。")])]
        }
        // Validate every stage before the first network request, avoiding partial execution.
        for (index, stage) in workflow.stages.enumerated() {
            guard !stage.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  stage.prompt.count <= 1200, stage.title.count <= 60,
                  stage.mode == "single" || stage.mode == "parallel",
                  !stage.profileIDs.isEmpty, stage.profileIDs.count <= 7,
                  Set(stage.profileIDs).count == stage.profileIDs.count,
                  stage.profileIDs.allSatisfy({ profileMap[$0] != nil }),
                  stage.mode != "single" || stage.profileIDs.count == 1 else {
                return [.init(title: "流程检查", answers: [.init(profileID: "", name: "Agent", text: "", error: "第 \(index + 1) 步的要求或 Agent 选择无效；没有发送文稿。")])]
            }
        }
        var results: [AgentWorkflowResult] = []
        var priorAnswers = ""
        for stage in workflow.stages {
            let instruction = "\(stage.prompt)\n\n用户的总目标：\(workflow.goal.isEmpty ? workflow.title : workflow.goal)\n\n前一步的 Agent 答案（供下一步参考）：\(priorAnswers.isEmpty ? "（第一步）" : priorAnswers)"
            let answers = await runSelectedAgents(profileIDs: stage.profileIDs, instruction: instruction,
                                                  selection: selection, context: context, mode: stage.mode)
            results.append(.init(title: stage.title, answers: answers))
            let successful = answers.filter { $0.error == nil }
            if successful.isEmpty { break }
            priorAnswers = successful.map { "[\($0.name)]\n\($0.text)" }.joined(separator: "\n\n").prefix(12_000).description
        }
        return results
    }

    func suggestExportLayout(profileID: String, requestText: String,
                             currentSettingsJSON: String) async -> AgentAnswer {
        guard let profile = loadProfiles().first(where: { $0.id == profileID && $0.enabled }) else {
            return AgentAnswer(profileID: profileID, name: "排版 Agent", text: "",
                               error: "请先启用所选 Agent。")
        }
        let system = """
        You configure DOCX page styles for an academic Markdown editor. Return ONLY one JSON object, no code fence or commentary, with {"settings":{...},"reason":"brief Chinese explanation"}. Allowed font keys (string names): bodyCjkFont and bodyLatinFont for Chinese/English body text, headingCjkFont and headingLatinFont for Chinese/English headings, mathCjkFont and mathLatinFont for Chinese/English equation characters, codeFont for code. Other allowed keys: bodySize (8-24 points); headingScale (1.05-2.4); lineSpacing (1-3); paragraphAfter (0-36 points); firstLineIndent (0-20 millimeters); bodyAlign (left,center,right,justify); headingAlign (left,center,right); pageSize (letter,a4); marginTop,marginBottom,marginLeft,marginRight (10-50 millimeters); pageNumbers (boolean). Include only keys that should change. Interpret Chinese typographic sizes accurately: 小四=12 pt, 五号=10.5 pt, 四号=14 pt. Times New Roman may be requested for equations, but equation layout software can substitute non-math-enabled fonts. Do not alter document content, invent requirements, or include other keys.
        """
        let prompt = """
        用户排版要求：\(requestText.prefix(2000))

        当前排版设置：\(currentSettingsJSON)

        只提出能由上述设置键表示的变更。文稿正文未提供，也不需要。
        """
        return await requestAgentCompletion(profile, system: system, prompt: prompt)
    }

    private func requestAgentCompletion(_ profile: AgentProfile, system: String, prompt: String) async -> AgentAnswer {
        do {
            let apiKey = keychain.secret(for: profile.id) ?? (profile.kind == "local" ? "ollama" : "")
            if apiKey.isEmpty { throw NSError(domain: "Agent", code: 401, userInfo: [NSLocalizedDescriptionKey: "尚未配置 API Key"] ) }
            guard let components = URLComponents(string: profile.endpoint.replacingOccurrences(of: "{model}", with: profile.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profile.model)),
                  let url = components.url else { throw NSError(domain: "Agent", code: 400, userInfo: [NSLocalizedDescriptionKey: "端点 URL 无效"]) }
            let scheme = url.scheme?.lowercased()
            let host = url.host?.lowercased()
            let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
            guard scheme == "https" || (profile.kind == "local" && scheme == "http" && isLoopback) else {
                throw NSError(domain: "Agent", code: 400, userInfo: [NSLocalizedDescriptionKey: "远程 Agent 必须使用 HTTPS；本地 HTTP 仅允许 localhost/回环地址"])
            }
            var httpRequest = URLRequest(url: url, timeoutInterval: 120)
            httpRequest.httpMethod = "POST"
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let requestBody: Any
            switch profile.kind {
            case "openai-responses":
                httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                requestBody = ["model": profile.model, "instructions": system, "input": prompt, "store": false]
            case "anthropic":
                httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                httpRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                requestBody = ["model": profile.model, "max_tokens": 2048, "system": system,
                        "messages": [["role": "user", "content": prompt]]]
            case "gemini":
                httpRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                requestBody = ["systemInstruction": ["parts": [["text": system]]],
                        "contents": [["role": "user", "parts": [["text": prompt]]]],
                        "generationConfig": ["temperature": 0.2]]
            default:
                httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                requestBody = ["model": profile.model, "messages": [["role": "system", "content": system],
                        ["role": "user", "content": prompt]], "temperature": 0.2]
            }
            httpRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (responseBytes, response) = try await URLSession.shared.bytes(for: httpRequest)
            let maximumResponseBytes = 4 * 1024 * 1024
            var responseData = Data()
            responseData.reserveCapacity(min(maximumResponseBytes,
                                             max(0, Int(response.expectedContentLength))))
            for try await byte in responseBytes {
                guard responseData.count < maximumResponseBytes else {
                    throw NSError(domain: "Agent", code: 413,
                                  userInfo: [NSLocalizedDescriptionKey:"Agent 回复超过 4 MiB 限制。"])
                }
                responseData.append(byte)
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseJSON = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
            guard (200..<300).contains(statusCode) else {
                let message = ((responseJSON["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(statusCode)"
                throw NSError(domain: "Agent", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            let text = extractAgentResponseText(responseJSON, kind: profile.kind)
            guard !text.isEmpty else { throw NSError(domain: "Agent", code: 422, userInfo: [NSLocalizedDescriptionKey: "服务未返回文本"]) }
            return AgentAnswer(profileID: profile.id, name: profile.name, text: text, error: nil)
        } catch {
            return AgentAnswer(profileID: profile.id, name: profile.name, text: "", error: error.localizedDescription)
        }
    }

    private func extractAgentResponseText(_ json: [String: Any], kind: String) -> String {
        if kind == "openai-responses" {
            if let value = json["output_text"] as? String { return value }
            let output = json["output"] as? [[String: Any]] ?? []
            return output.flatMap { $0["content"] as? [[String: Any]] ?? [] }.compactMap { $0["text"] as? String }.joined()
        }
        if kind == "anthropic" {
            return (json["content"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
        }
        if kind == "gemini" {
            let candidates = json["candidates"] as? [[String: Any]] ?? []
            let content = candidates.first?["content"] as? [String: Any]
            return (content?["parts"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
        }
        let choices = json["choices"] as? [[String: Any]] ?? []
        return ((choices.first?["message"] as? [String: Any])?["content"] as? String) ?? ""
    }

    static let defaultProfiles: [AgentProfile] = [
        .init(id: "openai", name: "OpenAI", kind: "openai-responses", endpoint: "https://api.openai.com/v1/responses", model: "gpt-5.6-luna", enabled: false),
        .init(id: "anthropic", name: "Anthropic", kind: "anthropic", endpoint: "https://api.anthropic.com/v1/messages", model: "claude-sonnet-4-5", enabled: false),
        .init(id: "gemini", name: "Gemini", kind: "gemini", endpoint: "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", model: "gemini-2.5-flash", enabled: false),
        .init(id: "deepseek", name: "DeepSeek", kind: "openai-chat", endpoint: "https://api.deepseek.com/chat/completions", model: "deepseek-chat", enabled: false),
        .init(id: "glm", name: "GLM", kind: "openai-chat", endpoint: "https://open.bigmodel.cn/api/paas/v4/chat/completions", model: "glm-4-flash", enabled: false),
        .init(id: "grok", name: "Grok", kind: "openai-chat", endpoint: "https://api.x.ai/v1/chat/completions", model: "grok-4-fast-non-reasoning", enabled: false),
        .init(id: "local", name: "本地 Agent", kind: "local", endpoint: "http://127.0.0.1:11434/v1/chat/completions", model: "qwen3:8b", enabled: false)
    ]
}
