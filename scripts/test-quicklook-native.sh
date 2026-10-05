#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
sdk_path="${DOT_MD_SDK_PATH:-$(test -d "$compatibility_sdk" && print -r -- "$compatibility_sdk" || xcrun --sdk macosx --show-sdk-path)}"
module_cache="${TMPDIR:-/private/tmp}/dot-md-quicklook-module-cache"
test_dir="$(mktemp -d /private/tmp/dot-md-quicklook-test.XXXXXXXX)"
trap 'rm -rf "$test_dir"' EXIT

CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" \
  swiftc -sdk "$sdk_path" -target "$(uname -m)-apple-macos13.0" -swift-version 5 \
  "$project_dir/Sources/DOTMDQuickLook/PreviewProvider.swift" \
  "$project_dir/Sources/DOTMDQuickLook/NativeMarkdownPreview.swift" \
  "$project_dir/scripts/test-quicklook-native.swift" \
  -o "$test_dir/quicklook-test" -framework AppKit -framework QuickLookUI

"$test_dir/quicklook-test"
