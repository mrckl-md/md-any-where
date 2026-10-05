# 参与 DOT MD 开发

欢迎改进编辑体验、学术公式、可访问性和隐私保护。项目自有代码位于 `Sources/DOTMD/`、`Support/` 和 `scripts/`；`Resources/vendor/` 是保留上游许可证的第三方发布文件，不应直接修改。`.build/`、`dist/` 为可重建产物。

## 易读的命名

- 函数使用“动作 + 对象”，例如 `renderMarkdownPreview`、`saveProfiles`、`loadDocumentImage`。避免只写 `run`、`write`、`handle`、`data`，除非作用域小到含义显然。
- 集合或状态写出其所代表的对象，例如 `selectedProfiles`、`pendingAutosaveTasks`；布尔值优先使用 `is`、`has` 或明确的过去分词。
- 单位、限制与格式写清楚：`maxEdits`、`candidateLength`、`sourceWidth`。标准格式缩写如 `DOCX`、`MathML`、`XML` 可以保留。
- 不要仅为了缩短名字而增加新缩写，也不要把 API 字段、DOM ID 或用户存储键当作内部变量批量重命名。

## 保持消息桥兼容

原生层通过 `invokeEditorJavaScript` 调用 `window.dotmd`，网页层通过 `sendNativeMessage` 发送消息。DOCX 设置和数学节点还使用 Swift/JavaScript 共用的 JSON 字段。内部函数可以改名，但桥对象应显式保留原有属性名；如果确需变更协议，应同时修改两侧、说明迁移方式并增加验证。

## 提交前验证

```sh
node --check Sources/DOTMD/Resources/app.js
node --check Sources/DOTMD/Resources/docx-export.js
node --check Sources/DOTMD/Resources/fuzzy-search.js
node scripts/test-fuzzy-search.cjs
node scripts/test-bridge-contract.cjs
./scripts/build-app.sh
```

修改 DOCX 导出器时还须运行 `./scripts/test-docx-fonts.sh` 和 `./scripts/test-docx-flowchart.sh`。修改移动端界面时运行 `./scripts/test-mobile-layout.sh`；修改草稿恢复或文件保存时运行 `./scripts/test-mobile-store.sh`。若开发机安装了 .NET SDK 10，请运行 `./scripts/test-docx-openxml.sh`；它会用 Microsoft Open XML SDK 检查生成文件的结构和元素顺序。涉及窗口、快捷键、文件权限、公式或导出时，请再用运行中的应用手动验证相关操作。导出改动应实际打开生成的 `.docx`，检查正文、公式、表格与图片。不要提交 API Key、私有文稿、测试导出文件、构建产物或未经用户确认的外部请求。
