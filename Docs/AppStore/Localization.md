# 商店本地化语言与验证

核对日期：2026-10-05。Apple 当前公布 **50 个 App Store 元数据本地化项**，包括地区变体。官方地区语言表与 API 短码表分别描述顾客看到哪一种语言、上传时使用哪个标识；国家/地区数与语言数不能混用。[官方地区语言表](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations)；[官方 locale 短码](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes)。

## 本仓库已提供

全部 50 项商店文案已经写入：保留原来的 `en-US.json`、`zh-Hans.json` 字段结构；另外 48 项位于 `localizations/`。每项都有名称、副标题、推广文字、关键词、描述、审核备注、公开支持邮箱和版权。品牌名一律保持精确的 `md any where`。

[manifest.json](localizations/manifest.json) 从 Apple 官方短码表核对生成，记录每项文件及建议界面语言映射。需特别保留 `ar-SA`、`bn-BD`、`nl-NL`、`gu-IN`、`kn-IN`、`ml-IN`、`mr-IN`、`or-IN`、`pa-IN`、`sl-SI`、`ta-IN`、`te-IN`、`ur-PK` 等正式商店短码，不能把运行时的语言前缀直接当成 App Store Connect 标识。

非英文文案是对应语言的实际译文，没有用英文复制品填补覆盖率。英语地区共用适用的英语内容；法语加拿大版、葡萄牙语两地区和西班牙语两地区按用语进行适配。描述强调 macOS、iPhone、iPad 三端，以及 macOS 的 MCP/CLI 与移动内置 Agent 的边界，不承诺在手机上运行桌面 IDE。所有版本都保留远程请求同意、可能的服务收费与第三方留存说明，并明确应用不附带 AI 模型额度、本机编辑无须启用 Agent。

已逐份核对 50 项描述与审核备注中的关键产品事实：Agent 默认停用、用户自配服务、本机功能无须应用账户、macOS 的 MCP/CLI 与移动内置 Agent 分工，以及无自营云同步。未宣称所有国家/地区已经可售，也未宣称全部界面语言或新构建已经验收。此核对为开发辅助检查，不代替母语审校。

这些译文为 AI 初译，已完成结构和技术词核对，**尚未经过每种语言的母语编辑审校**。翻译文件齐全不表示语言表达、法律语义和当地商店习惯已经获得人工认证。发布前优先请母语使用者复核副标题、数据发送同意、错误/恢复提示与隐私文案。[Apple 本地化建议](https://developer.apple.com/documentation/xcode/localization)。

## 机器验证

在仓库根目录运行：

```sh
python3 Docs/AppStore/validate-localizations.py
```

验证 50 项清单、JSON 字段、名称/副标题 30、推广文字 170、描述 4000 的 UTF-16 长度，以及关键词 100 UTF-8 字节边界；核对品牌和平台技术词保留，并防止整段英文误充其他语言。它不能证明译文的母语自然度。[Apple 元数据字段要求](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。

界面运行时语言文件与原生字符串的译文来源、重点审查及限制见[界面本地化说明](../Localization.md)，由应用本地化实现另行验证，包括键集合、占位符、Markdown/公式/流程图语法、系统语言回退、从右到左排版和小屏布局。商店文案已齐全，不作为全部界面翻译或每个设备场景已通过的证据。

## 尚待后台和发行者完成

这些本地文件没有作为全部 50 组本地化保存到后台，也没有提交审核。既有 App Store Connect 记录 `6819302567` 曾保存简体中文名称/副标题/版本文案、效率/工具分类与私有审核联系人；英文名称冲突仍待发行者决定。当前目标标识为 `app.mdanywhere.ios`、构建 `4`，Apple Developer 已注册该标识，既有记录 `6819302567` 已成功保存绑定。该记录不可编辑的 SKU 仍保留历史内部编号，处理方式待用户决定，不公开其值或声称全部云端字段改名。

发行计划为免费、174 个地区，仅排除中国大陆，香港、澳门、台湾保留，不自动加入未来新增地区；此选择已在当前记录保存，新标识绑定也已确认。后续进入大陆前先确认备案适用性，再决定是否办理。现有可选、用户自配 AI 继续准备；年龄、隐私最终答案与 DSA 交易商身份分别按事实和发行者确认处理，不另设删除 AI 的前提。历史截图已退休；构建 `4` 的简体中文、英文 iPhone/iPad 四张截图已真实拍摄核验；简体中文两张已替换后台旧图并上传、各设备组为 `1/10`，英文两张尚未上传，其他语言不冒用这两种语言的图片。审核凭证和私人联系方式不得进入公开文件。语言覆盖不等于地区发行许可。[Apple 本地化说明](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information)。
