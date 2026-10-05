# iOS Agent 隐私申报评估

## Saved answers - 2026-10-06

For record `6819394741`, build `1.0.0 (6)`, four categories were saved: Other User Content, User ID, Other Usage Data and Other Diagnostic Data. All are linked to the user, used for App Functionality and not for advertising tracking. Other User Content also has Other Purposes, reflecting provider product/model improvement. The four-category disclosure was published on 2026-10-06 after source and policy reassessment. It covers known optional API integration practices; it is not a claim of publisher-operated collection or Apple approval of a BYOK-specific interpretation.

This covers optional API-provider retention, account association, usage and technical/security logs. It does not assert developer-operated collection or uploads of offline clicks, crash reports or app performance telemetry. Google's API terms and xAI's retention policy support the classification. Generic network connections alone do not establish location or device-ID collection. No universal retention/training guarantee is made for custom endpoints.

The publisher confirmed a general audience and requested truthful BYOK review notes; no demo credentials were supplied. Earlier conditional analysis below remains as evidence and scope context; the actual saved choices above supersede draft-only wording. Publication and submission are tracked separately in submission.json.

修订日期：2026-10-06；官方政策核对日期：2026-10-05。范围为当前 iPhone/iPad 源码和下列官方公开政策，不包括对任何真实 API 账户、私有合同、代理服务器或付费额度的验证。本文件是发行者填写 App Store Connect 的依据，不是已确认的最终申报；没有执行真实模型调用，也没有读取或记录私人 Key、联系人。当前发布准备继续包含已有的可选、用户自配 Agent，无需再次确认是否保留该功能。

当前移动目标为 `app.mdanywhere.mobile`、构建 `1.0.0 (6)`。本地 Release 开发签名及严格验签、iPhone/iPad 模拟器安装启动和公开示例导入已通过。业务数据流与内容评估沿用此前已核实的实现事实，最终权限、发送范围与真机交互仍须单独核验；上述构建检查不等于隐私或年龄问卷定稿。应用标识变化也不保证历史草稿或 Keychain 自动迁移。

## 当前结论

**没有自营服务器不等于整个应用没有离设备数据处理，BYOK 也不自动等于“Data Not Collected”。** 当前预设服务的标准 API 政策已有请求内容留存证据，因此建议为可选远程 Agent 准备 `Yes`、**Other User Content（其他用户内容）**、用途 **App Functionality（App 功能）** 的候选答案；这是基于当前集成功能的评估，不是 Apple 对本应用的最终裁定。账号关联、标识、用量和诊断类别应按实际收集分别判断，不因发送了 API Key 就将所有类别自动勾选。

