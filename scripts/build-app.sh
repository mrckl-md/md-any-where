#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
sdk_path="${MD_ANY_WHERE_SDK_PATH:-$(test -d "$compatibility_sdk" && print -r -- "$compatibility_sdk" || xcrun --sdk macosx --show-sdk-path)}"
module_cache="${TMPDIR:-/tmp}/md-any-where-module-cache"
build_path="${MD_ANY_WHERE_BUILD_PATH:-/private/tmp/mdanywhere-release-build}"
cache_path="${MD_ANY_WHERE_CACHE_PATH:-/private/tmp/mdanywhere-release-cache}"
output_path="${MD_ANY_WHERE_APP_PATH:-$project_dir/dist/md any where.app}"
staging_dir="$(mktemp -d /private/tmp/mdanywhere-package.XXXXXXXX)"
app_path="$staging_dir/md any where.app"
trap 'rm -rf "$staging_dir"' EXIT
quicklook_path="$app_path/Contents/PlugIns/MDAnyWhereQuickLook.appex"
thumbnail_path="$app_path/Contents/PlugIns/MDAnyWhereThumbnail.appex"

cd "$project_dir"
if [[ ! -f "$project_dir/Sources/MDAnyWhere/Resources/AppIcon.icns" ]]; then
  "$project_dir/scripts/build-icon.sh"
fi
SDKROOT="$sdk_path" CLANG_MODULE_CACHE_PATH="$module_cache" SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swift build --disable-sandbox --scratch-path "$build_path" --cache-path "$cache_path" -c release
release_dir="$(SDKROOT="$sdk_path" CLANG_MODULE_CACHE_PATH="$module_cache" SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swift build --disable-sandbox --scratch-path "$build_path" --cache-path "$cache_path" -c release --show-bin-path)"

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$quicklook_path/Contents/MacOS" "$thumbnail_path/Contents/MacOS"
cp "$release_dir/MDAnyWhere" "$app_path/Contents/MacOS/MDAnyWhere"
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swiftc \
  -sdk "$sdk_path" -target "$(uname -m)-apple-macos13.0" -swift-version 5 \
  "$project_dir/Sources/MDAnyWhereLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/MDAnyWhereLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/MDAnyWhereAgent/main.swift" \
  -o "$app_path/Contents/MacOS/md-any-where-agent" \
  -framework AppKit \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
  -Xlinker "$project_dir/Support/MDAnyWhereAgent-Info.plist"
editor_resources="$release_dir/MDAnyWhere_MDAnyWhere.bundle/Resources"
# Xcode 27's SwiftPM build uses the standard macOS bundle layout.
if [[ ! -f "$editor_resources/index.html" ]]; then
  editor_resources="$release_dir/MDAnyWhere_MDAnyWhere.bundle/Contents/Resources/Resources"
fi
if [[ ! -f "$editor_resources/index.html" ]]; then
  print -u2 -- "无法找到编译后的编辑器资源：$release_dir/MDAnyWhere_MDAnyWhere.bundle"
  exit 1
fi
cp -R "$editor_resources" "$app_path/Contents/Resources/Editor"
python3 "$project_dir/scripts/bundle-editor-localizations.py" "$app_path/Contents/Resources/Editor"
cp "$project_dir/Support/Info.plist" "$app_path/Contents/Info.plist"
cp "$project_dir/Support/PrivacyInfo.xcprivacy" "$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$project_dir/Sources/MDAnyWhere/Resources/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
cp "$project_dir/Support/QuickLookPreview-Info.plist" "$quicklook_path/Contents/Info.plist"
cp "$project_dir/Support/QuickLookThumbnail-Info.plist" "$thumbnail_path/Contents/Info.plist"
python3 "$project_dir/scripts/prepare-localizations.py" "$app_path/Contents/Resources" --catalogs "$app_path/Contents/Resources/Editor/locales"
for extension_kind in preview thumbnail; do
  extension_path="$quicklook_path"
  [[ "$extension_kind" == "thumbnail" ]] && extension_path="$thumbnail_path"
  mkdir -p "$extension_path/Contents/Resources/Editor"
  cp -R "$app_path/Contents/Resources/Editor/locales" "$extension_path/Contents/Resources/Editor/locales"
  cp "$project_dir/Support/PrivacyInfo.xcprivacy" "$extension_path/Contents/Resources/PrivacyInfo.xcprivacy"
  python3 "$project_dir/scripts/prepare-localizations.py" "$extension_path/Contents/Resources" --kind "$extension_kind"
done
machine_arch="$(uname -m)"
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swiftc \
  -sdk "$sdk_path" -target "$machine_arch-apple-macos13.0" -module-name MDAnyWhereQuickLook -parse-as-library \
  "$project_dir/Sources/MDAnyWhereQuickLook/PreviewProvider.swift" \
  "$project_dir/Sources/MDAnyWhereLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/MDAnyWhereLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/MDAnyWhereQuickLook/NativeMarkdownPreview.swift" \
  -o "$quicklook_path/Contents/MacOS/MDAnyWhereQuickLook" \
  -framework AppKit -framework QuickLookUI \
  -Xlinker -e -Xlinker _NSExtensionMain
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swiftc \
  -sdk "$sdk_path" -target "$machine_arch-apple-macos13.0" -module-name MDAnyWhereThumbnail -parse-as-library \
  "$project_dir/Sources/MDAnyWhereThumbnail/ThumbnailProvider.swift" \
  -o "$thumbnail_path/Contents/MacOS/MDAnyWhereThumbnail" \
  -framework AppKit -framework QuickLookThumbnailing \
  -Xlinker -e -Xlinker _NSExtensionMain
codesign --force --sign - --identifier app.mdanywhere.editor.agent --entitlements "$project_dir/Support/MDAnyWhereAgent.entitlements" "$app_path/Contents/MacOS/md-any-where-agent"
codesign --force --sign - --entitlements "$project_dir/Support/MDAnyWhereQuickLook.entitlements" "$quicklook_path"
codesign --force --sign - --entitlements "$project_dir/Support/MDAnyWhereQuickLook.entitlements" "$thumbnail_path"
codesign --force --sign - --entitlements "$project_dir/Support/MDAnyWhere.entitlements" "$app_path"
mkdir -p "${output_path:h}"
if [[ -e "$output_path" ]]; then
  backup_path="${output_path%.app}-before-$(date +%Y%m%d-%H%M%S).app"
  mv "$output_path" "$backup_path"
  print -r -- "旧版本已保留：$backup_path" >&2
fi
mv "$app_path" "$output_path"
echo "$output_path"
