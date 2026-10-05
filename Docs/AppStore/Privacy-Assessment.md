# iOS Agent 隐私申报评估

核对日期：2026-10-05。范围为当前 iPhone/iPad 源码和下列官方公开政策，不包括对任何真实 API 账户、私有合同、代理服务器或付费额度的验证。本文件是发行者填写 App Store Connect 的依据，不是已确认的最终申报；没有执行真实模型调用，也没有读取或记录私人 Key、联系人。

## 当前结论

保留当前多提供商及自定义端点功能时，不能填写“Data Not Collected”。至少应准备申报远程 Agent 接收的 **Other User Content（其他用户内容）**，用于 **App Functionality（App 功能）**。通过 API 账户认证的内容应按“与用户关联”准备，除非取得适用于所有实际收集链路的去关联证据。账号标识、用量和技术日志还须按接收方实际保留内容逐项确认；默认关闭 Agent、用户自带 Key、`store: false` 都不能证明第三方不收集。

这是基于代码与标准 API 留存政策的评估。Apple 将请求所需实时处理之外可访问的离设备数据视作收集；仅设备内处理不在此范围。可选功能并不自动豁免披露，且不同用户/服务层级的数据实践需合并覆盖。参见 [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。

## 源码中实际发生的数据传输

主要证据：[AgentService.swift](../../Sources/DOTMD/AgentService.swift)、[iOS AppDelegate.swift](../../Sources/DOTMDiPad/AppDelegate.swift)、[app.js](../../Sources/DOTMD/Resources/app.js)。

- 七个默认配置均 `enabled: false`：OpenAI、Anthropic、Gemini、DeepSeek、GLM、Grok，以及设备回环地址上的本地兼容服务。显示名称、协议、端点、模型都可编辑，因此名称不能证明真实接收方。
- `requestAgentCompletion` 用原生 `URLSession` 直接向配置端点 POST，没有 md any where 中转服务器；远程必须 HTTPS，仅 `local` 协议的回环地址允许 HTTP。原生会从 Keychain 取出凭证发送到该端点；本地持久化使用 Keychain 不代表凭证从不离开设备。
- 普通任务发送任务要求、选中文字与附近上下文；摘要及全文工作流可发送全文。集群共识将其他服务的答案交给主席服务；工作流将前一步答案交给下一步，形成跨提供商传输。
- 流程设计发送目标和已启用 Agent 的显示名称/内部配置 ID，不发正文；这些 ID 是本地配置标识，不是专门生成的用户跟踪 ID。DOCX 排版发送排版要求及字体/页面设置，不发文稿正文。
- `confirmTransfer` 在每次远程运行前列出接收主机、发送范围并要求同意；回环地址免除此远程确认。设备上的回环服务仍可能自行转发至云端，不能仅从 `localhost` 判断整条链路离线。
- 本程序没有主动加入广告 ID、设备 ID、通讯录、定位、音视频、照片或支付字段，也没有遥测 SDK。服务端仍能观察连接 IP 和协议元数据；认证、计费、安全等日志是否长期保留，需要服务端政策证据。只读源码不能证明远端日志不存在。
- 本地 Markdown、预览、搜索、导出、恢复草稿、偏好和工作流设置本身没有开发者上传路径。系统文件提供商/系统备份另由用户的系统服务处理；这不等同于 md any where 自营云服务。

## 逐项填写建议

以下为选择当前在线 Agent 功能后的候选答案。标为“待核实”的项不能以猜测替代实际事实；[JSON 草稿](privacy-answer-draft.json)将最终确认值保留为空。

1. **是否收集数据：建议 Yes。** 标准 API 的内容日志已足以否定全应用“不收集”。仅移除实际远程能力并复核全部数据流，或取得覆盖全部接收方/用户配置的实时后不保留证据，才可重新评估 No。
2. **Other User Content：建议收集；App Functionality；Linked to User = Yes。** 包括自由文本指令、文稿范围和参与后续请求的答案。一般自由文本按此类申报，不因用户可能自行输入病历、姓名就勾选所有敏感类型；如果未来加入专门收集某类数据的功能，再单独申报。Tracking 暂建议 No，但须确认最终服务/代理没有广告关联或数据经纪商用途。
3. **Identifiers → User ID：待核实，倾向需要。** 用户自有 API Key 映射到服务商账户；若服务保留与请求关联的账户/项目/Key 标识，应按 App Functionality、Linked = Yes 申报。仅实时验证后不保留的认证 token 不因“发送过”就必须申报。不要把原始 Key 写入公开材料或测试记录。
4. **Usage Data → Other Usage Data：待核实，标准在线计费场景倾向需要。** 请求模型、token 用量等若按账户保留，通常用于功能/计费，应核对这一类别。若记录的是具体 Agent 操作、次数或功能互动，再评估 Product Interaction；不要无证据把全部点击、滚动或离线编辑都报为已上传。Google 的 API 条款明确列出 token 用量等服务数据。
5. **Diagnostics → Other Diagnostic Data / Performance Data：待核实。** 实际保留的请求状态、错误、安全触发或性能数据可对应这些项；用途视功能、安全、性能或行为分析的真实用途填写。无应用崩溃上传路径不意味着第三方 API 没有诊断日志，也不能把 Apple 自己独立收集的数据当作开发者收集。
6. **IP 地址：按用途判断，不能机械填定位。** 若用于技术/安全日志，核对诊断类别；若用于推断并保留大致位置，核对 Coarse Location；若用于持久识别，核对 Device ID。当前客户端没有定位读取，远端 IP 用途尚未完整确认。
7. **其他类别：当前客户端没有明确收集路径，不预先勾选。** 包括姓名/邮箱/电话、通讯录、支付信息、购买历史、健康/健身、照片/视频/音频、浏览历史、设备传感器、广告数据。API 供应商在其自有网站收取账单或付款，不代表这些全部经 md any where 上传。GitHub 外部支持流程需与 App 内请求区分，若以后加入反馈上传，再审查 Customer Support。

上述分类依据 Apple 的数据类型、用途、关联及 IP/自由文本指导；具体候选项由本应用代码及服务商日志说明推导，不能作为 Apple 对本应用的确认。[Apple 定义](https://developer.apple.com/app-store/app-privacy-details/)；[App Store Connect 填写流程](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。

用途方面：认证、生成答案和安全防滥用按 App Functionality 准备；提供商若用内容训练通用模型或开发其他产品，需评估 **Other Purposes**，不能只报 App Functionality。如果还分析用户行为，再评估 Analytics。没有证据支持 md any where 的广告/营销用途，也没有证据证明模型训练本身就是 Apple 定义的广告跟踪；Tracking 不能仅凭“第三方 AI”自动填 Yes，亦不能为未知代理一律担保 No。

## 各默认服务的官方政策核对

### OpenAI

默认端点为 `api.openai.com/v1/responses`，请求明确带 `store: false`。官方说明 API 数据默认不用于训练（主动共享除外），但标准防滥用日志可含提示词和回复，通常最多保留 30 天，法律/严重安全例外可能更久。ZDR/MAM 需符合资格、获批且受端点/模型限制；关闭 Responses 状态保存不等于关闭这些日志。不能把发行者一个账户的 ZDR 承诺推广到所有 BYOK 用户。[OpenAI 官方数据控制](https://developers.openai.com/api/docs/guides/your-data)。

**型号核验：** `gpt-5.6-luna` 有正式 OpenAI API 型号页，并列出 Responses 支持；它并非仅因同名 Codex 选项就不可用。实际审核账户的访问权限/额度仍须私下测试。[官方型号页](https://developers.openai.com/api/docs/models/gpt-5.6-luna)。

### Anthropic

默认端点为 `api.anthropic.com/v1/messages`。商用 API 标准输入输出通常在 30 天内删除，但违规、法律、约定或特定模型可能延长；不能写成无条件 30 天上限。商用数据默认不训练，主动选择共享或反馈等另有规则。需按实际账户、模型及合同核对，不套用 Claude 消费者订阅政策。[商用留存](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)；[训练说明](https://privacy.claude.com/en/articles/7996885-how-do-you-use-personal-data-in-model-training)。

### Gemini

默认为 `generativelanguage.googleapis.com` 的 `generateContent`，代码不检查账户是否已启用付费，也未强制某地区或服务层级。未付费服务的输入输出可能用于产品/模型改进并人工审阅；适用付费条款的内容不用于该类改进，但仍有安全日志。条款还列有认证、token、错误、性能和 IP 等服务数据。2026-03-23 生效条款要求 API 使用者成年，并限制面向或可能被未成年人访问的 API 客户端；地域与 EEA/英国/瑞士付费条件也必须单独确认。Apple 年龄评级并不自动证明符合这些服务条款。[Gemini API 条款](https://ai.google.dev/gemini-api/terms)。

**影响：** 是否保留 Gemini、允许未付费账户、如何实现年龄/地域约束必须由发行者决定。仅在 README 声称“仅付费”而代码仍接收任意 Key，不能据此缩小申报范围。

### DeepSeek

默认为 `api.deepseek.com/chat/completions`。官方开放平台条款要求下游应用自行向用户披露处理规则、取得相应授权并响应数据权利请求；其第 5.5 条明确区分下游用户的数据规则与一般服务隐私政策。本次获得的官方资料未足以确认 md any where 下游 API 文稿的具体留存天数、训练选择与日志去关联情况。不能从消费者网站的聊天开关推导 API 选择，也不能承诺 API 不训练/不留存。应取得对应开放平台账户的政策或书面数据处理说明。[开放平台条款](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html)；[一般隐私政策及其适用范围](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)。

### GLM / 智谱

默认为 `open.bigmodel.cn/api/paas/v4/chat/completions`。已核对开放平台用户协议（生效日 2026-09-04）；协议列有下游开发者数据安全和服务合规义务，且对免费功能的使用范围另有限制。其[隐私政策页面](https://docs.bigmodel.cn/cn/terms/privacy-policy)本次多次读取失败，未以二手文章填补。具体输入输出留存、训练、IP/账户日志和免费模型商用适用性均待核实，不能申报为“已证实零收集”。[官方用户协议](https://docs.bigmodel.cn/cn/terms/user-agreement)。

### Grok / xAI

默认为 `api.x.ai/v1/chat/completions`。官方 API 安全说明表示未经明确许可不训练，标准请求/回复仍保存 30 天用于审计。ZDR 按团队启用且可关闭，受功能限制；响应头可报告是否生效，当前代码没有读取或强制该状态。不能把提供商有 ZDR 选项写成每个用户都已启用。[官方 API 数据与安全说明](https://docs.x.ai/developers/faq/security)。

### 本地服务及自定义代理

`127.0.0.1` 是当前 iPhone/iPad，不是连接的 Mac。只有确认该服务全链路不再外传，才能把其处理算作设备内。用户可以把任何默认配置改成 HTTPS 代理；代理同时接收凭证和内容，且可能改写、记录、路由至其他服务。以上官方直连政策不能覆盖代理。发行者无法仅凭供应商名称或 `store: false` 为任意代理作出统一不留存、不训练、不跟踪承诺。

## 必须由发行者确认的服务选择

- **首版功能范围：** 保留全部提供商和任意 HTTPS 端点；还是选定一组有明确政策的官方直连服务；或首版仅保留离线编辑。收窄范围需要实际代码和测试随之改变，本次未删除功能。推荐先确认有限的官方直连范围，以便获得能够据实完成的申报；这不等于这些服务“无收集”。
- **Gemini：** 是否保留；是否排除未付费服务；服务条款要求的年龄及地区如何落实。BYOK 场景不能只回答发行者自己的账户类型。
- **未明确的服务/代理：** 如保留 DeepSeek、GLM 或自定义代理，由谁提供适用于最终接收方的留存、训练、账户/IP/诊断日志用途及删除说明。不能用“用户自行承担”替代应用的披露。
- **训练/分享与 ZDR：** 是否允许账号主动共享数据用于训练；若承诺 ZDR，实际如何验证所有可用账户/模型/代理均满足，以及仍保留哪些账号/用量元数据。
- **审核可复现性：** 最终保留哪些真实服务，提供哪些受限、可撤销且额度足够的审核访问方式。Key/合同/私人联系方式只进入 App Store Connect 私有渠道或本地忽略文件，禁止写入本公开文档。

## 最终填写和发布边界

可先按上面的 Yes 与 Other User Content 候选准备表单，但应在服务范围、日志分类和用途确认后才定稿/发布隐私标签。代码的 `PrivacyInfo.xcprivacy` 收集数组当前为空，只表达已写入的清单，不能推翻上述远端事实；最终清单、政策、同意界面与 App Store Connect 答案需逐项一致复核。Apple 隐私答案可单独更新，更新政策或草稿也不会自动改变已发布标签。[官方填写流程](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。
