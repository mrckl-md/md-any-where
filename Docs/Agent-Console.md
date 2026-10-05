# md any where Agent 控制台

md any where 的 macOS 版同时提供标准 MCP stdio 服务和直接命令行，可接入 Codex、Claude Code、Cursor、OpenCode 等 AI 编辑器与 Agent 平台。iPhone/iPad 使用应用内置 Agent，不提供桌面 MCP / CLI 宿主。macOS 上兼容平台使用同一可执行文件：

```text
/Applications/md any where.app/Contents/MacOS/md-any-where-agent
```

实际路径由“设置 → Agent 控制台”自动生成，不需要手写或猜测。当前新命名与构建 `4` 须重新验证，不把历史进程的响应作为新客户端验证。

## 接入

Codex CLI：

```sh
codex mcp add md-any-where -- '/Applications/md any where.app/Contents/MacOS/md-any-where-agent' mcp
```

Claude Code：

```sh
claude mcp add md-any-where --scope user -- '/Applications/md any where.app/Contents/MacOS/md-any-where-agent' mcp
```

Cursor 使用常见的 `mcpServers` 配置：

```json
{"mcpServers":{"md-any-where":{"command":"/Applications/md any where.app/Contents/MacOS/md-any-where-agent","args":["mcp"]}}}
```

OpenCode：

```json
{"mcp":{"md-any-where":{"type":"local","command":["/Applications/md any where.app/Contents/MacOS/md-any-where-agent","mcp"],"enabled":true}}}
```

Codex 与 ChatGPT desktop 均支持本地 STDIO MCP；Claude Code 通过 `claude mcp add` 添加本地 stdio 服务；OpenCode 的本地 MCP 配置使用命令数组。各平台版本变化时，以其官方文档为准：

- [OpenAI MCP 文档](https://developers.openai.com/codex/mcp/)
- [Anthropic MCP 文档](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Cursor MCP 文档](https://docs.cursor.com/context/model-context-protocol)
- [OpenCode MCP 文档](https://opencode.ai/docs/mcp-servers/)

DeepSeek Harness 或其他 Agent 框架只要支持本地 MCP stdio，就将服务器命令设为 `md-any-where-agent mcp`；如果只支持 shell 工具，也可调用下面的直接命令。

## 直接命令

```sh
md-any-where-agent status
md-any-where-agent list
md-any-where-agent read [文稿ID]
printf '# 新文稿' | md-any-where-agent new '标题.md'
printf '# 完整替换内容' | md-any-where-agent replace [文稿ID]
printf '\n追加内容' | md-any-where-agent append [文稿ID]
printf 'flowchart LR\nA[数据] --> B[训练]' | md-any-where-agent diagram [文稿ID]
md-any-where-agent find-replace '旧文字' '新文字' [文稿ID]
md-any-where-agent save [文稿ID]
md-any-where-agent call read_document '{"max_chars":5000}'
```

所有命令返回 JSON，便于 Agent 判断成功、错误、文稿 ID 和实际修改数量。

## MCP 工具

- `mdanywhere_status`
- `mdanywhere_list_documents`
- `mdanywhere_read_document`
- `mdanywhere_create_document`
- `mdanywhere_replace_document`
- `mdanywhere_append_text`
- `mdanywhere_insert_diagram`：插入不带围栏的 Mermaid `flowchart` / `graph` 源码，md any where 会自动生成 `mermaid` 代码块
- `mdanywhere_find_replace`
- `mdanywhere_save_document`

读取默认最多返回 50,000 字符，调用方可通过 `max_chars` 调整，硬上限为 200,000，避免将整本长文意外塞进 Agent 上下文。

## 安全模型

- 默认关闭；用户必须在 md any where 设置中明确启用。
- “仅读取”和“读取与编辑”分开授权；写命令在只读模式下由应用本身拒绝。
- 默认不监听；用户开启控制台后只绑定 `127.0.0.1:57362`，不接受局域网或互联网连接，关闭即停止。
- 平台侧仍通过 MCP stdio 接入；回环 TCP 只用于随包 `md-any-where-agent` 与主应用之间的本机 IPC，并限制单次请求体积。
- 每次请求使用随机文件名，扩展名为 `md-any-where-agent-command`，UTI 为 `app.mdanywhere.agent-command`；桥目录位于当前用户的 `Application Support/MDAnyWhere/AgentBridge`。文件必须属于当前 macOS 用户，权限不得包含组或其他用户访问位，并限制体积。
- 只操作当前 md any where 已打开文稿；不能遍历目录，不能通过路径打开任意文件。
- 新文稿保存位置仍必须由用户通过 macOS 保存面板选择。
- Agent 宿主自己的工具审批仍然有效；md any where 在此基础上再执行一次本地访问检查。
