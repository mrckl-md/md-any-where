# iPhone / iPad 年龄评级事实草稿

## Saved questionnaire - 2026-10-06

App Store Connect record `6819394741`, iOS `1.0.0 (6)`: the questionnaire was saved and Apple calculated a global **4+** rating, including the global rating for systems before version 26. Regional exceptions remain controlled by Apple. This is not an approval decision.

The publisher confirmed general writing users, no extra minimum age, and no Kids category. The final override question was set to Not Applicable. Capability questions were answered No and supplied-content frequency questions None, based on the editor, supplied templates and public fixtures. No live model output was tested; the reviewer notes disclose optional BYOK generation and the absence of a universal moderation layer. Provider account, age and regional conditions remain separate.

The earlier assessment below preserves the reasoning and limits; its draft/pending wording describes the assessment stage, superseded by this saved result. The release binary was not changed.

修订日期：2026-10-06；官方定义核对日期：2026-10-05。范围：当前 iOS 源码、随包界面及公开演示文稿。本文提供 App Store Connect 问卷的代码事实与候选答案，**不是已保存或已获 Apple 确认的评级**。没有调用第三方模型、发送文稿、测试付费 API 或修改应用功能。

当前移动目标为 `app.mdanywhere.mobile`、构建 `1.0.0 (6)`。本地 Release 开发签名及严格验签、iPhone/iPad 模拟器安装启动和公开示例导入已通过。业务数据流与内容评估沿用此前已核实的实现事实，最终权限、发送范围与真机交互仍须单独核验；上述构建检查不等于隐私或年龄问卷定稿。应用标识变化也不保证历史草稿或 Keychain 自动迁移。

## 填写原则

