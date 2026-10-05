#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
test_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/dotmd-native-localization.XXXXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
app_path="$test_dir/NativeLocalizationTests.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources/Editor/locales"
python3 - "$project_dir" "$app_path" <<'PY'
from pathlib import Path
import json, plistlib, sys
project, app = map(Path, sys.argv[1:])
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'app.dotmd.localization-tests', 'CFBundleExecutable': 'test-localization',
    'CFBundleName': 'NativeLocalizationTests', 'CFBundlePackageType': 'APPL', 'CFBundleDevelopmentRegion': 'en'}))
for locale in ('en', 'zh-Hans'):
    values = json.loads((project / f'Sources/DOTMD/Resources/locales/{locale}.json').read_text())
    # Exercise the compiled fallback even when neither runtime catalog has a key.
    values.pop('native.error.unknown', None)
    (app / f'Contents/Resources/Editor/locales/{locale}.json').write_text(json.dumps(values, ensure_ascii=False))
PY
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path "$test_dir/module-cache" \
  "$project_dir/Sources/DOTMDLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/DOTMDLocalization/EnglishFallback.swift" \
  "$project_dir/scripts/test-native-localization.swift" \
  -o "$app_path/Contents/MacOS/test-localization"
"$app_path/Contents/MacOS/test-localization" -dotmd.interfaceLanguage en-US --expect=en-US
"$app_path/Contents/MacOS/test-localization" -dotmd.interfaceLanguage zh-Hans --expect=zh-Hans
python3 "$project_dir/scripts/prepare-localizations.py" "$app_path/Contents/Resources"
python3 - "$project_dir" "$app_path" <<'PY'
from pathlib import Path
import json, plistlib, re, sys
project, app = map(Path, sys.argv[1:])
locales = json.loads((project / 'Support/Localization/locales.json').read_text())
native = json.loads((project / 'Support/Localization/native-en.json').read_text())
english = json.loads((project / 'Sources/DOTMD/Resources/locales/en.json').read_text())
assert set(native).issubset(english), 'Native catalog keys missing from shared editor English catalog'
for key, value in native.items():
    assert value == english[key], f'Native English fallback differs from shared catalog: {key}'
for source in (project / 'Sources').rglob('*.swift'):
    if 'DOTMDLocalization' in source.parts: continue
    keys = re.findall(r'L\("(native\.[^"]+)"', source.read_text())
    assert set(keys).issubset(native), f'Missing native keys in {source}'
for locale in ['en', *locales]:
    info = plistlib.loads((app / f'Contents/Resources/{locale}.lproj/InfoPlist.strings').read_bytes())
    assert info['CFBundleDisplayName'] == 'md any where'
    assert info['Markdown Document']
assert plistlib.loads((app / 'Contents/Resources/zh-Hans.lproj/InfoPlist.strings').read_bytes())['Markdown Document'] == 'Markdown 文稿'
print(f'Native localization packaging passed: {len(locales)} store locales, all native keys and InfoPlist.strings verified.')
PY
