#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
sdk_path="${DOT_MD_SDK_PATH:-$(test -d "$compatibility_sdk" && print -r -- "$compatibility_sdk" || xcrun --sdk macosx --show-sdk-path)}"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/dot-md-font-test.XXXXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

CLANG_MODULE_CACHE_PATH="$temporary_dir/module-cache" SWIFT_MODULECACHE_PATH="$temporary_dir/module-cache" swiftc -sdk "$sdk_path" "$project_dir/Sources/DOTMDLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/DOTMDLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/DOTMD/DocxExporter.swift" \
  "$project_dir/scripts/test-docx-fonts.swift" -o "$temporary_dir/font-test"
"$temporary_dir/font-test" "$temporary_dir/sample.docx"

unzip -tq "$temporary_dir/sample.docx"
for part in word/styles.xml word/settings.xml word/document.xml word/_rels/document.xml.rels '\[Content_Types\].xml'; do
  unzip -p "$temporary_dir/sample.docx" "$part" | xmllint --noout -
done

unzip -p "$temporary_dir/sample.docx" word/styles.xml | \
  rg -q 'w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="宋体"'
unzip -p "$temporary_dir/sample.docx" word/styles.xml | \
  rg -q 'w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="黑体"'
unzip -p "$temporary_dir/sample.docx" word/settings.xml | \
  rg -q '<m:mathFont m:val="Times New Roman"/>'
unzip -p "$temporary_dir/sample.docx" word/settings.xml | \
  rg -q '<w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>'
unzip -p "$temporary_dir/sample.docx" word/document.xml | \
  rg -q '<m:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="宋体"'
echo "DOCX Chinese/Latin/equation font XML passed."
