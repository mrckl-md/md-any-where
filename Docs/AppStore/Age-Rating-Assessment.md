# iPhone / iPad 年龄评级评估草稿

核对日期：2026-10-05。范围：当前 iOS 源码、随包界面和公开演示文稿。状态：**能力题已有填写建议；Agent 内容频率仍待定稿；未在 App Store Connect 保存问卷。** 本文没有调用任何 Agent、发送文稿或测试第三方模型输出。

## 建议结论

md any where 是个人文稿编辑器。当前没有网页浏览器、用户间聊天、公开内容社区、社交信息流或广告，这些能力可以据实答“否”。可以编辑任意 Markdown、通过系统分享面板发送文件，并不自动构成 Apple 所定义的广泛分发 UGC 或应用内用户间聊天。这是依据当前实现与 Apple 定义作出的判断，不是 Apple 的个案审核结论。[年龄评级定义](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

**Agent 是实际存在的生成式 AI 功能，不能从评估中删去。** 用户可配置服务端点、模型和自由任务，回复未经本应用内容审核即显示。默认关闭、用户自带 Key、发送前同意以及“学术编辑”提示词，都不能证明回复不含敏感内容。因此，现有证据不足以把所有敏感内容题填成 None，也不足以虚构 Infrequent 或 Frequent。

建议首版继续定位通用生产力工具，不选择 Made for Kids。若发行者决定主动限制到成年人，可在如实完成问卷后选择较高的 18+ override；这只是产品定位建议，并非“AI 必须 18+”的 Apple 规则，也不能替代真实的内容答案或解决不允许上架的内容。[设置与提高年龄评级](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)

## 代码证据

- [iOS AppDelegate](../../Sources/DOTMDiPad/AppDelegate.swift)：`decidePolicyFor navigationAction` 只放行本地编辑器目录和 `about:blank`；`confirmTransfer` 展示接收服务与发送范围；分享使用系统 `UIActivityViewController`。没有联系人、用户账号、消息收件箱、公开帖子或社交流。
- [app.js](../../Sources/DOTMD/Resources/app.js)：`requestAgentEdits` 接受自定义任务与文稿上下文；`showAgentResults` 使用 `textContent` 显示返回文本。这避免 HTML 执行，却不是敏感文本过滤。Markdown 外部网络链接受到限制。
- [AgentService.swift](../../Sources/DOTMD/AgentService.swift)：`runSelectedAgents` 的系统提示要求学术编辑和不捏造引文，没有年龄或敏感内容规则；`requestAgentCompletion` 检查 URL 协议、响应大小和 JSON 格式，随后原样返回文本。远程端点可自定义为 HTTPS，本地 HTTP 限回环。没有统一内容审核器、强制受控服务名单或年龄校验。
- [index.html](../../Sources/DOTMD/Resources/index.html)：预设写作/公式任务，同时提供自定义任务、可编辑端点和模型。没有面向儿童的家长密码、分龄开关、广告、抽奖、投注或竞赛。
- [公开演示文稿](../../tests/fixtures/mobile-demo.md)：写作、数学公式、流程图及功能清单，没有敏感内容。这个结论仅覆盖随包示例，不能代表 Agent 全部可达输出。

## 能力题：可以定稿的建议

以下是对本应用的逐项判断；英文名称用于对照后台，最终以实际问卷标签为准。

- **Parental Controls：No。** 普通 Agent 启用开关不是由家长管理的内容或使用限制。
- **Age Assurance：No。** 没有年龄估计、验证、声明年龄 API 或分龄访问机制。
- **Unrestricted Web Access：No。** WKWebView 用来运行本地编辑器；自定义 API 请求不是让用户自由浏览任意网页。
- **User-Generated Content：No。** 文稿保存在用户选择的文件或应用恢复副本中，没有应用内向广泛用户分发内容的功能。
- **Social Media：No。** 没有可发现、扩散或互动的公开内容信息流。
- **Social Media Disabled for Users Under 13：Not applicable。** 上题为 No 时不应把此条件项填成 Yes；应用也没有实现该项要求的年龄检查。如果后台强制显示布尔值，按“没有此能力”答 No。
- **Messaging and Chat：No。** 用户与 AI 交互，不是应用内用户互相通信。系统分享文件不构成内建聊天服务。
- **Advertising：No。** 没有广告展示或广告 SDK。

截至核对日，Apple 官方公开类别页没有列出独立的通用“AI-generated content”年龄问卷项，也未查到“使用 AI 一律 18+”规定。**如果实际 App Store Connect 新增了“是否包含 AI 生成内容”或同义问题，应填 Yes，并说明文本生成、可配置服务与自定义任务。** 不应把“没有公开的独立字段”解释为可以忽略 AI 内容。

2026 年 9 月起，社交媒体新增问题已是提交新应用/更新的必答项；不能只沿用旧的 UGC/聊天三个答案。[Apple 关于新版社交媒体问卷的公告](https://developer.apple.com/news/?id=tlur8uvi)

## 内容题：逐项建议与未决频率

这里的“待核验”是材料准备状态，**不是 App Store Connect 可选值**。它意味着当前不能代填或提交该项。随包示例没有下列内容；仍需把可选 Agent 的实际行为纳入最终答案。不能仅因用户可以自行键入、导入某种文字，就将普通编辑器所有内容题判为“有”。这里的未决依据是应用主动提供了可反复调用的生成服务，而且允许更换服务及任务。

- **Profanity or Crude Humor：待核验频率。** 自定义润色、创作或转写任务可以请求此类文字，当前没有本应用阻断。
- **Horror/Fear Themes：待核验频率。** 没有预设恐怖内容，但自由创作路径未限制题材。
- **Alcohol, Tobacco, or Drug Use or References：待核验频率。** 没有消费功能或相关默认内容；Agent 可讨论、改写或生成相关材料。
- **Medical or Treatment Information：待核验频率。** 产品没有医疗诊断或治疗功能，也不提供医疗默认模板；自由任务仍可请求相关建议，现有提示词不限制回答。
- **Health or Wellness Topics：待核验是否存在。** 没有健康/健身功能；若自由任务会生成健康生活建议，不能仅因产品分类是 Productivity 而忽略。若后台使用 Yes/No，则按实际输出与访问条件定稿。
- **Mature or Suggestive Themes：待核验频率。** 自由任务可以包含成人议题、创伤、战争等；并非只有色情才属于本项。
- **Sexual Content or Nudity：待核验频率。** 纯文字回复也可能包含性相关表达；没有图片生成器不是答 None 的充分依据。
- **Graphic Sexual Content and Nudity：待核验，必须单独排查。** 未观察到实际输出，不能凭“任何端点理论上都可能返回”就宣称已经存在；也不能在没有验证或产品约束时宣称不存在。
- **Cartoon or Fantasy Violence：待核验频率。** 没有内置暴力画面/游戏；自由写作可生成幻想打斗文本，应依据后台示例和实际输出判断。
- **Realistic Violence：待核验频率。** 没有默认暴力内容；自由任务未对相关叙述作限制。
- **Prolonged Graphic or Sadistic Realistic Violence：待核验，必须单独排查。** 当前没有审核或拒绝机制证据，不能自动填 None；也不能无实际依据判为已包含。
- **Guns or Other Weapons：待核验频率。** 文稿和 Agent 任务可能涉及武器描述；没有武器商品销售功能并不解决内容描述题。
- **Gambling：No。** 没有投注、金钱输赢或可兑换真实价值的筹码功能。
- **Simulated Gambling：None / No。** 没有模拟投注玩法。Agent 解释相关概念不等于本应用提供模拟赌博；若以后加入可运行玩法须重新评估。
- **Contests：None。** 没有用户之间的排名、奖励或竞赛。Agent 并行评审不是用户竞赛。
- **Loot Boxes：No。** 没有购买随机虚拟物品的容器或机制。

频率必须反映发布版本的可达体验。默认关闭或额外配置步骤不是自动等于“低频”；同样，没有真实使用或输出证据也不应把所有可想象题材一律填成“频繁”。应记录正常写作流程以及特定内容任务是否可反复获得相关结果，再按后台定义选择实际值。旧 API 枚举 `INFREQUENT_OR_MILD` / `FREQUENT_OR_INTENSE` 已弃用，新接口使用 `INFREQUENT` / `FREQUENT`。[Apple Age Ratings API](https://developer.apple.com/documentation/appstoreconnectapi/age-ratings)

Apple 对露骨性内容和持续写实血腥/虐待暴力的评级可以是 Unrated，不能以“提高到 18+”解决。官方安全规则还明确覆盖露骨性**描述**，不仅是图片；评级答案应如实反映功能。[年龄评级定义](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) [审核指南 1.1、2.3.6](https://developer.apple.com/app-store/review/guidelines/)

## 最少需要发行者确认的两点

1. **首版 Agent 范围**：保留当前任意兼容端点、模型与自由任务，还是另做受控版本。默认按当前代码“保留”评估。若保留，少量默认模型测试不能代表用户可配置的全部服务；需要向 App Review 明确说明这一边界，不能由维护者承诺不存在某类输出。若要对 None 或低频作可靠承诺，需先明确并落实受控服务/内容策略；这将是另一个代码与验证任务，本次没有擅自修改。
2. **目标年龄/EULA**：是否将首版定位为成人工具并在准确问卷之上主动提高至 18+，以及是否已有必须遵守的最低使用年龄条款。不要为了取得某个期望评级而反向修改内容答案。Apple 允许提高评级，且要求覆盖比计算评级更高的 EULA 年龄门槛。[设置年龄评级](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)

此外还需要一次**执行验收**，不是再问发行者十几个猜测题：在拟发布范围内记录服务/模型版本、正常任务、各敏感类别的允许/拒绝结果及可重复性；若任意端点仍开放，向审核备注明确该限制，并依据实际后台题目与 Apple 个案反馈定稿。此评估没有获得调用用户付费服务的授权，因此没有产生 API 费用或伪造测试结论。

## 可供审核备注使用的事实说明

> md any where is a private Markdown editor for iPhone and iPad. It has no public content feed, user-to-user messaging, advertising, or unrestricted in-app web browser. Optional Agent tools generate text through providers, HTTPS endpoints, and models configured by the user. Agent tools are disabled by default. Users may enter custom writing instructions. Before each remote run, the app asks for consent and identifies the destination and the document scope. The app does not implement a universal content-moderation layer across user-configured providers. Provider behavior and restrictions may differ. These optional generation capabilities are included in our age-rating assessment.

这是当前实现的客观说明；在敏感频率和最终评级未确认前，不附加“全部输出适合儿童”“所有供应商已安全过滤”等承诺。Apple 要求明确说明向第三方 AI 分享个人数据的位置，并在分享前取得明确同意；当前原生确认框是对应实现，但隐私同意不等于年龄验证或内容审核。[审核指南 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/)

## 本次边界

本次只读检查代码及 Apple 官方材料，只新增本文。没有修改年龄限制、提示词、过滤机制、App Store 元数据 JSON 或发布状态；没有登录、保存或提交 App Store Connect 问卷。最终值仍应由发行者对实际提交版本确认，保留后台计算的各地区及旧系统评级结果，不能将建议 18+ 写成已获 Apple 评级。
