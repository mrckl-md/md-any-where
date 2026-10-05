# App Store 发布准备

核对日期：2026-10-06。当前品牌精确为 **md any where**。移动目标为 `1.0.0 (6)`、`app.mdanywhere.mobile`；macOS 目标为 `1.0.0 (5)`、`app.mdanywhere.editor`。工程为 `MDAnyWhere-iOS.xcodeproj`，scheme 为 `MDAnyWhere-iOS`。macOS 可通过 MCP / CLI 接入 AI 编辑器，移动端提供内置 Agent。移动 build 6 已于 2026-10-06 成功上传新记录，Apple 已完成处理，TestFlight 状态为“准备提交”，已关联商店版本 1.0.0；尚未送审或发布。

## 当前已完成与记录状态

- **最终源码审查：** 移动 build 6 / macOS build 5 包含下方五类修复。移动草稿存储 9 项、真实 WebKit 编辑安全、移动布局 9 项、50 项语言状态及 27 组多语言布局、桥接契约、本机 Agent 传输回归通过；iOS 17 全量 Swift 类型检查通过。日志保存在被 Git 忽略的 `.build/review/`，不含真实 API 调用。
- **移动 build 6：** `.build/ios/app-store/build6/md any where.xcarchive` 开发签名归档及 App Store 发行重签 IPA 导出成功。归档的开发描述文件允许调试且含设备列表；导出 IPA 严格验签通过，发行描述文件无调试权限和设备列表。SDK iOS 27/最低 iOS 17、设备族 `1,2`、47 × 584 条目录和 51 个语言目录已核验；打包 JavaScript 与源码哈希一致，归档 dSYM UUID 匹配。iPhone/iPad 模拟器均安装启动成功，公开示例编辑/分栏、公式/流程图/表格画面已核验，7 项 JS/CSS/目录哈希与源码一致。移动 build 6 上传成功，Apple 已完成处理，TestFlight 状态为“准备提交”，已关联商店版本 1.0.0；尚未送审或发布。
- **本版真机部署：** iPad 使用 build 6 开发签名包安装并启动成功；iPhone 的连接/锁定状态查询超时，本版未执行安装或启动。不把安装启动成功写成全部交互验收完成。
- **macOS build 5：** 最终构建、主程序/Quick Look/缩略图/Agent 四组件版本与标识、严格深层 ad-hoc 签名通过；`app.js`、语言目录与源码一致。真实 WebKit DOCX 回归通过，检查流程图 PNG、图片关系、OMML 公式、表格与失败回退。此结果不表示 Developer ID 公证或 Mac App Store 发行。
- **新记录已创建：** `6819394741` 已绑定 `app.mdanywhere.mobile` 和 SKU `MD-ANY-WHERE-IOS-001`。完全访问已获用户明确授权，团队仅本人。版本 `1.0.0` 的简中推广文字、描述、关键词、支持/营销 URL、版权、私有审核联系人、不要求登录及手动发布已保存。副标题、效率/工具分类、免费价格及 174 地区供应设置已恢复保存，未来新增地区自动加入已关闭。隐私政策 URL 也已保存并核验，基础资料恢复完成。
- **旧记录已移除：** `6819302567` 已停止全部 175 个地区供应并移除，非永久删除；用户明确不恢复。旧记录此前的保存和截图上传只作历史证据，不计入新记录完成状态。
- **四张截图保留：** 简中和英文各一张 iPhone 编辑、一张 iPad 分栏，真实来源为 build 4；尺寸、无 Alpha 通道和画面无历史品牌已核验。build 6 所示主界面未变，可复用，保留原文件名及来源版本，不冒称重新拍摄。新记录简中两张已上传，iPhone 6.9 英寸、iPad 13 英寸组各 `1/10`；英文两张待上传，详见[截图清单](AppStore/Screenshots/README.md)。

## 本次修复与验证

1. Agent 请求拒绝自动重定向，防止已同意发送的正文或认证头被转发到另一地址。本机假数据复现原 307/308 行为；修复后同站与跨站的 301/302/303/307/308 均不访问目标，正常响应和 4 MiB 边界保持通过。
2. Agent 与公式结果绑定请求时的文稿、CodeMirror 文档实例和修改版本；切换文稿、关闭后重开、修改正文及乱序响应不会把旧结果写入新选区。
3. 查找在切换标签时清除旧位置；忽略大小写查找使用原文 UTF-16 偏移，避免 Unicode 大小写转换扩长后替换错位。
4. 原生文稿替换桥收到不存在的文稿 ID 时直接返回，不覆盖当前文稿。
5. Markdown 链接保留解析器默认的危险协议验证，再施加离线限制；导出不接受可执行或本地文件链接，安全页内锚点仍可用。

可运行 `scripts/test-agent-transport.sh`、`scripts/test-editor-safety.sh`、`scripts/test-mobile-store.sh`、`scripts/test-mobile-layout.sh`、`scripts/test-localized-editor.sh` 与 `node scripts/test-bridge-contract.cjs` 复查相应行为。多语言仍为 50 个官方语言项、47 份目录，每份 584 条；新增过期选区提示已覆盖全部目录。测试通过不表示所有真实服务、设备或母语翻译已验收。

## 历史证据的适用范围