Apple 的收集定义关注开发者或第三方合作方是否能在实时请求所需时间以外访问离设备的数据；仅设备内处理不属于收集。可选披露有多项同时满足的条件，默认关闭或每次同意本身不足以豁免。一般自由文本可以用 Other User Content 表示，不必把用户可能写入的每一种信息都单独勾选。参见 [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。

**不要求先调查世界上所有可能的用户自选服务器，才能开始填写问卷。** Apple 要求准确披露应用及其第三方合作方的实际收集，但所查官方说明没有明确裁定任意 BYOK 端点如何全部归入该范围，也没有要求穷尽这些端点的日志。应分开记录开发者自身行为、预设服务集成的已知行为，以及用户自行配置服务的边界；既不为未知服务保证零留存，也不把它可能具有的一切行为都算作本应用已证实收集。若这个归属问题影响最终答案，应向 App Review 说明实际架构并取得针对该问题的解释，而不是据此暂停已经有依据的其他答案。

## 源码中实际发生的数据传输

主要证据：[AgentService.swift](../../Sources/MDAnyWhere/AgentService.swift)、[iOS AppDelegate.swift](../../Sources/MDAnyWhereMobile/AppDelegate.swift)、[app.js](../../Sources/MDAnyWhere/Resources/app.js)。

- 七个默认配置均 `enabled: false`：OpenAI、Anthropic、Gemini、DeepSeek、GLM、Grok，以及设备回环地址上的本地兼容服务。显示名称、协议、端点、模型都可编辑，因此名称不能证明真实接收方。
- `requestAgentCompletion` 用原生 `URLSession` 直接向配置端点 POST，没有 md any where 中转服务器；远程必须 HTTPS，仅 `local` 协议的回环地址允许 HTTP。原生会从 Keychain 取出凭证发送到该端点；本地持久化使用 Keychain 不代表凭证从不离开设备。
- 普通任务发送任务要求、选中文字与附近上下文；摘要及全文工作流可发送全文。集群共识将其他服务的答案交给主席服务；工作流将前一步答案交给下一步，形成跨提供商传输。
- 流程设计发送目标和已启用 Agent 的显示名称/内部配置 ID，不发正文；这些 ID 是本地配置标识，不是专门生成的用户跟踪 ID。DOCX 排版发送排版要求及字体/页面设置，不发文稿正文。
- `confirmTransfer` 在每次远程运行前列出接收主机、发送范围并要求同意；回环地址免除此远程确认。设备上的回环服务仍可能自行转发至云端，不能仅从 `localhost` 判断整条链路离线。
- 当前 Agent 请求没有主动加入广告 ID、设备 ID、通讯录、定位、音视频、照片或支付字段，也没有遥测 SDK。服务端仍能观察连接 IP 和协议元数据；仅从建立连接不能认定其被长期保留或用于定位。客户端事实可先据实填写，相关集成服务的实际留存、用途再依据政策判断。
- 本地 Markdown、预览、搜索、导出、恢复草稿、偏好和工作流设置本身没有开发者上传路径。系统文件提供商/系统备份另由用户的系统服务处理；这不等同于 md any where 自营云服务。

## 逐项填写建议

按当前代码保留可选 Agent 评估，不默认要求删去供应商、限制端点或改成离线版。以下可用于准备后台答案；标为“条件项”的内容不是全部表单的前置阻碍。[JSON 草稿](privacy-answer-draft.json)区分代码事实、候选答案和最终确认，后者仍保留为空。

1. **是否收集数据：候选 Yes。** 根据当前预设服务的标准请求内容留存准备；无需等任意用户端点全部查明才开始填写。不能仅凭无自营服务器、BYOK、默认关闭或 `store: false` 改答 No。最终答案还需对应提交版本的实际集成及 Apple 披露范围。
2. **Other User Content：候选收集；App Functionality。** 包括自由文本指令、文稿范围和参与后续请求的答案。**Linked to User：在所申报服务保留账户关联请求时为 Yes**；当前客户端没有匿名化或去关联保障。认证行为本身不证明内容会保留，不能把这个候选推成所有端点的统一事实。一般自由文本不因可能包含姓名或病历就增加所有敏感类别。
3. **Identifiers → User ID：条件项。** 若纳入申报的服务实际保留账户、项目或 Key 标识与请求的关联，则评估此项；单凭 Key 可认证不能证明另有长期收集。仅实时验证后不保留的 token 不因发送过就必须申报。不要在公开材料记录原始 Key。
4. **Usage Data → Other Usage Data：条件项。** 按所集成服务实际保留的模型、token、用量记录及其用途判断。若保留具体功能互动，再评估 Product Interaction；不要无证据申报全部点击、滚动或离线编辑已被上传，也不因计费存在就勾选 Analytics。
5. **Diagnostics → Other Diagnostic Data / Performance Data：条件项。** 当前没有应用崩溃、性能遥测上传路径；远端若实际收集与本应用相关的诊断数据，再按内容和用途分类。一般 API 错误回复不等于已建立诊断收集；Apple 独立收集的数据也不应算作开发者收集。
6. **IP 地址：按用途判断，不能机械填定位。** 若用于技术/安全日志，核对诊断类别；若用于推断并保留大致位置，核对 Coarse Location；若用于持久识别，核对 Device ID。当前客户端没有定位读取，远端 IP 用途尚未完整确认。
7. **其他类别：当前客户端没有明确收集路径，不预先勾选。** 包括姓名/邮箱/电话、通讯录、支付信息、购买历史、健康/健身、照片/视频/音频、浏览历史、设备传感器、广告数据。API 供应商在其自有网站收取账单或付款，不代表这些全部经 md any where 上传。GitHub 外部支持流程需与 App 内请求区分，若以后加入反馈上传，再审查 Customer Support。

上述分类依据 Apple 的数据类型、用途、关联及 IP/自由文本指导；具体候选项由本应用代码及服务商公开说明推导，不能作为 Apple 对本应用的确认。**Tracking：当前客户端行为支持候选 No**，没有广告关联或数据经纪商传输路径；纳入申报的第三方集成若有不同实际行为，再相应调整。不要为未知端点填造跟踪事实，也不要向用户承诺所有端点都不跟踪。[Apple 定义](https://developer.apple.com/app-store/app-privacy-details/)；[App Store Connect 填写流程](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。

用途方面：认证、生成答案和安全防滥用按 App Functionality 准备；提供商若用内容训练通用模型或开发其他产品，需评估 **Other Purposes**，不能只报 App Functionality。如果还分析用户行为，再评估 Analytics。没有证据支持 md any where 的广告/营销用途，也没有证据证明模型训练本身就是 Apple 定义的广告跟踪；Tracking 不能仅凭“第三方 AI”自动填 Yes，亦不能为未知代理一律担保 No。

## 各默认服务的官方政策核对

### OpenAI

默认端点为 `api.openai.com/v1/responses`，请求明确带 `store: false`。官方说明 API 数据默认不用于训练（主动共享除外），但标准防滥用日志可含提示词和回复，通常最多保留 30 天，法律/严重安全例外可能更久。ZDR/MAM 需符合资格、获批且受端点/模型限制；关闭 Responses 状态保存不等于关闭这些日志。不能把发行者一个账户的 ZDR 承诺推广到所有 BYOK 用户。[OpenAI 官方数据控制](https://developers.openai.com/api/docs/guides/your-data)。

**型号核验：** `gpt-5.6-luna` 有正式 OpenAI API 型号页，并列出 Responses 支持；它并非仅因同名 Codex 选项就不可用。实际审核账户的访问权限/额度仍须私下测试。[官方型号页](https://developers.openai.com/api/docs/models/gpt-5.6-luna)。

### Anthropic

默认端点为 `api.anthropic.com/v1/messages`。商用 API 标准输入输出通常在 30 天内删除，但违规、法律、约定或特定模型可能延长；不能写成无条件 30 天上限。商用数据默认不训练，主动选择共享或反馈等另有规则。需按实际账户、模型及合同核对，不套用 Claude 消费者订阅政策。[商用留存](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)；[训练说明](https://privacy.claude.com/en/articles/7996885-how-do-you-use-personal-data-in-model-training)。

### Gemini

默认为 `generativelanguage.googleapis.com` 的 `generateContent`，代码不检查账户是否已启用付费，也未强制某地区或服务层级。未付费服务的输入输出可能用于产品/模型改进并人工审阅；适用付费条款的内容不用于该类改进，但仍有安全日志。条款还列有认证、token、错误、性能和 IP 等服务数据。2026-03-23 生效条款要求 API 使用者成年，并限制面向或可能被未成年人访问的 API 客户端；地域与 EEA/英国/瑞士付费条件也必须单独确认。Apple 年龄评级并不自动证明符合这些服务条款。[Gemini API 条款](https://ai.google.dev/gemini-api/terms)。

**影响：** 这是第三方服务条款问题，与 Apple 内容频率题分开评估，不自动得出应用必须 18+。若发行者决定采用特定服务层级、年龄或地区限制，应确认实际实现与声明相符；本评估没有代为选择或修改限制。

### DeepSeek

默认为 `api.deepseek.com/chat/completions`。官方开放平台条款要求下游应用自行向用户披露处理规则、取得相应授权并响应数据权利请求；其第 5.5 条明确区分下游用户的数据规则与一般服务隐私政策。本次获得的官方资料未足以确认 md any where 下游 API 文稿的具体留存天数、训练选择与日志去关联情况。不能从消费者网站的聊天开关推导 API 选择，也不能承诺 API 不训练/不留存。应取得对应开放平台账户的政策或书面数据处理说明。[开放平台条款](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html)；[一般隐私政策及其适用范围](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)。

### GLM / 智谱

默认为 `open.bigmodel.cn/api/paas/v4/chat/completions`。已核对开放平台用户协议（生效日 2026-09-04）；协议列有下游开发者数据安全和服务合规义务，且对免费功能的使用范围另有限制。其[隐私政策页面](https://docs.bigmodel.cn/cn/terms/privacy-policy)本次多次读取失败，未以二手文章填补。具体输入输出留存、训练、IP/账户日志和免费模型商用适用性均待核实，不能申报为“已证实零收集”。[官方用户协议](https://docs.bigmodel.cn/cn/terms/user-agreement)。

### Grok / xAI

默认为 `api.x.ai/v1/chat/completions`。官方 API 安全说明表示未经明确许可不训练，标准请求/回复仍保存 30 天用于审计。ZDR 按团队启用且可关闭，受功能限制；响应头可报告是否生效，当前代码没有读取或强制该状态。不能把提供商有 ZDR 选项写成每个用户都已启用。[官方 API 数据与安全说明](https://docs.x.ai/developers/faq/security)。

### 本地服务及自定义代理

`127.0.0.1` 是当前 iPhone/iPad，不是连接的 Mac。只有确认该服务全链路不再外传，才能把其处理算作设备内。用户可以把任何默认配置改成 HTTPS 代理；代理同时接收凭证和内容，且可能改写、记录、路由至其他服务。以上官方直连政策不能覆盖代理。发行者无法仅凭供应商名称或 `store: false` 为任意代理作出统一不留存、不训练、不跟踪承诺。

## 需要发行者确认的项目

- **源码之外的实际安排：** 当前发布范围已包含现有可选、用户自配 Agent，不把再次确认是否保留 AI 列为阻碍。如另有源码看不到的自营代理、供应商协议或数据使用安排，请补充，以便准确评估。不因自定义端点存在就要求改成受控服务名单。
- **目标用户和已采用的服务条款：** 目标年龄、本应用 EULA 最低年龄及适用第三方服务条件需发行者确认；本文不代定。Gemini 等服务的特定条件应单独核对，不能把提高 Apple 评级当作自动满足服务条款。
- **特殊数据承诺：** 仅当准备作出 ZDR、不训练等特别承诺时，需提供与承诺覆盖范围相符的证据。当前不作跨所有账户、模型或代理的保证，也不要求先让所有 BYOK 用户关闭日志才能填写其他答案。
- **审核可复现性：** 提供什么受限、可撤销且额度足够的服务访问方式，由发行者私下安排。Key、合同和私人联系方式只进入 App Store Connect 私有渠道或本地忽略文件。

预设集成服务中尚无充分依据的日志类别、用途及任意端点的披露归属，是有明确范围的核实事项，不适合让发行者猜测。可以依据相关官方政策或向 App Review 提供架构说明解决。当前没有因此代填“无收集”，也没有把穷尽所有潜在服务器行为列为提交前提。DSA 交易商身份属于另一项发行者法律声明，不由代码或本隐私评估决定。

## 最终填写和发布边界

可以先准备已具依据的答案，并逐项核对尚未明确的实际收集；不要把某个条件项的不确定扩大成整份问卷都不能处理。正式发布的答案仍需准确反映提交版本，无法确认的事实不能用猜测补齐。代码的 `PrivacyInfo.xcprivacy` 收集数组当前为空，不足以证明整体无收集；其与隐私政策、同意界面、App Store Connect 答案应按各自适用范围保持一致，不要求不同格式的字段机械相同。Apple 隐私答案可以单独更新，文档改动不会自动发布标签。[官方填写流程](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。

第三方 AI 分享个人数据的位置必须明确披露并在发送前取得明确同意；当前远程确认框是对应实现，不是对服务商全部行为的认证。参见 [审核指南 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)。年龄题的代码事实和内容范围另见 [年龄评级草稿](Age-Rating-Assessment.md)。本文件没有保存或提交任何后台答案。
