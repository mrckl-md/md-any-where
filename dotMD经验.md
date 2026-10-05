# md any where 开发经验

当前发布版本：1.0.0。开发源码在本文件夹的 `Sources/`，应用配置在 `Support/`，构建和验证脚本在 `scripts/`。`dist/` 与 `.build/` 是可重新生成的产物，不是源码。

## DOCX 导出的教训

- ZIP 能解压、XML 能解析，不代表 Word 接受整个 DOCX。曾有 31 处 OOXML 元素顺序或属性错误；必须运行 `./scripts/test-docx-openxml.sh`，再用 Microsoft Word 打开复杂公式、表格和列表的样本文档。
- `word/settings.xml` 要声明现代 Word 兼容模式；缺失时，Word 可能以旧版“兼容模式”打开。
- 中文学术论文预设的公式英文字母与符号字体为 Times New Roman；公式中的汉字仍用宋体。Times New Roman 不包含完整数学字形，Word/WPS 可能对部分运算符自动替换字体。
- 保留原生 Word 公式结构，不能为了表面一致而悄悄将可编辑公式替换成图片。

## 发布前核对

1. 确认四个 `Support/*Info.plist` 的短版本号和构建版本号一致；检查隐私界面和 MCP 服务信息中的版本号。
2. 运行项目测试、`./scripts/test-docx-fonts.sh`、`./scripts/test-docx-openxml.sh`，再运行 `./scripts/build-app.sh`。
3. 核对生成应用的签名，实际打开导出的 DOCX，检查中文、公式、表格与分页；验证 DMG 校验和。
4. 更换已安装应用前，先确认编辑器未运行，并保存可恢复的旧版备份。不要覆盖用户的文稿。

## 当前仍需关注

- Mermaid 流程图在编辑器中可以渲染，但导出到 Word 的示例仍可能保留为文本；这与 DOCX 能否打开是两个问题。
- 本机 Word 尚未激活编辑许可，已验证打开与显示，未验证在 Word 中保存；Windows Word 仍需实机回归。
- Agent 请求只能在用户主动触发并选择服务后发送。不要把私有文稿、API Key 或测试导出文件提交到公开仓库。
