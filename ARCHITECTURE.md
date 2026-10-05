# DOT MD 源码导览

DOT MD 的业务代码都是编译前源码。`Resources/vendor/` 是带原始许可证的第三方发布包，贡献者不应直接修改；`dist/` 和 `.build/` 是可重建产物，不应提交到 Git。

## 组件边界

- `AppDelegate.swift`：macOS 窗口、菜单、用户选择的文件权限、保存和 JavaScript 消息桥。原生端保留每个标签页的最新文本，供自动保存和关闭确认使用。
- `Resources/app.js`：CodeMirror 标签页、编辑操作记录、Markdown/KaTeX 实时预览、查找替换与 Agent UI。
- `Resources/index.html` 与 `Resources/styles.css`：控件的语义结构和共享视觉样式。设置项按分组行排版；对话框按钮、输入框、开关、滑杆使用同一交互强调色，深色、降低透明度及降低动态效果另有适配。
- `Resources/Brand/DOT-MD-Mark.svg`：标题栏和 Dock 图标共用的矢量主稿。`scripts/render-icon.swift` 从主稿直接绘制每个尺寸的 PNG，`scripts/build-icon.sh` 打包为 `.icns`；修改品牌时不要只替换编译后的应用资源。
- `Resources/fuzzy-search.js`：独立、可用 Node 测试的有界模糊匹配。长行有计算上限，查询结果限量时会在界面明确提示。
- `AgentService.swift`：各 Agent 的协议适配、并行请求和钥匙串读取。请求只在用户明确点击时发生；排版 Agent 不接收文稿正文。
- `Sources/DOTMDAgent/main.swift`：独立的 `dotmd-agent` 命令行与 MCP stdio 服务。它不链接业务模型；所有操作通过仅限 `127.0.0.1:57361` 的长度分帧通道交由正在运行的主应用重新鉴权和执行。
- `Resources/docx-export.js`：从预览 DOM 提取文稿结构和排版设置。正文、标题、公式的中英文字体分别保留在设置键中；旧版单字体设置只在读取时迁移。
- `DocxExporter.swift`：将结构写为标准 OOXML `.docx`。正文和标题使用 `w:rFonts` 的西文/East Asian 槽，公式另有文档级 `m:mathFont` 和数学文字的中英文字体槽；图片只读取内嵌数据或当前文稿目录下的本地文件，并缩小到适合排版的尺寸。
- `FormulaClipboard.swift`：公式多格式剪贴板。
- `Sources/DOTMDiPad/AppDelegate.swift`：iPhone/iPad 共用的 UIKit Scene 与 WebKit 宿主，负责系统文件选择器、协调保存、分享、打印和 Agent 请求确认。
- `Sources/DOTMDiPad/DocumentStore.swift`：移动端 UTF-8 文件读写、外部修改冲突检查与受保护的会话恢复数据。
- `Resources/ipad.js` 与 `Resources/ipad.css`：移动端触控入口、窄屏布局和键盘视口适配。`scripts/prepare-ipad-resources.py` 只在 iOS 构建副本中加载这两份资源，桌面端继续使用共享编辑器。

`DOTMD-iPad.xcodeproj` 的历史名称和 `app.dotmd.ipad` 标识保持不变；目标同时支持 iPhone 与 iPad。Swift Package 构建 macOS 应用及命令行工具，Xcode 工程构建 iOS 应用。`Sources/DOTMDiPad/PDFRenderer.swift` 使用 UIKit 打印格式器生成带边距的分页 PDF。

iOS 图标从同一品牌矢量稿生成，扩展背景到整个正方形并移除 Alpha 通道，由系统应用外部圆角。重新生成命令：`xcrun swift scripts/render-ios-icon.swift Sources/DOTMD/Resources/Brand/DOT-MD-Mark.svg Support/iPad/Assets.xcassets/AppIcon.appiconset/AppIcon.png`。

## 数据流与性能约束

`CodeMirror change` 更新标签状态并将最新文本同步给原生端；预览渲染经过短暂防抖。大文稿延长渲染间隔，选中高亮使用上一次渲染建立的节点索引。批量打开文件在原生端合并为一次桥调用，JavaScript 只渲染最终激活的标签页。

