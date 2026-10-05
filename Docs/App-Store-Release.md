# App Store 发布准备

核对日期：2026-10-05。目标为 iPhone/iPad 的 iOS App Store 发布；macOS 源码仍可独立构建。本文件是准备清单，不是已提交、已通过审核或已完成全部测试的声明。

## 当前已准备的内容

- [公开源码仓库](https://github.com/mrckl-md/DOT-MD)已推送至 `main`，GitHub 已识别 MIT 许可证；README、许可证与隐私政策文件均已可访问。保留七份第三方许可证及版本/哈希清单。
- iOS 工程、系统文件选择/分享、草稿恢复、Keychain 与逐次远程 Agent 发送确认。
- [完整隐私政策](../PRIVACY.md)及应用内隐私说明，覆盖移动端草稿、备份与第三方处理。
- [中英文名称、副标题、描述、关键词及审核备注](AppStore/README.md)。英文元数据明确应用界面目前以简体中文为主。
- 本地开发构建与设备部署脚本。它们使用开发签名，不等于 App Store 分发归档。
- `Release` 归档及本地 App Store `.ipa` 导出已成功，版本为 `1.0.0 (1)`；已检查 Apple Distribution 签名、`get-task-allow = false`、设备族 `1,2`（iPhone/iPad）及打包资源。产物保留在被 Git 忽略的 `.build/ios/app-store/20261005-214601/`，没有上传。
- [四张简体中文商店截图](AppStore/Screenshots/README.md)：最终源码构建的实际模拟器 UI，iPhone、iPad 各两张，无个人资料；尺寸及无 Alpha 通道已核对。

最终构建已重新部署至 iPhone 17 Pro Max（iOS 27.0.1），安装、启动、公开示例导入、触控编辑保存和导出通过本轮验证。同一通用开发构建也已安装并启动于 iPad，保留原有数据。PDF 是两页白底原生分页，目视确认公式、全部三个流程图节点、表格与尾文完整。真机 DOCX 内含 1884 × 480 白底流程图 PNG，三个节点完整；XML 检查确认 OMML 公式、表格、图片关系和尾文存在。Quick Look 能显示正文、图片与表格，但不显示 OMML；本轮没有用 Word/WPS 实际验证公式显示。

移动文稿存储九项回归、九种视口 WebKit 布局回归及 DOCX 图像回归均通过，独立代码审查未发现阻塞项。预览滚动时观察到的空白已通过真机截图确认为 Device Hub 镜像延迟，不是应用缺陷。这些结果只覆盖已说明的范围，不能替代以下完整发布验收；本地归档/导出成功也不等于 Apple 服务器 Validate、上传或审核通过。

## 尚需维护者或发行账号完成

1. 用有权限的 Apple Developer Program 账号确认团队、协议和发行主体；在 App Store Connect 建立对应 app 记录。当前 Bundle ID 是 `app.dotmd.ipad`，工程/scheme 保留 `DOTMD-iPad` 历史名称。首次上传前确认该 ID 的归属与正式使用意图；上传后不能随意更改。参见 [App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)。
2. 填写真实审核联系人、电话、邮箱及公开支持联系方式；不能把占位值、不可访问仓库或仅有“即将上线”的页面提交。拟定 [支持入口](https://github.com/mrckl-md/DOT-MD/issues) 和 [政策 URL](https://github.com/mrckl-md/DOT-MD/blob/main/PRIVACY.md) 在公开前均不可用，且 Issues 页面不能代替所需的实际联系信息。参见 [版本元数据](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。
3. 按下文核对第三方留存、隐私标签、年龄评级、加密和销售地区要求。不要从 MIT 开源许可推导出 API 服务使用授权或审核豁免。
4. 对已生成的 Release archive，在 Organizer 执行 Apple 服务器 Validate；若之后更改代码、版本或发布配置，应重新归档、导出与验收。之后的 Upload、TestFlight 邀请、提交审核和正式发布仍是待执行的账号操作；本次准备没有执行这些步骤。可用 `DOT_MD_TEAM_ID=你的团队ID ./scripts/archive-ios.sh all` 重建本地归档和导出包；脚本不上传。

## 设备验收与截图

发布前至少覆盖：小屏 iPhone 竖屏及横屏；键盘显示/收起；iPad 分栏；文稿菜单和各设置/公式/Agent/DOCX 对话框；中文输入、撤销、复制粘贴；Files 打开/保存/另存；后台及重启恢复；文件提供商冲突；DOCX/PDF/HTML 实际打开；拒绝 Agent 发送时无请求；清除 Key。使用 `tests/fixtures/mobile-demo.md` 这类公开示例，不能用个人文稿或真实 Key 拍摄。

本仓库已准备 iPhone 6.9 英寸组两张 1320 × 2868 JPEG，以及 iPad 13 英寸组两张 2064 × 2752 JPEG，均无 Alpha 通道，详见[截图清单](AppStore/Screenshots/README.md)。它们来自最终源码对应的实际模拟器 UI，展示公开示例，不是设备真机测试的替代证据；尚未上传 App Store Connect。若提交前 UI 发生变化，应重新截取。

Apple 每个设备组接受 1–10 张 PNG/JPEG；当前也接受这些组的其他列明尺寸。若不提供 6.9 英寸组，则需符合规则的 6.5 英寸组；支持 iPad 时必须提供 13 英寸组。不能把窄屏截图简单拉伸成另一设备 UI。参见 [截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 和 [上传规则](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)。

现有截图展示编辑、分栏及预览；可按商店呈现需要补充文件与草稿、导出设置、第三方 Agent 的明确同意界面。iPhone/iPad 各拍对应布局，不以 Mac 截图代替。截图必须展示实际功能，描述中不承诺无损导出所有 Markdown/Mermaid 语法。

## 隐私标签与隐私清单

应用没有自营文稿服务器、广告或分析 SDK，但第三方 Agent 可能处理并保留用户内容。不能直接选择“Data Not Collected”。本机处理通常不属于 Apple 定义的收集；离设备后保留超过实时请求所需时间则应评估收集，用户自愿启用不自动满足可选披露条件。通用文稿可按 `Other User Content`、用途 `App Functionality` 核对；是否关联用户须考虑 API 账户。提供商/代理的日志、IP及认证信息需按真实用途和留存分别核对，不能凭猜测填“未关联”。参见 [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。

[privacy-answer-draft.json](AppStore/privacy-answer-draft.json) 是待核实的填写依据，不能自动上传为最终答案。需要记录所支持提供商或代理的实际政策、保留期限、是否训练、与账户关联情况和删除渠道，再由发行者作最终申报。

当前 `Support/PrivacyInfo.xcprivacy` 包含 UserDefaults 的 `CA92.1` 原因，且收集类型数组为空；这不是“第三方没有收集”的证据。发布前须根据最终二进制和已确认数据实践审查、必要时更新。原生 macOS 控制台使用 `fstat`，若单独准备 Mac App Store 版，还需单独检查该目标的文件元数据 API 原因；不要把 macOS 检查结论直接套到 iOS。参见 [必需理由 API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) 和 [第三方 SDK 要求](https://developer.apple.com/support/third-party-SDK-requirements/)。

## 外部 AI 与审核可复现性

应用已经在远程任务前展示接收主机及发送范围并请求单次同意，涵盖普通 Agent、工作流设计/运行和 DOCX 排版。仍需验证取消路径、端点变化、多提供商共识和全文任务，确保说明与真实载荷相符。Apple 对向第三方 AI 共享个人数据要求清晰披露和事前明确许可。应用和资料不能承诺未知服务商“绝不训练”或“立即删除”。参见 [审核指南 5.1.2](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)。

离线编辑不要求登录。审核员若要测试可选 Agent，需要可用的受限测试服务/凭证；维护者应通过 App Store Connect 私有审核信息提供，不把密钥提交 GitHub 或元数据文件。不要要求审核员购买 API 额度才可完成全部审核，也不要隐藏该功能。服务商条款、账号/计费和必要授权由发行者核实；不得宣称 Apple 认可集成。

## 年龄评级

完成当前 App Store Connect 问卷，由系统生成各地区结果，不预先承诺 4+。当前没有应用内广告、赌博、用户间聊天、内容社区或不受限网页浏览；本地私有文稿并不等同于广泛传播 UGC。应用也没有自建年龄验证或家长控制，不应勾选为已有能力。可选的自定义 AI 端点可能生成不同年龄适宜性的内容，须实际评估能出现的内容并如实作答，必要时提高评级或限制功能；不要因为默认关闭就一律填“无”。本版本不申报 Kids 类别。参见 [评级定义](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) 和 [填写年龄评级](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)。

## 加密与地区

当前原生网络使用 Apple URLSession/HTTPS，凭证用系统 Keychain，未发现随包提供自有加密算法。按这个实现，可能符合“加密仅限 Apple 操作系统提供”的文档豁免，但发行者仍要完成加密问题并确认最终依赖；不能把“使用 HTTPS”填写成“完全不使用加密”。只有确认不含非豁免加密后才设置 `ITSAppUsesNonExemptEncryption = NO`。参见 [加密文档要求](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption) 和 [该键说明](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)。

销售地区尚未确定。若选中国大陆，核对实际适用的备案及内容/AI相关资质；若选欧盟，完成适用的经营者身份和联系信息申报。这些是发行账号和地区选择事项，本仓库没有替发行者取得资质。参见 [Apple App 信息中的地区要求](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)；提交时复核 App Store Connect 的实际问题。

## 源码公开边界

仅提交源码、资源、文档与无敏感内容的测试。排除 `.build/`、`dist/`、`.NET bin/obj`、设备日志、截图中的个人信息、`.mobileprovision`、证书/私钥、`.env` 和真实凭证。七份 vendor 许可证保留；MIT 只覆盖项目自有代码。发布前检查暂存区，不把本次设备授权记录或 API 请求内容带入 Git 历史。
