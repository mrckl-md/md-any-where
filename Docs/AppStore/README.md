# App Store 元数据草稿

核对日期：2026-10-05。以下文本可逐字段复制到 App Store Connect。简体中文名称、副标题与版本文案已保存；其余语言为本地草稿，英文名称冲突待解决。没有上传构建或提交审核。

- [zh-Hans.json](zh-Hans.json)：简体中文名称、副标题、推广语、描述、关键词和审核备注。
- [en-US.json](en-US.json)：英文商店文案；界面语言实际覆盖以应用本地化验证为准。
- [Localization.md](Localization.md)：Apple 当前全部 50 个商店本地化项及译文审核边界；另 48 份文案在 [localizations](localizations/manifest.json)，可离线验证字段长度。
- [submission.json](submission.json)：Bundle ID、拟定 URL 与仍需发行者填写的字段。
- [privacy-answer-draft.json](privacy-answer-draft.json) 与 [Privacy-Assessment.md](Privacy-Assessment.md)：基于代码和官方政策的隐私候选答案及未确认的 AI 服务范围，不能当成已完成问卷。
- [Screenshots/README.md](Screenshots/README.md)：四张改名前历史截图的设备组、尺寸和内容说明；新品牌截图待重拍，尚未上传。

品牌名精确为 `md any where`，版本为 `1.0.0 (3)`。新构建已通过三端编译、多语言回归及真机安装；此前构建 `1` 的发行导出与真机 PDF/DOCX 检查作为历史记录保留，不把旧产物当作新版本。DOCX 公式此前验证到 OMML 结构，未用 Word/WPS 目视检查。归档、分发签名及设备验收的当前范围见[发布准备](../App-Store-Release.md)。Apple 服务器 Validate、上传、TestFlight 与提交审核仍未执行。

名称和副标题上限各 30 字符；推广语 170 字符；描述 4000 字符；关键词按 Apple 当前说明不超过 100 UTF-8 字节。文件已按这些边界检查。首版不需要 What's New，因此未提供伪造更新历史。参见 [App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) 和 [版本字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。

已确认售价免费、销售地区包括中国大陆、商店版权署名 `© 2026 陈科霖`，公开支持邮箱为 [longshenggdgz@163.com](mailto:longshenggdgz@163.com)。私人审核联系人已保存于 App Store Connect，不写入本仓库。中国大陆备案资料、新品牌截图、分发签名、最终 AI 范围、年龄评级、隐私问卷及 Agent 审核访问方式仍待落实。新 [仓库](https://github.com/mrckl-md/md-any-where)及[政策链接](https://github.com/mrckl-md/md-any-where/blob/main/PRIVACY.md)随源码同步。完整门槛见 [发布准备](../App-Store-Release.md)。
