# App Store 元数据与发布准备

核对日期：2026-10-06。移动目标为 **md any where 1.0.0 (5)**、`app.mdanywhere.mobile`；macOS 保持 `1.0.0 (4)`、`app.mdanywhere.editor`。移动版 Release 本地自动开发签名和归档严格验签已通过，没有启用在线描述文件更新；归档仍为开发签名，尚未完成 App Store 发行签名导出。iPhone/iPad 模拟器均完成安装、启动和公开示例导入；设备族 `1,2`、47 份 catalog、每份 583 条和 51 个语言目录已核对。build 5 真机部署、服务器 Validate、构建上传、送审和发布尚未完成。

- [zh-Hans.json](zh-Hans.json) 与 [en-US.json](en-US.json)：中英文名称、副标题、推广语、描述、关键词和审核备注。
- [Localization.md](Localization.md) 与 [localizations/manifest.json](localizations/manifest.json)：全部 50 个商店本地化项及结构验证；翻译尚未全部经母语审校。
- [submission.json](submission.json)：移动 build 5、macOS build 4 及新商店记录当前状态；历史验证单独列示。
- [Privacy-Assessment.md](Privacy-Assessment.md)、[privacy-answer-draft.json](privacy-answer-draft.json)、[Age-Rating-Assessment.md](Age-Rating-Assessment.md)：代码事实、候选答案与具体待确认项。现有可选、用户自配 Agent 继续纳入准备；不要求穷尽所有未知端点，也不自动判为未收集或 18+。
- [Screenshots/README.md](Screenshots/README.md)：四张简体中文/英文 iPhone 与 iPad 图片来自 build 4，可用于界面不变的 build 5；保留原文件名，不冒称 build 5 拍摄，新记录尚未上传。

Apple Developer 已注册 `app.mdanywhere.mobile`。旧 App Store Connect 记录 `6819302567` 已停止全部 175 个地区供应并移除，非永久删除；用户明确不恢复。新建表单已填入新标识与 SKU `MD-ANY-WHERE-IOS-001`。有限访问选项不可用，自动审批拒绝选择完全访问，具体授权待用户确认，因此新记录尚未创建，Apple ID 为空。旧记录曾保存的价格、地区、政策 URL、文案、联系人和截图不计入新记录完成状态。

发行计划保持免费、174 个地区，仅排除中国大陆，香港、澳门、台湾保留，不自动加入未来新增地区。创建新记录后须重新保存并核验。后续进入大陆前先确认 App 备案适用性，再决定是否办理；没有自营服务器不自动豁免。英文名称可用性、欧盟 DSA 交易商身份、目标年龄及最终隐私/年龄/内容版权声明仍须据实完成，本文不代为作法律声明。公开支持邮箱为 [longshenggdgz@163.com](mailto:longshenggdgz@163.com)，商店版权 `© 2026 陈科霖`；私人审核信息和凭证不进入本仓库。

名称和副标题各限 30 字符；推广语 170 字符；描述 4000 字符；关键词不超过 100 UTF-8 字节。可运行 `python3 Docs/AppStore/validate-localizations.py` 检查本地文案。首版不编造 What's New。参见 [App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) 和 [版本字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。

[源码仓库](https://github.com/mrckl-md/md-any-where)与[隐私政策](https://github.com/mrckl-md/md-any-where/blob/main/PRIVACY.md)继续使用当前地址。历史版本的真机与发行结果不作为 build 5 证明；完整事实及后续事项见[发布准备](../App-Store-Release.md)。
