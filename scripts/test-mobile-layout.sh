#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
test_dir="$(mktemp -d /private/tmp/md-any-where-mobile-layout.XXXXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
module_cache="${TMPDIR:-/private/tmp}/md-any-where-mobile-layout-module-cache"

cp -R "$project_dir/Sources/MDAnyWhere/Resources" "$test_dir/Editor"
python3 "$project_dir/scripts/bundle-editor-localizations.py" "$test_dir/Editor"
cp "$project_dir/tests/fixtures/mobile-demo.md" "$test_dir/Editor/mobile-demo.md"
python3 - "$test_dir/Editor/index.html" <<'PY'
from pathlib import Path
import sys
page = Path(sys.argv[1])
html = page.read_text()
html = html.replace('</head>', '<link rel="stylesheet" href="ipad.css">\n</head>')
html = html.replace('</body>', '<script src="ipad.js"></script>\n</body>')
page.write_text(html)
PY

CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" \
  xcrun swiftc -swift-version 5 "$project_dir/scripts/test-mobile-layout.swift" \
  -o "$test_dir/mobile-layout-test" -framework AppKit -framework WebKit
"$test_dir/mobile-layout-test" "$test_dir/Editor"
