#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
if (( $# > 0 )); then
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print -r -- "用法：./scripts/test-mobile-store.sh"
    print -r -- "在 macOS 上直接编译并测试移动端 DocumentStore；仅使用临时文件，不需要模拟器、设备、签名或网络。"
    print -r -- "需要 Xcode 或 Command Line Tools；受限沙箱须允许系统 NSFileCoordinator 服务。"
    exit 0
  fi
  print -u2 -- "本脚本不接受参数；使用 --help 查看说明。"
  exit 2
fi

sdk_path="${DOT_MD_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/dot-md-mobile-store.XXXXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

xcrun swiftc -swift-version 5 -parse-as-library -sdk "$sdk_path" \
  -module-cache-path "$temporary_dir/module-cache" \
  "$project_dir/Sources/DOTMDLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/DOTMDLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/DOTMDiPad/DocumentStore.swift" \
  "$project_dir/scripts/test-mobile-store.swift" \
  -o "$temporary_dir/mobile-store-tests"
"$temporary_dir/mobile-store-tests" "$temporary_dir"
