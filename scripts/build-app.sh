#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
compatibility_sdk="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
sdk_path="${DOT_MD_SDK_PATH:-$(test -d "$compatibility_sdk" && print -r -- "$compatibility_sdk" || xcrun --sdk macosx --show-sdk-path)}"
module_cache="${TMPDIR:-/tmp}/dot-md-module-cache"
build_path="${DOT_MD_BUILD_PATH:-/private/tmp/dotmd-release-build}"
cache_path="${DOT_MD_CACHE_PATH:-/private/tmp/dotmd-release-cache}"
output_path="${DOT_MD_APP_PATH:-$project_dir/dist/md any where.app}"
staging_dir="$(mktemp -d /private/tmp/dotmd-package.XXXXXXXX)"
app_path="$staging_dir/md any where.app"
trap 'rm -rf "$staging_dir"' EXIT
quicklook_path="$app_path/Contents/PlugIns/DOTMDQuickLook.appex"
thumbnail_path="$app_path/Contents/PlugIns/DOTMDThumbnail.appex"

cd "$project_dir"
if [[ ! -f "$project_dir/Sources/DOTMD/Resources/AppIcon.icns" ]]; then
  "$project_dir/scripts/build-icon.sh"
fi
SDKROOT="$sdk_path" CLANG_MODULE_CACHE_PATH="$module_cache" SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swift build --disable-sandbox --scratch-path "$build_path" --cache-path "$cache_path" -c release
release_dir="$(SDKROOT="$sdk_path" CLANG_MODULE_CACHE_PATH="$module_cache" SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swift build --disable-sandbox --scratch-path "$build_path" --cache-path "$cache_path" -c release --show-bin-path)"

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$quicklook_path/Contents/MacOS" "$thumbnail_path/Contents/MacOS"
cp "$release_dir/DOTMD" "$app_path/Contents/MacOS/DOTMD"
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swiftc \
  -sdk "$sdk_path" -target "$(uname -m)-apple-macos13.0" -swift-version 5 \
  "$project_dir/Sources/DOTMDLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/DOTMDLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/DOTMDAgent/main.swift" \
  -o "$app_path/Contents/MacOS/dotmd-agent" \
  -framework AppKit \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
  -Xlinker "$project_dir/Support/DOTMDAgent-Info.plist"
editor_resources="$release_dir/DOTMD_DOTMD.bundle/Resources"
# Xcode 27's SwiftPM build uses the standard macOS bundle layout.
if [[ ! -f "$editor_resources/index.html" ]]; then
  editor_resources="$release_dir/DOTMD_DOTMD.bundle/Contents/Resources/Resources"
fi
if [[ ! -f "$editor_resources/index.html" ]]; then
  print -u2 -- "无法找到编译后的编辑器资源：$release_dir/DOTMD_DOTMD.bundle"
  exit 1
fi
cp -R "$editor_resources" "$app_path/Contents/Resources/Editor"
python3 "$project_dir/scripts/bundle-editor-localizations.py" "$app_path/Contents/Resources/Editor"
cp "$project_dir/Support/Info.plist" "$app_path/Contents/Info.plist"
cp "$project_dir/Support/PrivacyInfo.xcprivacy" "$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$project_dir/Sources/DOTMD/Resources/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
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
  -sdk "$sdk_path" -target "$machine_arch-apple-macos13.0" -module-name DOTMDQuickLook -parse-as-library \
  "$project_dir/Sources/DOTMDQuickLook/PreviewProvider.swift" \
  "$project_dir/Sources/DOTMDLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/DOTMDLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/DOTMDQuickLook/NativeMarkdownPreview.swift" \
  -o "$quicklook_path/Contents/MacOS/DOTMDQuickLook" \
  -framework AppKit -framework QuickLookUI \
  -Xlinker -e -Xlinker _NSExtensionMain
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" swiftc \
  -sdk "$sdk_path" -target "$machine_arch-apple-macos13.0" -module-name DOTMDThumbnail -parse-as-library \
  "$project_dir/Sources/DOTMDThumbnail/ThumbnailProvider.swift" \
  -o "$thumbnail_path/Contents/MacOS/DOTMDThumbnail" \
  -framework AppKit -framework QuickLookThumbnailing \
  -Xlinker -e -Xlinker _NSExtensionMain
codesign --force --sign - --identifier app.dotmd.editor.agent --entitlements "$project_dir/Support/DOTMDAgent.entitlements" "$app_path/Contents/MacOS/dotmd-agent"
codesign --force --sign - --entitlements "$project_dir/Support/DOTMDQuickLook.entitlements" "$quicklook_path"
codesign --force --sign - --entitlements "$project_dir/Support/DOTMDQuickLook.entitlements" "$thumbnail_path"
codesign --force --sign - --entitlements "$project_dir/Support/DOTMD.entitlements" "$app_path"
mkdir -p "${output_path:h}"
if [[ -e "$output_path" ]]; then
  backup_path="${output_path%.app}-before-$(date +%Y%m%d-%H%M%S).app"
  mv "$output_path" "$backup_path"
  print -r -- "旧版本已保留：$backup_path" >&2
fi
mv "$app_path" "$output_path"
echo "$output_path"