编辑操作记录按用户设置保留最近 5–100 步，默认 10 步。每步是完整文本快照，便于可靠地跳转到指定操作；因此很大的文稿仍会随步数增加而占用更多内存。改动这部分结构时必须同时验证回退、前进、跨标签切换和未保存提示。

系统选择器是文件权限边界。应用不能自行扫描桌面、文稿或下载目录；WebView 不加载远程图片与网页。只允许选定 Agent 端点上的主动请求，不加入遥测或后台联网。

iOS 的文稿恢复副本保存在应用私有的 `Application Support/DocumentRecovery` 中。未保存草稿会恢复到标签页，已保存文稿通过书签重新访问原文件。磁盘内容发生外部修改时拒绝直接覆盖，用户可另存副本；文件读写通过 `NSFileCoordinator` 协调。macOS 本机 Agent 控制台不包含在 iOS 目标中。

本机 Agent 控制台默认关闭，关闭时不启动监听器。启用后只绑定 IPv4 回环地址，不接受局域网或互联网连接；请求使用 4 字节长度前缀且限制在 1000 万字节以内。主应用只接受固定命令集合。读取有字符上限，写命令要求用户另行选择“读取与编辑”，且只能使用已打开文稿的内部 ID。任何改动都必须维持这些检查，不能把任意路径或任意 JavaScript 执行暴露为 Agent 工具。

## 命名与跨语言接口

自有源码中的内部标识使用英文完整词组和动词开头的函数名，例如 `openMarkdownFiles`、`writeDocumentToDisk`、`renderMarkdownPreview`、`collectDocxBlocks`。布尔变量以 `is`/`has` 开头；带单位或用途的数值写出用途，例如 `maxEdits`、`sourceMappedPreviewBlocks`。`DOCX`、`XML`、`MathML`、`CRC32` 等格式标准名可以保留缩写。

`AppDelegate.swift` 的 `invokeEditorJavaScript` 调用 `window.dotmd`；网页编辑器通过 `sendNativeMessage` 向名为 `editor` 的 WebKit 消息处理器发送类型字符串。`window.dotmd`、`window.dotmdDocx` 的公开属性名，以及 `DocxRun`/`DocxMathNode`/`DocxLayout` 的 JSON 字段，是跨 Swift/JavaScript 的契约。重命名内部函数时，应在桥对象中显式映射旧属性名，或同步修改两侧并添加迁移测试；不要对序列化字段或 DOM ID 做无差别的文本替换。

设置控件保留原生 HTML `input`、`select`、`button` 的语义和键盘操作；开关只是用 CSS 呈现为 macOS 风格，不要改写为无语义的点击区域。新增控件优先复用共享样式与 `--control-*` 变量，并检查深浅色、焦点、禁用状态及较窄窗口。

编辑菜单的复制、剪切、粘贴和全选必须保持 `NSMenuItem.target == nil`，以便系统响应链把命令交给当前焦点的输入框或原生文件对话框。CodeMirror 编辑区单独使用 `extraKeys` 与剪贴板桥；不要再给标准编辑菜单项默认绑定 `AppDelegate`，否则其他输入框的快捷键会被截走。

## 本机验证

运行 `node scripts/test-fuzzy-search.cjs` 检查模糊匹配，`node scripts/test-bridge-contract.cjs` 检查跨语言接口和 DOCX DOM ID，`node scripts/test-agent-console.cjs` 检查 MCP 握手与工具目录，使用 `node --check Sources/DOTMD/Resources/*.js` 检查自己的 JavaScript，并运行 `./scripts/build-app.sh` 构建。构建脚本自动使用本机 macOS SDK 和架构，不要求固定 SDK 路径。涉及 DOCX 的变更应以 Word/WPS 或 LibreOffice 打开实际产物，检查文字、公式、表格和图片。

移动端使用 `./scripts/build-ios.sh simulator` 构建，`./scripts/test-mobile-layout.sh` 检查实际 WebKit 在手机、平板及键盘压缩视口下的布局。`tests/fixtures/mobile-demo.md` 是不含个人数据的演示文稿，可用于真机导入、编辑保存、公式/流程图预览及导出检查。WebKit 布局测试不能代替真机键盘、系统文件选择器和系统分享测试。
