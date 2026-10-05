# App Store 发布准备

核对日期：2026-10-06。当前品牌精确为 **md any where**，目标版本 `1.0.0 (4)`。iPhone/iPad 应用标识为 `app.mdanywhere.ios`，macOS 主应用标识为 `app.mdanywhere.editor`；工程为 `MDAnyWhere-iOS.xcodeproj`，scheme 为 `MDAnyWhere-iOS`。macOS 可通过 MCP / CLI 接入 AI 编辑器，移动端提供内置 Agent。新标识已完成 macOS 与 iOS 模拟器构建，适用源码回归和 arm64 Release 开发签名严格验签也已通过。iPad 已安装但启动未确认，iPhone 安装因连接异常失败，App Store 发行归档仍待完成；当前构建尚未上传、送审或发布。

## 当前准备状态

- [源码仓库](https://github.com/mrckl-md/md-any-where)、MIT 许可、七份第三方许可证及版本/哈希清单保留；文档、源模块、工具及资源路径统一使用新命名。
- 现有功能包含系统文件选择/分享、草稿恢复、Keychain、逐次远程 Agent 发送确认和离线本地化资源。现有行为评估可以作为检查依据，但不能替代新标识构建的代码、资源和功能复验。
- [完整隐私政策](../PRIVACY.md)、[隐私草案](AppStore/Privacy-Assessment.md)、[年龄草案](AppStore/Age-Rating-Assessment.md)与[全部 50 项商店文案](AppStore/Localization.md)已准备。文案不是已完成审核或最终问卷。
- **构建 `4` 已验证：** macOS 构建成功，`app.mdanywhere.editor` 及 Quick Look、缩略图、Agent 的新标识已核对，严格深层 ad-hoc 签名检查通过。iOS 模拟器构建成功，标识 `app.mdanywhere.ios`、设备族 `1,2`、47 份 catalog 和 51 个语言目录已核对；目标 iPhone/iPad 模拟器均安装并启动成功。七组 JavaScript 检查及 Agent 打包、Quick Look、Mermaid、原生本地化回归已通过。移动存储 9 项、视口布局 9 项、50 项语言状态保留与 27 组 WebKit 布局、WebKit DOCX 全套回归已通过；arm64 Release 开发签名构建及严格验签也已通过。
- **截图已准备：** 构建 `4` 的简体中文、英文各两张图片已经从实际模拟器应用捕获，展示 iPhone 编辑和 iPad 分栏。尺寸、无 Alpha 通道、无历史标识已核验；简体中文两张已在记录 `6819302567` 替换旧图并上传，iPhone 6.9 英寸与 iPad 13 英寸组各核验为 `1/10`，英文两张尚未上传，详见[截图清单](AppStore/Screenshots/README.md)。历史版本图片已移出当前公开素材，保留于忽略的历史备份。
- **开发签名与真机进度：** 手动描述文件配置先前被拒绝后，本机 Automatic 使用已存描述文件成功完成 Release 构建与开发签名，无需 `-allowProvisioningUpdates`，严格验签通过。产物为 `.build/ios/local-device/Build/Products/Release-iphoneos/md any where.app`。iPad 新标识安装成功，但启动遇到 CoreDevice XPC 服务不可用，尚未确认启动；iPhone 安装因 CoreDevice `4016` 连接异常失败。用户解锁重连后可直接复用此包重试，不需重建。开发签名成功不等于 App Store 分发验证，当前仍无经验证的构建 `4` 发行归档或 IPA。
- **新标识已注册并绑定：** Apple Developer 已注册 `app.mdanywhere.ios`，App Store Connect 记录 `6819302567` 已实际保存绑定。该记录的 SKU 不可编辑，仍保留历史内部编号；其处理方式待用户决定，不在公开材料写出其值，也不宣称云端全部内部字段已完成改名。
- **既有记录的已保存设置：** 免费价格、简体中文名称/副标题/分类/版本文案、政策 URL、私有审核联系人，以及 174 个发行地区；唯一排除中国大陆，香港、澳门、台湾保留，未来新增地区不自动加入（`futureautoinclude = false`）。这些设置此前保存在同一记录，该记录现已成功绑定新标识；已选择地区不等于已获准销售。
- 公开支持邮箱为 [longshenggdgz@163.com](mailto:longshenggdgz@163.com)，商店版权为 `© 2026 陈科霖`。私人审核联系人及凭证不进入公开文件。

## 历史证据的适用范围

历史版本 `1` 曾完成本地 App Store IPA 导出，检查过 Apple Distribution 签名、`get-task-allow = false` 和设备族 `1,2`，但没有上传。该版本真机 PDF 为两页白底，公式、三个流程图节点、表格与尾文目视完整；DOCX 包含 1884 × 480 白底流程图 PNG，XML 中有 OMML、表格、图片关系和尾文。Quick Look 显示正文、图片和表格但不显示 OMML；没有用 Word/WPS 完成公式目视验证。移动存储、布局及 DOCX 图像回归结果仅属于当时版本。

历史版本 `3` 曾完成三端编译、47 × 583 条文案及 50 项语言映射检查、50 项语言切换状态保留、27 组 WebKit 布局，以及 iPhone/iPad 安装；当时 iPhone 启动受到锁屏影响。该版本归档成功，但后续分发导出报 `No Accounts` 与 `No signing certificate`，退出码 `70`。这些错误只说明当时导出进程无法访问所需账号或发行身份，不能证明用户退出登录。成功与失败使用同一本机用户和 Xcode 路径，没有切换 HOME 的证据；具体发行身份取得方式尚未确定。

历史简体中文两张截图曾在既有记录的 iPhone 6.9 英寸和 iPad 13 英寸组各核验为 `1/10`，英文两张仅在本地准备。这两张历史中文图片现已从对应后台设备组删除，并实际替换为构建 `4` 图片；当前上传状态依据新文件名及各 `1/10` 单独核验，英文历史图片继续退休。所有历史结果都不认证构建 `4` 的新应用标识、桥协议、钥匙串范围、安装、资源打包或发行签名。

## 尚需完成

1. 设备解锁重连后，使用已经严格验签的 Release 开发签名包重试 iPad 启动与 iPhone 安装/启动，无需先重建；之后完成物理设备交互验收。标识变化可能形成独立应用容器，不宣称历史草稿或 Keychain 自动迁移；先将需要保留的文稿保存为文件，不删除历史安装数据。
2. 新 Bundle ID 已注册并绑定，接下来处理不可编辑历史 SKU 的选择，以及英文名称冲突、DSA 交易商身份、目标年龄和最终问卷；这些事项由发行者确认，不将成功改绑重新列为待办。记录信息见 [submission.json](AppStore/submission.json)。
3. 简体中文构建 `4` 两张已完成替换、上传及数量核验；英文两张仍待上传到相应语言与设备组并核实。不要将部分完成写成全部四张已上传，也不再上传退休历史图片。
4. 完成新标识的发行归档、导出和签名验证，再执行 Apple 服务器 Validate。如遇账号/签名访问错误，先查看 Xcode 的“Settings → Apple Accounts”状态再处理，不预先删除账号或重新登录。可使用 `MD_ANY_WHERE_TEAM_ID=你的团队ID MD_ANY_WHERE_BUILD_NUMBER=4 ./scripts/archive-ios.sh all` 准备本地归档；脚本不上传。
5. 继续按现有可选、用户自配的 Agent 准备审核访问和隐私/年龄事实答案，不要求重新决定是否保留 AI。完成具体待核实项后，再进行构建上传、TestFlight（如采用）、提交审核及正式发布；这些步骤当前均未完成。

## 设备验收与截图

发布前至少覆盖：小屏 iPhone 竖屏及横屏；键盘显示/收起；iPad 分栏；文稿菜单和各设置/公式/Agent/DOCX 对话框；中文输入、撤销、复制粘贴；Files 打开/保存/另存；后台及重启恢复；文件提供商冲突；DOCX/PDF/HTML 实际打开；拒绝 Agent 发送时无请求；清除 Key。使用 `tests/fixtures/mobile-demo.md` 这类公开示例，不能用个人文稿或真实 Key 拍摄。

构建 `4` 已从真实模拟器应用完成四张截图：简体中文和英文各有 iPhone 编辑模式 1320 × 2868 JPEG、iPad 分栏模式 2064 × 2752 JPEG。四张均无 Alpha 通道且无历史标识；简体中文两张已上传到记录 `6819302567` 并删除对应旧图，两个设备组各为 `1/10`，英文两张尚未上传。截图证明对应模拟器画面，不证明物理设备部署或所有交互通过。历史图片已退出当前公开素材，详见[截图清单](AppStore/Screenshots/README.md)。

Apple 每个设备组接受 1–10 张 PNG/JPEG；当前也接受这些组的其他列明尺寸。若不提供 6.9 英寸组，则需符合规则的 6.5 英寸组；支持 iPad 时必须提供 13 英寸组。不能把窄屏截图简单拉伸成另一设备 UI。参见 [截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 和 [上传规则](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)。

新截图应展示实际编辑与分栏，可按商店呈现需要补充纯预览、文件与草稿、导出设置、第三方 Agent 的明确同意界面。iPhone/iPad 各拍对应布局，不以 Mac 截图代替。截图必须展示实际功能，描述中不承诺无损导出所有 Markdown/Mermaid 语法。

## 隐私标签与隐私清单

应用没有自营文稿服务器、广告或分析 SDK；可选 Agent 由用户配置并直接请求第三方服务。无自营服务器、BYOK 和默认关闭不自动等于“Data Not Collected”。当前预设 API 的已知内容留存支持准备 `Yes`、`Other User Content`、`App Functionality` 的候选答案；本机处理不因此变成远程收集。账号关联、标识、用量、诊断及 IP 类别按实际留存和用途分别判断，不因连接或发送凭证就全部勾选。参见 [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。

[privacy-answer-draft.json](AppStore/privacy-answer-draft.json) 与 [Privacy-Assessment.md](AppStore/Privacy-Assessment.md) 区分代码事实、候选答案及条件项，不能自动上传为最终答案。不要求先查明所有未来用户自选端点的日志，也不为未知服务承诺零留存。先准备有依据的答案，对会影响申报的具体服务行为或披露边界继续核实；必要时向 App Review 说明实际架构。某个条件项的不确定不应阻止其他已明确字段的准备。

当前 `Support/PrivacyInfo.xcprivacy` 包含 UserDefaults 的 `CA92.1` 原因，且收集类型数组为空；这不是“第三方没有收集”的证据。发布前须根据最终二进制和已确认数据实践审查、必要时更新。原生 macOS 控制台使用 `fstat`，若单独准备 Mac App Store 版，还需单独检查该目标的文件元数据 API 原因；不要把 macOS 检查结论直接套到 iOS。参见 [必需理由 API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) 和 [第三方 SDK 要求](https://developer.apple.com/support/third-party-SDK-requirements/)。

## 外部 AI 与审核可复现性

应用已经在远程任务前展示接收主机及发送范围并请求单次同意，涵盖普通 Agent、工作流设计/运行和 DOCX 排版。仍需验证取消路径、端点变化、多提供商共识和全文任务，确保说明与真实载荷相符。Apple 对向第三方 AI 共享个人数据要求清晰披露和事前明确许可。应用和资料不能承诺未知服务商“绝不训练”或“立即删除”。参见 [审核指南 5.1.2](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)。

离线编辑不要求登录。审核员若要测试可选 Agent，需要可用的受限测试服务/凭证；维护者应通过 App Store Connect 私有审核信息提供，不把密钥提交 GitHub 或元数据文件。不要要求审核员购买 API 额度才可完成全部审核，也不要隐藏该功能。服务商条款、账号/计费和必要授权由发行者核实；不得宣称 Apple 认可集成。

## 年龄评级

按实际用途和提供内容填写问卷，由系统计算各地区评级，不预先承诺 4+ 或一律提高为 18+。当前无广告、赌博、用户间聊天、内容社区、不受限网页浏览、年龄验证或家长控制；这些能力题有源码依据。随包示例与预设内容未发现敏感题材，相应 `None` 仅是据该范围准备的候选；实际 Agent 体验仍应纳入最终评估，不把尚未测试写成已验证无敏感输出，也不因通用模型理论上可生成就全部填“频繁”。目标年龄、EULA 最低年龄、Kids 类别及是否主动提高评级由发行者确认，不由本材料代定。详见 [年龄评级事实草稿](AppStore/Age-Rating-Assessment.md)、[Apple 评级定义](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) 和 [填写流程](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)。

## 加密与地区

当前原生网络使用 Apple URLSession/HTTPS，凭证用系统 Keychain，未发现随包提供自有加密算法。按这个实现，可能符合“加密仅限 Apple 操作系统提供”的文档豁免，但发行者仍要完成加密问题并确认最终依赖；不能把“使用 HTTPS”填写成“完全不使用加密”。只有确认不含非豁免加密后才设置 `ITSAppUsesNonExemptEncryption = NO`。参见 [加密文档要求](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption) 和 [该键说明](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)。

免费价格和 174 个发行地区已在既有 App Store Connect 记录保存，唯一排除中国大陆，香港、澳门、台湾保留；未来新增地区不自动加入。同一记录现在已绑定 `app.mdanywhere.ios`。已选定地区仍须满足适用要求，不等于已经获准销售。后续如进入中国大陆，先按实际功能确认本应用是否属于 App 备案适用范围，再决定是否办理；没有自营服务器、用户自行填写 API 地址并不自动构成豁免。工信部通知以境内从事互联网信息服务的 App 主办者为对象，本次查阅的官方资料未明确界定 BYOK 通用客户端，不将尚未提供备案号列为本次首发的确定缺项。参见 [工信部备案通知](https://www.miit.gov.cn/zwgk/zcwj/wjfb/tz/art/2023/art_920db564162e4312916a01bed6540ad8.html)。欧盟 DSA 交易商身份待用户确认，再据实完成对应信息申报，不由源码或免费价格推断。本次继续按现有可选 Agent 准备，不再以重新选择是否保留 AI 为前置条件；隐私和年龄答案仍按各自事实与待确认项处理。参见 [Apple App 信息中的地区要求](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)；提交时复核实际后台问题。

## 源码公开边界

仅提交源码、资源、文档与无敏感内容的测试。排除 `.build/`、`dist/`、`.NET bin/obj`、设备日志、截图中的个人信息、`.mobileprovision`、证书/私钥、`.env` 和真实凭证。七份 vendor 许可证保留；MIT 只覆盖项目自有代码。发布前检查暂存区，不把本次设备授权记录或 API 请求内容带入 Git 历史。
