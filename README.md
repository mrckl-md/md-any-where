# md any where

md any where 是支持 macOS、iPhone 和 iPad 的 Markdown、学术公式与 AI 写作工作台。macOS 可通过 MCP / CLI 接入 Codex、Claude Code、Cursor 等 AI 编辑器；iPhone/iPad 使用内置 Agent 完成润色、校对、总结与文字工作流。编辑与预览在本机进行，可选 Agent 在用户确认后连接自己配置的服务。项目自有源码采用 [MIT 许可证](LICENSE)，第三方组件保留各自许可。

项目仓库：[mrckl-md/md-any-where](https://github.com/mrckl-md/md-any-where)。截至 2026-10-06，本次发布目标为移动版 `1.0.0 (6)`、`app.mdanywhere.mobile`，macOS `1.0.0 (5)`、`app.mdanywhere.editor`。最终审查已修复 Agent 重定向泄露、Agent/公式错文稿与过期选区、搜索标签切换与 Unicode 偏移、未知文稿 ID 写入、危险 Markdown 链接五类问题；本机网络、真实 WebKit、草稿存储及多语言布局回归通过。iOS build 6 开发签名归档及发行重签 IPA 导出、macOS build 5 构建与严格深层 ad-hoc 签名已验证；iPhone/iPad 模拟器安装、启动和公开示例画面验证通过；移动 build 6 已于 2026-10-06 成功上传新记录，Apple 已完成处理，TestFlight 状态为“准备提交”，已关联商店版本 1.0.0；尚未送审或发布。新商店记录 `6819394741` 已保存基础资料与简中两张截图。详见 [App Store 发布准备](Docs/App-Store-Release.md)。

## 已实现

核心编辑器由三个平台共用；移动版使用系统“文件”选择器、分享面板、触摸工具栏、内置 Agent 和草稿恢复。窗口拖动、Finder Quick Look、本机 MCP / CLI 控制台与液态玻璃窗口材质属于 macOS 功能。移动端的 Agent 调用不表示手机或平板能运行桌面 IDE/MCP 宿主。

三端界面覆盖 Apple 当前的 50 个商店语言/地区项，离线打包 47 份语言目录，每份 584 条界面与原生提示。默认跟随系统，也可在设置中手动选择语言；阿拉伯语、希伯来语和乌尔都语使用从右到左界面。切换语言保留文稿、撤销记录和未保存的设置输入。译文已做重点语义检查，尚未完成全部语言的母语审校；详见 [多语言实现与验证](Docs/Localization.md)。语言支持不等于所有国家/地区已获准发行。

- CodeMirror 编辑器：撤销/重做、精确/忽略大小写/模糊查找、替换当前/全部替换、自动补括号、列表回车延续、行号与软换行
- 每标签页独立的滚动操作时间线：顶部回退/前进、操作记录列表、指定步骤跳转；设置中可选择保留 5–100 步，默认 10 步
- 浏览器式多标签窗口：多选打开文件、独立撤销历史/光标/滚动位置、未保存标记、拖拽排序
- 非全屏状态可从顶栏所有非按钮/非标签页区域拖动窗口（包括工具栏与标签栏空白处）；编辑器选区会在右侧预览中同步定位并高亮
- 标签页可独立保存和自动保存，支持关闭确认；macOS 支持恢复最近关闭的标签页，iPhone/iPad 保存本机草稿供重启恢复
- 编辑器 / 分栏 / 阅读三种模式，支持 `⌘1`、`⌘2`、`⌘3` 快速切换
- 修复“仅预览”模式进入零宽网格列而不可见的问题；三种视图与大纲开关可任意组合
- Markdown 实时预览：表格、任务列表、脚注、本地相对链接、代码高亮；出于隐私与安全考虑，不渲染原始 HTML，也不自动识别或打开外部网页链接
- 离线 Mermaid 风格流程图：支持 `flowchart` / `graph`、TD/TB/BT/LR/RL 方向、常用节点与分支标签；按文档层级排版，连线从节点边缘进出，循环边绕行，不加载网页脚本。当前是常用流程图语法子集，不包含 Mermaid 的所有图种和高级指令
- 内置沙盒化 Quick Look 预览扩展；Finder 使用 AppKit 原生文本排版，不再依赖沙盒中可能崩溃的 WebKit 子进程。普通标题、段落、列表、引用与行内样式可读；复杂流程图在 Quick Look 中显示源码与提示，完整图形请在 md any where 内查看
- 离线 KaTeX：`$...$`、`$$...$$`、`\(...\)`、`\[...\]`，支持矩阵、对齐、宏等常用 LaTeX
- 标题大纲、同步滚动、字数/字符数、光标位置
- 原生打开、保存、另存为与已打开文件自动保存
- HTML、PDF 与 Word/WPS 共用的标准 `.docx` 导出；保留标题层级、列表、表格、代码、引用、可编辑公式及可读取的本地图片
- Word/WPS 导出支持字体、字号、对齐、行距、段距、首行缩进、纸张、页边距和页码设置；提供预设及一句话排版要求
- DOCX 正文、标题、公式分别指定中文与英文字体，例如正文中文宋体、英文 Times New Roman；代码字体另设，混排内容不必手工分段
- 跟随系统的明暗主题、编辑字号、阅读宽度等偏好
- 全新蓝色纸页与 MD 艺术字图标：叠放文稿、折角与暖色输入光标分别表达多文件、预览和编辑；Dock 与标题栏使用同一矢量稿
- 设置项采用 macOS 式分组行与开关；对话框和工具栏控件共用交互颜色、焦点/禁用状态，窄窗口下工具栏保持单行
- 可在设置中启用液态玻璃效果；macOS 26 使用系统玻璃材质，旧系统自动回退，并尊重“降低透明度”辅助功能
- 多供应商 Agent：OpenAI Responses、Anthropic、Gemini、DeepSeek、GLM、Grok 与本地 Ollama/LM Studio
- Agent 服务启用、端点、模型和 API Key 统一在“设置 → Agent 与模型”管理；Agent 编辑台只保留实际写作任务、工作流和结果
- 单 Agent、并行评审和“并行提案 → 主 Agent 共识合并”三种模式；端点与模型名均可修改
- 可视化文字工作流：最多五张线性步骤卡片，可逐步或并行运行、自定义每步提示词，也可让 Agent 先生成流程供用户确认
- 内置本机 `md-any-where-agent` 控制台与 MCP stdio 服务，Codex CLI、Claude Code、Cursor、OpenCode、DeepSeek Harness 等兼容平台无需读屏即可操作已打开文稿
- Agent 支持全文语义查找与全文总结；总结结果可一键生成新的、未保存的 `.md` 标签页
- API Key 持久存入系统钥匙串；运行时发送范围由任务决定，可能包括选区、上下文或全文，远程发送前明确确认
- 默认不启用任何 Agent；远程 Agent 只允许 HTTPS，本地 HTTP 只允许 localhost/回环地址；请求不自动跟随 HTTP 重定向
- 公式助手：Unicode 数学符号与简单分式自动转换为 LaTeX，支持 Agent 生成、修正和解释公式
- 多格式公式剪贴板：同时提供 LaTeX、MathML、HTML 与 SVG，面向 Word、WPS、LibreOffice、MathType 和 Overleaf

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `⌘C` / `⌘X` / `⌘V` | 复制 / 剪切 / 粘贴；Markdown 编辑器使用原生剪贴板桥接，其他输入框和系统文件对话框使用 macOS 标准响应链 |
| `⌘S` | 保存当前文稿 |
| `⌘A` / `⌘D` | 全选 / 取消选择（同时取消预览高亮） |
| `⌘Z` / `⌘⇧Z` | 回退 / 前进 |
| `⌘⌥Z` | 打开操作记录列表 |
| `⌘B` / `⌘I` / `⌘K` | 粗体 / 斜体 / 链接 |
| `⌘⇧M` | 插入块级 LaTeX |
| `⌘⇧G` | 插入 Mermaid 流程图 |
| `⌘⌥1` | 一级标题 |
| `⌘F` | 查找与替换（精确、忽略大小写、模糊、Agent） |
| `⌘⌥F` | 打开查找与替换并直接定位到替换输入框 |
| `⌘S` / `⌘⇧S` | 保存 / 另存为 |
| `⌘T` / `⌘W` | 新建 / 关闭标签页 |
| `⌘⇧T` | 恢复最近关闭的标签页 |
| `⌃Tab` / `⌃⇧Tab` | 下一个 / 上一个标签页 |
| `⌘1` … `⌘9` | 直接切换到第 1…9 个标签页 |
| `⌘⇧1` / `⌘⇧2` / `⌘⇧3` | 编辑 / 分栏 / 预览 |
| `⌘⇧L` | 显示或隐藏大纲 |
| `⌘⇧A` | 打开 Agent 编辑台 |
| `⌘⌥M` | 打开公式转换器 |
| `⌘⇧D` | 打开 Word / WPS 导出设置 |

## Agent 配置与集群

在 Mac 打开“md any where → 设置… → Agent 与模型”，在 iPhone/iPad 打开“文稿 → 设置与 Agent…”，勾选需要使用的服务并填写模型、端点和 API Key，保存后返回 Agent 编辑台运行任务。密钥通过系统 Keychain 保存，不进入工程、Markdown 或 `UserDefaults`。OpenAI 使用 Responses API 且请求设置 `store: false`；DeepSeek、GLM、Grok 和本地服务使用 OpenAI-compatible Chat Completions；Anthropic 与 Gemini 使用各自原生协议。

- **单 Agent**：只调用第一个已勾选的 Agent。
- **并行评审**：同时调用所有已勾选 Agent，分别展示结果。
- **Agent 集群**：先并行生成候选，再让第一个 Agent 作为主席对候选进行校验和共识合并。该模式会增加一次合并调用。

## Codex / Claude Code / Cursor / OpenCode 控制台

在“设置 → Agent 控制台”中明确启用，并选择“仅读取”或“读取与编辑”。界面会按所选平台生成可复制的 MCP 接入命令或 JSON。对 Agent 平台仍使用标准 MCP stdio；主应用与随包辅助程序之间只在控制台启用期间绑定 `127.0.0.1:57362`，不监听局域网或互联网地址，关闭控制台即停止监听。

它只列出和操作已经由用户在 md any where 中打开的标签页，不能扫描磁盘，也不能绕过系统文件选择器。未保存的新文稿仍需用户通过“另存为”选择位置。除状态检查外，每次控制台操作都会在 md any where 内显示确认框；本机连接的进程身份无法可靠核验，因此只应批准自己发起的操作。提供的 MCP 工具有状态检查、文稿列表、受限读取、新建文稿、全文替换、追加、流程图插入、字面查找替换和保存；读工具与写工具带有相应 MCP 注解，方便宿主 Agent 应用审批策略。完整命令及安全模型见 [Agent 控制台文档](Docs/Agent-Console.md)。

## 公式复制

选中公式后按 `⌘⌥M`。可先做离线规范化，也可交给 Agent 把自然语言或错误公式转换为 LaTeX。复制时应用会一次写入多种剪贴板类型：Word/WPS 建议先插入公式框并选择 LaTeX 输入，再粘贴以保持可编辑；MathML 适用于 LibreOffice/MathType；SVG 用于不支持可编辑数学格式但要求外观一致的场景。

## Word / WPS 导出与排版

点击工具栏的 `DOCX` 或按 `⌘⇧D`，选择预设或自定义排版，再点击“导出 .docx…”。Word 和 WPS 都可以直接打开此标准文件并继续编辑；本应用不生成专有的 `.wps` 文件。字体名称会写入文档，目标电脑若未安装该字体，编辑软件可能使用替代字体。

“正文”“标题”“公式”各有中文和英文字体输入框。导出时正文与标题分别写入 OOXML 的 `eastAsia`（中文）和 `ascii`/`hAnsi`（西文）字体槽；公式文字也分别写入这两种槽位，公式英文字体另作为文档级数学字体。可以将正文中文设为宋体、英文设为 Times New Roman，并单独选择公式英文字体。Times New Roman 并非所有公式结构都支持的数学专用字体，Word/WPS 可能将分式、根号或运算符替换为兼容字体；要尽量保持复杂公式的字体外观，建议选 Cambria Math 等数学字体。

在“一句话排版要求”输入诸如“A4，正文宋体小四，1.5 倍行距，首行缩进两字，标题黑体居中，页脚页码”。“本机识别常见要求”离线解析常用规则；已配置 Agent 时可选择一个服务，点击“Agent 生成设置”理解更自由的描述。Agent 仅接收排版要求和当前设置，不接收文稿正文；建议先显示供用户确认，点击“应用这些设置”后才更改导出配置。导出目标通过系统保存对话框由用户单独选择。

KaTeX 公式导出为 Word 可编辑数学结构。嵌入式图片和已获授权文件夹内可读取的本地图片会进入 DOCX；无法读取或远程图片只保留说明文字，不向外部图片地址发起请求。

Mermaid 流程图可在应用内、HTML 和 PDF 中显示，并在 DOCX 中以白底 PNG 图片保留。流程图图片不能在 Word 中逐个编辑节点；若转换失败，会提示并保留可编辑的原始流程图代码。转换全程离线。Finder Quick Look 使用容量受限（前 1 MiB）的原生离线预览器，不保证与应用内的公式、表格及流程图排版完全一致。

## 隐私与权限

- 普通编辑、查找、离线预览和导出不依赖开发者服务器；当前代码不含广告、遥测或行为分析上传。
- 文稿权限来自用户选择的文件/文件夹或主动打开操作。使用 iCloud Drive 等文件提供商时，同步与备份受该服务和系统设置控制。
- iPhone/iPad 会在应用私有容器保存当前标签页的恢复副本；偏好与工作流要求保存在本机，API Key 持久保存在系统钥匙串。
- 远程 Agent 默认停用；每次运行前展示接收方与范围并征求本次同意。服务商可能保存内容、IP 或关联 API 账户，不能据“无开发者服务器”宣称所有数据都不被收集。
- macOS MCP 控制台默认关闭，仅监听本机回环地址；文稿读写另需用户确认。移动版不提供此控制台。

保存、删除、备份、剪贴板和第三方数据处理的完整说明见 [隐私政策](PRIVACY.md)。`PrivacyInfo.xcprivacy` 是源码声明，不能代替按实际第三方行为完成的 App Store 隐私申报。

## macOS 构建

`Sources/`、`Support/`、`Package.swift` 与 `scripts/` 是完整的编译前源码，修改功能时只编辑这些文件；`.build/` 和 `dist/` 是随时可以删除并重新生成的编译产物。应用自己的 Swift、HTML、CSS 和 JavaScript 均以未压缩源码保存，构建脚本不会把它们压缩或混淆。`vendor/` 内带 `.min` 的文件是第三方项目官方发布包，并非 md any where 业务源码，其对应许可证完整保留。

本机需要 macOS 13 或以上、Swift 6 和 Apple Command Line Tools 或 Xcode。构建脚本使用本机架构；若安装了已验证的 macOS 15.4 SDK，会优先使用它以规避当前预览版 SDK 的编译问题，否则使用系统默认 SDK。可用 `MD_ANY_WHERE_SDK_PATH` 覆盖。运行：

```sh
./scripts/build-app.sh
```

产物位于 `dist/md any where.app`。打包先在临时目录完成并验证签名，原有同名产物会重命名保留，不会直接删除。当前构建使用 ad-hoc 签名，交给其他 Mac 前应使用团队的 Apple Developer 证书进行签名与公证。已打开的旧版应用不会被构建脚本自动退出，请先保存文稿并正常退出，再启动新版。

图标主稿是 `Sources/MDAnyWhere/Resources/Brand/MD-Any-Where-Mark.svg`。`scripts/build-icon.sh` 使用 AppKit 从矢量稿分别渲染 16–1024 px 的 macOS 图标尺寸，并生成 `AppIcon.icns`；`build-app.sh` 会自动先执行该步骤。现有 `.icns` 兼容 macOS 13 起的开发包；正式提交新版系统应用图标时，发布团队还可从同一矢量稿制作 Icon Composer 的分层和外观变体。

最终审查新增 `./scripts/test-agent-transport.sh`：使用本机假数据验证重定向不会转发正文或认证头，并检查 4 MiB 响应边界；`./scripts/test-editor-safety.sh` 在真实 WebKit/CodeMirror 中验证异步结果目标、查找替换及 Markdown 链接安全。测试不访问真实 API Key 或收费服务。

可运行 `node scripts/test-fuzzy-search.cjs` 验证有界模糊查找，`node scripts/test-mermaid-flowchart.cjs` 检查离线流程图解析与 SVG，`node scripts/test-bridge-contract.cjs` 检查 Swift/JavaScript 消息桥和导出界面的 DOM ID，`node scripts/test-agent-console.cjs` 检查 MCP 握手与工具目录，`node scripts/test-quicklook-contract.cjs` 检查打包后的 Quick Look 扩展、文件类型与签名，`./scripts/test-quicklook-native.sh` 检查原生预览控制器确实生成内容，`node scripts/test-workflow.cjs` 检查文字工作流，`node scripts/test-docx-fonts.cjs` 测试字体设置迁移与一句话识别，`./scripts/test-docx-fonts.sh` 构造并检查实际 DOCX 字体 XML，`./scripts/test-docx-flowchart.sh` 在真实 WebKit 中导出公开示例并检查 DOCX 流程图图片、公式、表格及失败回退，`node --check Sources/MDAnyWhere/Resources/*.js` 检查应用 JavaScript；`scripts/format-css.mjs` 用于机械格式化项目 CSS。源码组件、消息桥和性能边界见 [ARCHITECTURE.md](ARCHITECTURE.md)，社区贡献的命名与验证流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

在 Finder 中双击项目根目录的 `启动 md any where.command` 可一键启动应用；若 `/Applications/md any where.app` 已安装，会优先打开它，避免生成重复副本；否则在尚未构建时先自动执行构建脚本。
若目录中有单独打包的 `dist/md any where 更新版.app`，请先保存文稿并正常退出旧版，再双击 `安装 md any where 更新版.command`。脚本会先确认应用未运行、核对更新版签名、备份原应用，然后安装并打开新版；若无法读取进程状态则拒绝替换。

## iPhone / iPad 构建与本机部署

移动版最低支持 iOS / iPadOS 17，工程为 `MDAnyWhere-iOS.xcodeproj`，scheme 为 `MDAnyWhere-iOS`，Bundle ID 为 `app.mdanywhere.mobile`；macOS 主应用标识为 `app.mdanywhere.editor`。移动版不包含 macOS 的 `md-any-where-agent`、MCP 控制台或 Finder Quick Look 扩展。

需要完整 Xcode、iOS SDK 和 `devicectl`。无需证书的模拟器构建：

```sh
./scripts/build-ios.sh simulator
```

产物为 `.build/ios/simulator/Build/Products/Debug-iphonesimulator/md any where.app`。脚本只编译；在 Xcode 打开工程并选择 iPhone 或 iPad 模拟器即可运行。

真机首次部署前，在 Xcode 的“Settings → Apple Accounts”登录并确认开发签名团队；通过线缆连接目标设备、解锁并信任 Mac。在设备的“设置 → 隐私与安全性 → 开发者模式”开启后按提示重启确认。在 Xcode 的“Open Developer Tool → Device Hub”（旧版为“Window → Devices and Simulators”）选中目标 iPhone/iPad，复制 Identifier（UDID），替换下面占位值：

```sh
export MD_ANY_WHERE_TEAM_ID='你的10位团队ID'
export MD_ANY_WHERE_DEVICE_UDID='目标iPhone或iPad的UDID'
./scripts/deploy-ios.sh
```

脚本要求显式 UDID，不会自动选择其他设备。它允许 Xcode 更新开发描述文件和注册指定设备，再通过 `devicectl` 安装并启动。只构建真机应用可运行 `./scripts/build-ios.sh device`。产物在 `.build/ios/device/Build/Products/Debug-iphoneos/md any where.app`，日志在 `.build/ios/logs/`。开发者模式的开启和重启确认必须在设备端完成；签名到期后需要重新部署。

使用通用 iOS 脚本与 `MD_ANY_WHERE_TEAM_ID`、`MD_ANY_WHERE_DEVICE_UDID` 参数。应用标识变化后，系统可能将其视为另一应用，不能假定历史安装的草稿或钥匙串会自动迁移；安装前请先将需要保留的文稿保存到可访问的文件位置。移动设备上的 localhost 指向设备自身，不能直接调用相连 Mac 的 Ollama/LM Studio。

上述是本地开发部署，不是 TestFlight 或 App Store 分发。App Store 的归档、元数据、截图和人工提交事项见 [发布准备](Docs/App-Store-Release.md)。

## 第三方组件

应用离线打包了 CodeMirror 5、markdown-it、markdown-it-footnote、markdown-it-task-lists、markdown-it-texmath、KaTeX 与 highlight.js。它们的许可证见 `THIRD_PARTY_NOTICES.md`。

## 开源与 App Store 发布

项目自有代码采用 [MIT](LICENSE)；依赖许可和版权说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。公开前仅提交源码、资源和文档，不提交个人文稿、证书、描述文件、API Key、设备日志或构建目录。

[App Store 发布准备](Docs/App-Store-Release.md)、[50 项商店本地化文案](Docs/AppStore/Localization.md) 和 [截图清单](Docs/AppStore/Screenshots/README.md) 已提供。当前移动目标为 `1.0.0 (6)`、`app.mdanywhere.mobile`，macOS 目标为 `1.0.0 (5)`。新记录 `6819394741` 绑定新标识及 SKU `MD-ANY-WHERE-IOS-001`；简中基础资料、私有审核联系人、不要求登录与手动发布设置已保存。旧记录已停止全部供应并移除，保留历史记录，不恢复。

发行计划为免费、174 个地区，唯一排除中国大陆，港澳台保留，未来新增地区不自动加入；这些供应设置及隐私政策 URL 已在新记录保存。四张中英文截图来自 build 4，所示主界面仍适用；保留实际来源版本。简中两张已上传，新记录两个设备组各 `1/10`；英文两张待上传。

iOS build 6 开发签名归档及发行重签 IPA 导出已成功，最低 iOS 17、iPhone/iPad 设备族、47 × 584 条目录和随包资源一致性已核验；macOS build 5 构建、四组件严格深层 ad-hoc 签名及真实 WebKit DOCX 回归通过。iPhone/iPad 模拟器安装启动、公开示例画面和资源一致性已核验；iPad 真机安装启动成功，iPhone 本版尚未部署。移动 build 6 上传成功，Apple 已完成处理，TestFlight 状态为“准备提交”，已关联商店版本 1.0.0。隐私、年龄、内容版权、DSA、英文名称与可选 AI 私有审核访问仍是待完成的提交事项，不构成暂停构建上传的要求。公开支持邮箱为 [longshenggdgz@163.com](mailto:longshenggdgz@163.com)，商店版权为 `© 2026 陈科霖`；私人审核联系人及凭证不进入仓库。移动 build 6 已于 2026-10-06 成功上传新记录，Apple 已完成处理，TestFlight 状态为“准备提交”，已关联商店版本 1.0.0；尚未送审或发布。
