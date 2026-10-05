#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
test_dir="$(mktemp -d /private/tmp/md-any-where-editor-safety.XXXXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
module_cache="${TMPDIR:-/private/tmp}/md-any-where-editor-safety-module-cache"

cp -R "$project_dir/Sources/MDAnyWhere/Resources" "$test_dir/Editor"
python3 "$project_dir/scripts/bundle-editor-localizations.py" "$test_dir/Editor"
cp "$project_dir/tests/editor-safety.js" "$test_dir/Editor/editor-safety.js"
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" \
  xcrun swiftc -swift-version 5 "$project_dir/scripts/test-editor-safety.swift" \
  -o "$test_dir/editor-safety-test" -framework AppKit -framework WebKit
"$test_dir/editor-safety-test" "$test_dir/Editor"
