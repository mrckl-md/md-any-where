# Third-party notices

md any where's original code is licensed under the [MIT License](LICENSE). Bundled third-party code keeps its own copyright notices and license terms; the root license does not replace them.

## Bundled runtime components

Full license texts are already present in `Sources/MDAnyWhere/Resources/Licenses/`. Both packagers copy that directory into the application: `Contents/Resources/Editor/Licenses/` on macOS and `Editor/Licenses/` on iOS/iPadOS. Preserve these files when distributing applications or source archives.

- **CodeMirror 5.65.21** — MIT; Marijn Haverbeke and other contributors. Editor, Markdown/XML modes and bundled addons. [Upstream](https://github.com/codemirror/codemirror5), [license](Sources/MDAnyWhere/Resources/Licenses/CodeMirror.txt).
- **markdown-it** — MIT; Vitaly Puzrin, Alex Kocharin and other contributors. The bundled browser file does not identify its package version in a readable banner. [Upstream](https://github.com/markdown-it/markdown-it), [license](Sources/MDAnyWhere/Resources/Licenses/markdown-it.txt).
- **markdown-it-footnote 4.0.0** — MIT; Vitaly Puzrin, Alex Kocharin and other contributors. [Upstream](https://github.com/markdown-it/markdown-it-footnote), [license](Sources/MDAnyWhere/Resources/Licenses/markdown-it-footnote.txt).
- **markdown-it-task-lists 2.1.0** — ISC; Revin Guillen. [Upstream](https://github.com/revin/markdown-it-task-lists), [license](Sources/MDAnyWhere/Resources/Licenses/markdown-it-task-lists.txt).
- **markdown-it-texmath** — MIT; Stefan Goessner. The bundled source retains its original header; its exact package version is not recorded locally. [Upstream](https://github.com/goessner/markdown-it-texmath), [license](Sources/MDAnyWhere/Resources/Licenses/markdown-it-texmath.txt).
- **KaTeX 0.18.7** — MIT; Khan Academy and other contributors. Includes browser JavaScript, CSS and KaTeX fonts. [Upstream](https://github.com/KaTeX/KaTeX), [license](Sources/MDAnyWhere/Resources/Licenses/KaTeX.txt).
- **highlight.js 11.12.0** — BSD 3-Clause; Ivan Sagalaev and other contributors. Includes browser code and bundled light/dark styles. [Upstream](https://github.com/highlightjs/highlight.js), [license](Sources/MDAnyWhere/Resources/Licenses/highlight.js.txt).

Versions above come from each bundled file's own version string or banner. [Third-Party-Inventory.json](Docs/Third-Party-Inventory.json) records principal file and license hashes for this source snapshot; it is not a complete transitive SBOM or a security certification. No vendor payload or retained license text was changed for this release preparation.

md any where's `mermaid-flowchart.js` is a project-owned parser/renderer for a limited Mermaid-style flowchart syntax, not the Mermaid library. DOCX font settings refer to fonts on the recipient's device; md any where does not bundle Microsoft fonts such as Times New Roman or Cambria Math.

## Development-only dependencies

The optional test project `tests/OpenXmlSchemaValidator/OpenXmlSchemaValidator.csproj` references Microsoft `DocumentFormat.OpenXml` 3.5.1. Its NuGet dependencies and .NET runtime are test tooling and are not included in the application bundles. Exclude generated `bin/` and `obj/` from source releases. If distributing a compiled test tool, retain its packages' licenses too. [Open XML SDK upstream](https://github.com/dotnet/Open-XML-SDK).

## Distribution checks

Retain all seven license texts and source copyright notices, plus this file and the root `LICENSE`. Recheck attribution when replacing vendor code, fonts or styles. These licenses do not grant rights to a provider's trademarks, API service, or user-supplied proprietary content.
