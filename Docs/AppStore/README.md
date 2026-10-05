# App Store 元数据与发布准备

核对日期：2026-10-06。发布目标为 **md any where 移动版 1.0.0 (6)**、`app.mdanywhere.mobile`，以及 macOS `1.0.0 (5)`、`app.mdanywhere.editor`。最终源码审查的五类安全与数据正确性修复已通过本机网络、真实 WebKit、草稿存储和多语言布局回归；语言覆盖为 50 项、47 份目录、每份 584 条。移动 build 6 开发签名归档及发行重签 IPA 导出通过，最低 iOS 17、设备族 1/2、目录与源码资源一致性已核验；macOS build 5 构建、四组件严格深层 ad-hoc 签名和 WebKit DOCX 回归通过。iPhone/iPad 模拟器安装启动、公开示例画面和资源一致性已核验；移动 build 6 上传成功，Apple 已完成处理，TestFlight 状态为“准备提交”，已关联商店版本 1.0.0，iPad 真机安装启动成功，iPhone 本版未安装启动；尚未送审或发布。

- [zh-Hans.json](zh-Hans.json) 与 [en-US.json](en-US.json)：中英文名称、副标题、推广语、描述、关键词和审核备注。
- [Localization.md](Localization.md) 与 [localizations/manifest.json](localizations/manifest.json)：全部 50 个商店本地化项及结构验证；翻译尚未全部经母语审校。
- [submission.json](submission.json)：移动 build 6、macOS build 5 及新商店记录当前状态；历史验证单独列示。
- [Privacy-Assessment.md](Privacy-Assessment.md)、[privacy-answer-draft.json](privacy-answer-draft.json)、[Age-Rating-Assessment.md](Age-Rating-Assessment.md)：代码事实、候选答案与具体待确认项。现有可选、用户自配 Agent 继续纳入准备；不要求穷尽所有未知端点，也不自动判为未收集或 18+。
- [Screenshots/README.md](Screenshots/README.md)：四张简体中文/英文 iPhone 与 iPad 图片来自 build 4，可用于主界面不变的 build 6；保留原文件名，不冒称 build 6 拍摄；新记录简中两张已上传、各设备组 `1/10`，英文待上传。

Apple Developer 已注册 `app.mdanywhere.mobile`。旧 App Store Connect 记录 `6819302567` 已停止全部 175 个地区供应并移除，非永久删除；用户明确不恢复。新记录 `6819394741` 已创建，绑定新标识与 SKU `MD-ANY-WHERE-IOS-001`。完全访问已获用户明确授权，团队仅本人。版本 `1.0.0` 简中推广文字、描述、关键词、支持/营销 URL、版权、私有审核联系人、不要求登录和手动发布设置已保存；简中两张截图已重新上传，两设备组各 `1/10`。副标题、效率/工具分类、免费价格和 174 地区供应设置也已保存；隐私政策 URL 也已保存并核验，基础资料恢复完成；旧记录状态不计入完成。

发行计划保持免费、174 个地区，仅排除中国大陆，香港、澳门、台湾保留，不自动加入未来新增地区。此价格与地区设置已在新记录保存并核验；免费定价向导覆盖 175 个地区，实际供应为排除中国大陆后的 174 个地区，不能混为一项。后续进入大陆前先确认 App 备案适用性，再决定是否办理；没有自营服务器不自动豁免。英文名称可用性、欧盟 DSA 交易商身份、目标年龄及最终隐私/年龄/内容版权声明仍须据实完成，本文不代为作法律声明。公开支持邮箱为 [longshenggdgz@163.com](mailto:longshenggdgz@163.com)，商店版权 `© 2026 陈科霖`；私人审核信息和凭证不进入本仓库。

名称和副标题各限 30 字符；推广语 170 字符；描述 4000 字符；关键词不超过 100 UTF-8 字节。可运行 `python3 Docs/AppStore/validate-localizations.py` 检查本地文案。首版不编造 What's New。参见 [App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) 和 [版本字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。

[源码仓库](https://github.com/mrckl-md/md-any-where)与[隐私政策](https://github.com/mrckl-md/md-any-where/blob/main/PRIVACY.md)继续使用当前地址。历史版本的真机与发行结果不作为 build 6 证明；完整事实及后续事项见[发布准备](../App-Store-Release.md)。

隐私、年龄、内容版权、DSA 和可选 AI 私有审核访问按事实完成，属于送审准备事项；不要求先完成全部问卷才上传已验证的构建。历史 build 1/3/4/5 结果仍单独保留。
