# App Store 元数据与发布准备

核对日期：2026-10-06。当前目标为 **md any where 1.0.0 (4)**，iOS 标识 `app.mdanywhere.ios`，工程及 scheme 为 `MDAnyWhere-iOS`。新标识的 macOS 构建及严格深层 ad-hoc 签名检查、iOS 模拟器构建和 iPhone/iPad 模拟器安装启动已通过；包内 47 份 catalog、51 个语言目录及设备族 `1,2` 已核对。四张中英文截图已准备；简体中文两张已替换后台旧图并上传，两设备组各核验为 1/10；英文两张尚未上传。新标识的移动存储 9 项、布局 9 项、50 项语言与 27 组 WebKit 场景、WebKit DOCX 回归已通过。本机 Automatic 使用已存描述文件完成 arm64 Release 开发签名和严格验签，没有启用在线描述文件更新。iPad 新标识安装成功，但因设备服务不可用尚未确认启动；iPhone 因连接异常安装失败。解锁重连后可复用现有签名包重试，发行归档仍待完成，不沿用历史版本 `1`、`3` 的通过结论。

- [zh-Hans.json](zh-Hans.json) 与 [en-US.json](en-US.json)：中英文名称、副标题、推广语、描述、关键词和审核备注。
- [Localization.md](Localization.md) 与 [localizations/manifest.json](localizations/manifest.json)：全部 50 个商店本地化项及结构验证；翻译尚未全部经母语审校。
- [submission.json](submission.json)：新标识及构建 `4` 当前状态；历史验证单独列示，不混作新版本证据。
- [Privacy-Assessment.md](Privacy-Assessment.md)、[privacy-answer-draft.json](privacy-answer-draft.json)、[Age-Rating-Assessment.md](Age-Rating-Assessment.md)：代码事实、候选答案与具体待确认项。现有可选、用户自配 Agent 继续纳入准备；不要求穷尽所有未知端点，也不自动判为未收集或 18+。
- [Screenshots/README.md](Screenshots/README.md)：构建 `4` 的简体中文、英文 iPhone 编辑与 iPad 分栏共四张截图已真实拍摄核验；简体中文两张已上传到 iPhone 6.9 英寸与 iPad 13 英寸组并各核验为 1/10，原有旧图已删除，英文两张尚未上传；历史图片已从当前公开素材移出并保留备份。

Apple Developer 已注册 `app.mdanywhere.ios`，App Store Connect 记录 `6819302567` 已成功保存绑定。不可编辑 SKU 仍是历史内部编号，处理方式待用户决定；不公开其值，也不声称云端全部内部字段已改名。该既有记录曾保存简体中文名称、副标题、分类、版本文案、私有审核联系人、免费价格和政策 URL，以及 174 个发行地区：唯一排除中国大陆，香港、澳门、台湾保留，未来新增地区不自动加入。这些设置与新绑定均属于同一记录；后台配置保存不等于构建已上传或审核通过。

历史版本 `1` 曾成功发行导出；历史版本 `3` 曾归档成功，但导出进程报账号/签名访问错误。这不证明用户已退出登录。如新构建仍遇到错误，先查看 Xcode 的“Settings → Apple Accounts”状态，不预先删除账号或重新登录。历史版本的 DOCX 公式只验证到 OMML 结构，未用 Word/WPS 目视核验；新标识的模拟器验证不替代真机与发行验收。

名称和副标题各限 30 字符；推广语 170 字符；描述 4000 字符；关键词不超过 100 UTF-8 字节。可运行 `python3 Docs/AppStore/validate-localizations.py` 检查本地文案。首版不编造 What's New。参见 [App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) 和 [版本字段](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。

发行计划保持免费、首发排除中国大陆。后续进入大陆前先确认 App 备案适用性，再决定是否办理；没有自营服务器不自动豁免。英文商店名称冲突、欧盟 DSA 交易商身份、目标年龄和最终问卷仍待相应确认，本文不代为作法律声明。公开支持邮箱为 [longshenggdgz@163.com](mailto:longshenggdgz@163.com)，商店版权 `© 2026 陈科霖`；私人审核信息和凭证不进入本仓库。

[源码仓库](https://github.com/mrckl-md/md-any-where)与[隐私政策](https://github.com/mrckl-md/md-any-where/blob/main/PRIVACY.md)继续使用当前地址。新标识构建尚未上传，Apple 服务器 Validate、TestFlight、送审和发布均未完成。完整事实及后续事项见[发布准备](../App-Store-Release.md)。
