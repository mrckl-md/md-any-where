#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
sdk_path="${MD_ANY_WHERE_SDK_PATH:-$(test -d "$compatibility_sdk" && print -r -- "$compatibility_sdk" || xcrun --sdk macosx --show-sdk-path)}"
temporary_dir="$(mktemp -d /private/tmp/md-any-where-openxml-test.XXXXXXXX)"
trap 'rm -rf "$temporary_dir"' EXIT

if ! command -v dotnet >/dev/null; then
  print -u2 -- "The Open XML schema test requires .NET SDK 10 or newer."
  exit 2
fi

CLANG_MODULE_CACHE_PATH="$temporary_dir/module-cache" \
SWIFT_MODULECACHE_PATH="$temporary_dir/module-cache" \
swiftc -sdk "$sdk_path" \
  "$project_dir/Sources/MDAnyWhereLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/MDAnyWhereLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/MDAnyWhere/DocxExporter.swift" \
  "$project_dir/scripts/test-docx-fonts.swift" \
  -o "$temporary_dir/docx-fixture"
"$temporary_dir/docx-fixture" "$temporary_dir/fixture.docx"
dotnet run --project "$project_dir/tests/OpenXmlSchemaValidator/OpenXmlSchemaValidator.csproj" -- "$temporary_dir/fixture.docx"
