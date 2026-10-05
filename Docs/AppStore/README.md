# App Store 元数据草稿

核对日期：2026-10-05。以下文本可逐字段复制到 App Store Connect，但所有文件仍是“准备中”，没有执行上传或提交。

- [zh-Hans.json](zh-Hans.json)：简体中文名称、副标题、推广语、描述、关键词和审核备注。
- [en-US.json](en-US.json)：英文商店文案，明确 UI 目前以简体中文为主。
- [submission.json](submission.json)：Bundle ID、拟定 URL 与仍需发行者填写的字段。
- [privacy-answer-draft.json](privacy-answer-draft.json)：隐私填写依据及待核实项，不能当成已完成问卷。
- [Screenshots/README.md](Screenshots/README.md)：四张最终源码模拟器截图的设备组、尺寸和内容说明，iPhone/iPad 各两张，尚未上传。

本地 Release archive 和 App Store `.ipa` 已生成，版本 `1.0.0 (1)` 的分发签名、禁用调试权限及 iPhone/iPad 设备族已检查。最终构建的 iPhone 真机 PDF/DOCX 导出已复测，移动存储与布局回归通过；DOCX 公式目前验证到 OMML 结构，未用 Word/WPS 目视检查。详细范围见[发布准备](../App-Store-Release.md)。Apple 服务器 Validate、上传、TestFlight 与提交审核仍未执行。

名称和副标题上限各 30 字符；推广语 170 字符；描述 4000 字符；关键词按 Apple 当前说明不超过 100 UTF-8 字节。文件已按这些边界检查。首版不需要 What's New，因此未提供伪造更新历史。参见 [App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) 和 [版本字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。

提交前必须补齐真实审核联系人、公开支持联系方式、可访问政策 URL、价格/地区选择、最终年龄评级、隐私问卷及可选 Agent 审核访问方式，并完成剩余发布验收。[公开仓库](https://github.com/mrckl-md/DOT-MD)已推送到 `main`，MIT 许可证和[政策文件](https://github.com/mrckl-md/DOT-MD/blob/main/PRIVACY.md)链接已核验；不能将当前占位发布状态送审。完整门槛见 [发布准备](../App-Store-Release.md)。