移动 build 5 曾完成本地开发签名 Release 包、严格验签归档，以及 iPhone/iPad 模拟器安装、启动和公开示例导入，目录为 47 × 583 条。最初未完成发行导出；用户重新验证 Xcode 账号后，该旧包作为签名预检成功导出，未上传，也不包含本次最终修复。历史预检结果位于 `.build/final-review/build5-signing-preflight-after-login/`；本版未完成真机部署。

移动 build 4 曾通过七组 JavaScript、Agent 打包、Quick Look、Mermaid、原生本地化、移动存储 9 项、布局 9 项、50 项语言状态与 27 组 WebKit 布局、WebKit DOCX 回归，以及模拟器和本地开发签名构建。其 iPad 安装成功但启动未确认，iPhone 因连接异常安装失败。这些仍是之前标识与构建的证据，不算当前 build 6 真机验收已通过。

版本 `1` 曾成功本地 App Store IPA 导出并验证发行签名，但未上传；真机 PDF 两页及完整内容、DOCX 流程图图片/表格/OMML 结构曾核验。Quick Look 不显示 OMML，未用 Word/WPS 完成公式目视验证。版本 `3` 曾归档成功，分发导出报账号/签名访问错误；错误只能说明当时导出进程不能访问所需身份，不能证明用户退出登录。版本 `1`、`3` 图片已退休并保留历史备份。

## 尚需完成

1. 新记录 `6819394741` 已创建，简中版本资料与私有审核设置已恢复；副标题、分类、免费价格、174 地区供应设置及隐私政策 URL 也已恢复核验，基础资料恢复完成。英文名称可用性仍须核验，年龄、隐私、内容版权与 DSA 声明按事实和发行者确认完成。详见 [submission.json](AppStore/submission.json)。
2. 移动 build 6 的 iPad 安装启动已完成；继续完成 iPhone 部署及所需真机交互验收。标识变化可能形成独立容器，不保证历史草稿或 Keychain 自动迁移；先把要保留的文稿保存为文件，不删除历史安装数据。
3. 新记录简中两张 build 4 来源图片已重新上传，两个设备组各 `1/10`；继续上传并核验英文两张，不把部分完成写成四张全部上传。
4. 本地 App Store 发行签名导出及签名验证已完成；build 6 已成功上传，上传流程中的服务器分析已接受，后台已显示 build 6“准备提交”；未单独执行 Validate 命令。可使用 `MD_ANY_WHERE_TEAM_ID=你的团队ID MD_ANY_WHERE_BUILD_NUMBER=6 ./scripts/archive-ios.sh all` 准备归档和导出，脚本不上传。若账号/签名访问受阻，先查看 Xcode 的“Settings → Apple Accounts”状态，不预先删除或重新登录账号。
5. 继续按现有可选、用户自配 Agent 准备审核访问与问卷，不重新询问是否保留 AI。build 6 已成功上传，提交事项继续准备；TestFlight 分发（如采用）、送审及发布分别记录实际结果，当前均未完成。

## 设备验收与截图

发布前覆盖小屏 iPhone 竖横屏、键盘、iPad 分栏、菜单及设置/公式/Agent/DOCX 对话框、中文输入、撤销、复制粘贴、Files 打开/保存/另存、后台与重启恢复、文件冲突、DOCX/PDF/HTML 实际打开、拒绝远程发送及清除 Key。使用 `tests/fixtures/mobile-demo.md` 等公开示例，不拍摄个人文稿或真实凭证。

四张公开素材的来源版本均为 `1.0.0 (4)`：iPhone 为 1320 × 2868 JPEG，iPad 为 2064 × 2752 JPEG，均无 Alpha 通道。当前 build 6 所示主界面未变，可复用，但截图不证明真机部署或所有交互通过。Apple 每个设备组接受 1–10 张 PNG/JPEG；支持 iPad 时须提供适用的 13 英寸组。参见[截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)与[上传规则](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)。

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

发行计划保持免费、174 个地区，唯一排除中国大陆，香港、澳门、台湾保留；未来新增地区不自动加入。新记录 `6819394741` 已保存免费价格和上述 174 地区供应设置；免费定价向导覆盖 175 个地区，供应范围单独排除中国大陆，不能把定价范围当成可售地区。已选定地区仍须满足适用要求，不等于已经获准销售。后续如进入中国大陆，先按实际功能确认本应用是否属于 App 备案适用范围，再决定是否办理；没有自营服务器、用户自行填写 API 地址并不自动构成豁免。工信部通知以境内从事互联网信息服务的 App 主办者为对象，本次查阅的官方资料未明确界定 BYOK 通用客户端，不将尚未提供备案号列为本次首发的确定缺项。参见 [工信部备案通知](https://www.miit.gov.cn/zwgk/zcwj/wjfb/tz/art/2023/art_920db564162e4312916a01bed6540ad8.html)。欧盟 DSA 交易商身份待用户确认，再据实完成对应信息申报，不由源码或免费价格推断。本次继续按现有可选 Agent 准备，不再以重新选择是否保留 AI 为前置条件；隐私和年龄答案仍按各自事实与待确认项处理。参见 [Apple App 信息中的地区要求](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)；提交时复核实际后台问题。

## 源码公开边界

仅提交源码、资源、文档与无敏感内容的测试。排除 `.build/`、`dist/`、`.NET bin/obj`、设备日志、截图中的个人信息、`.mobileprovision`、证书/私钥、`.env` 和真实凭证。七份 vendor 许可证保留；MIT 只覆盖项目自有代码。发布前检查暂存区，不把本次设备授权记录或 API 请求内容带入 Git 历史。