md any where 的实际用途是个人 Markdown 编辑、预览、导出及可选的文本 Agent 辅助。评级应反映提交版本实际提供的功能和内容。不能仅因用户可自行写入任意文字或配置通用模型，就认定应用频繁提供每种敏感内容；同样，未测试模型输出不能写成已证实所有输出安全。Apple 依据问卷中的能力、内容及频率计算评级，没有查到“通用 AI 或 BYOK 必须一律 18+”的规定。[Apple 年龄评级定义](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

当前发布准备继续包含已有的可选、用户自配 Agent，无需再次确认是否保留该功能，也不将建立受控服务名单或统一内容过滤器设为填写所有答案的前提。若实际内容、产品定位或服务安排后来改变，应另行落实并重新评估；本次不代为删功能或限制用户年龄。

## 可据源码填写的能力题

以下是当前实现对应的事实建议，英文名称供对照后台；实际题目或选项改变时应重新核对。

- **Parental Controls：No。** 没有由家长管理的内容、时长或访问控制。普通 Agent 开关不属于家长控制。
- **Age Assurance：No。** 没有年龄验证、估计、声明年龄 API 或分龄访问机制。
- **Unrestricted Web Access：No。** WKWebView 只加载本地编辑器；用户填写 API URL 不等于可以自由浏览网页。
- **User-Generated Content：No。** 没有应用内向广泛用户分发文稿的功能。用户保存或用系统分享面板导出自己的文件，不自动构成此项。
- **Social Media：No。** 没有公开信息流、关注或扩散内容的社交机制。
- **Social Media Disabled for Users Under 13：Not applicable。** 没有社交媒体能力；如后台强制显示布尔值，按不存在该能力答 No，不能虚构分龄限制。
- **Messaging and Chat：No。** 没有用户彼此通信的内建功能。用户与模型交互不等于用户间聊天。
- **Advertising：No。** 没有广告展示或广告 SDK。

这些判断采用 Apple 对网页浏览、广泛分发 UGC、社交媒体和用户间聊天的具体定义，而非把“联网”作为统一判断标准。[官方类别说明](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

如实际后台出现独立的“AI 生成内容”或同义问题，当前功能的事实答案是 **Yes，包含可选文本生成**。所查公开类别页未列出这项独立字段，不据此忽略 Agent，也不虚构后台已出现该题。

## 内容题的事实与候选答案

随包文稿、预设任务和界面围绕写作、公式、流程图及编辑功能，检查范围内未发现下列敏感内容。以下 `None` 是据该实际提供内容准备的**候选值**，不是对任意用户文稿或第三方模型所有可能输出的保证：

- **Profanity or Crude Humor：None 候选。** 无内置粗俗、侮辱或低俗幽默内容。
- **Horror/Fear Themes：None 候选。** 无内置恐怖内容或相关默认任务。
- **Alcohol, Tobacco, or Drug Use or References：None 候选。** 无内置相关内容或消费功能。
- **Medical or Treatment Information：None 候选。** 不提供医疗诊断、治疗服务或相关默认模板。
- **Health or Wellness Topics：No 候选。** 没有健康或健身指导功能及默认内容；以后台实际选项为准。
- **Mature or Suggestive Themes：None 候选。** 无内置成人暗示或相关主题内容。
- **Sexual Content or Nudity：None 候选。** 无内置性相关内容；纯文本仍可能属于内容题，不能仅凭没有图片生成功能排除该类别。
- **Graphic Sexual Content and Nudity：None 候选。** 检查范围内未发现此内容，未观察或测试模型是否会产生此类输出。
- **Cartoon or Fantasy Violence：None 候选。** 无内置幻想暴力内容或玩法。
- **Realistic Violence：None 候选。** 无内置写实暴力内容。
- **Prolonged Graphic or Sadistic Realistic Violence：None 候选。** 检查范围内未发现此内容，未作模型输出测试。
- **Guns or Other Weapons：None 候选。** 无内置武器内容或相关功能。

可选 Agent 接受用户任务、文稿上下文和自选模型，回复会在本地显示；代码没有统一的敏感文本过滤器。这是评估范围的一部分。**最终内容答案应考虑拟发布版本的实际 Agent 体验及已有证据**：如果默认流程、明确支持的内容用途或已观察到的输出包含某类内容，应据实调整该项及频率。没有这类证据时，不因“任何端点理论上都能返回”直接填 Infrequent 或 Frequent，也不据此将其余代码事实答案全部搁置。

当前未执行模型输出测试，因此不能将上述候选批量标记为“全应用全部内容已验证 None”。需要进一步验证时，应针对影响答案的具体功能或类别记录正常使用及可重复结果；不要求穷尽所有未来用户服务器，也不把未穷尽等同于已存在全部敏感内容。最终仍有解释分歧时，可以向 App Review 说明通用客户端的架构与范围，请其就具体题目给出意见。[如实填写年龄问卷](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)

以下机制不存在，可以据源码准备相应答案：

- **Gambling：No。** 没有投注、金钱输赢或可兑换真实价值的筹码。
- **Simulated Gambling：None / No。** 没有模拟投注玩法。文本讨论概念不等于提供赌博机制。
- **Contests：None。** 没有用户竞赛、排名或奖励；Agent 并行评审不是用户竞赛。
- **Loot Boxes：No。** 没有付费随机虚拟物品机制。

提高评级不能替代准确的内容答案，也不能解决 Apple 不允许上架的内容；不得将“18+”当作所有内容的通用许可。[审核指南 1.1、2.3.6](https://developer.apple.com/app-store/review/guidelines/)

## 需要发行者确认的内容

1. **目标用户及最低年龄条款。** 是否面向儿童、是否有本应用 EULA 最低年龄，以及是否希望主动提高系统计算评级，均保留待确认。本文不替发行者选择 Made for Kids、成人定位或 18+ override；若 EULA 最低年龄高于计算评级，Apple 要求相应提高评级。[设置年龄评级](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
2. **源码之外的实际产品安排。** 现有可选 Agent 已纳入本次准备，不再询问是否保留。如另有未体现在源码的默认内容、服务约定或内容限制，请补充；没有新增安排时即可沿用本草稿事实，不要求先另选供应商。
3. **事实验证和最终回答。** 发行者应确认影响内容题的实际体验，保留必要的验证记录或 Apple 个案解释，再批准最终答案。本次没有获得 API 访问凭证或产生调用费用，也没有伪造输出结果。

第三方服务自己的年龄、地区或账户条件，应与本应用的 Apple 评级分别核对；提高评级不自动满足服务条款。DSA 交易商身份是另一项发行者法律声明，不能由本文件或源代码代为决定。

## 可供审核备注使用的事实说明

> md any where is a private Markdown editor for iPhone and iPad. It has no public content feed, user-to-user messaging, advertising, or unrestricted in-app web browser. Optional Agent tools generate text through providers, HTTPS endpoints, and models configured by the user. These tools are disabled by default. Users can enter writing instructions. Before each remote run, the app identifies the destination and document scope and asks for consent. The app does not apply a universal content-moderation layer across user-configured providers. Provider behavior may differ. Our age-rating answers consider the editor's supplied content and its optional generation features.

此段描述代码事实，不包含已获评级、所有输出适合儿童或全部供应商已过滤的承诺。远程数据分享同意不是年龄验证或内容审核；第三方 AI 分享要求另见 [审核指南 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing) 和 [隐私评估](Privacy-Assessment.md)。

## 代码依据与本次范围

- [iOS AppDelegate](../../Sources/MDAnyWhereMobile/AppDelegate.swift)：本地页面导航限制、`confirmTransfer` 和系统分享面板。
- [AgentService.swift](../../Sources/MDAnyWhere/AgentService.swift)：默认关闭的七个配置、自由端点和模型、学术编辑提示、原生 API 请求及响应处理。
- [app.js](../../Sources/MDAnyWhere/Resources/app.js) 与 [index.html](../../Sources/MDAnyWhere/Resources/index.html)：预设/自定义任务、返回文字显示和本地编辑界面。
- [公开示例](../../tests/fixtures/mobile-demo.md)：写作、公式、流程图与编辑功能的测试文稿。

本次只修订评估材料，未修改功能、法律声明或后台问卷。最终应保存实际后台计算的地区和旧系统评级结果，不能将本文候选值当作已发布评级。
