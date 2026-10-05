#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
archive_mode="${1:-archive}"

usage() {
  cat <<'USAGE'
用法：./scripts/archive-ios.sh [archive|export|all]

archive  构建 Release .xcarchive（默认）。
export   将已有 .xcarchive 导出为本地 App Store .ipa。
all      依次归档并导出本地 .ipa。

必填环境变量：
  DOT_MD_TEAM_ID             Apple Developer 团队 ID（10 位字母或数字）
export 模式还需：
  DOT_MD_ARCHIVE_PATH        已有 .xcarchive 的绝对路径
可选环境变量：
  DOT_MD_ARCHIVE_PATH        archive/all 的新归档路径；默认 .build/ios/app-store/日期时间/DOT MD.xcarchive
  DOT_MD_MARKETING_VERSION   发布版本，如 1.0.0
  DOT_MD_BUILD_NUMBER        构建版本，如 1（每次上传前须增加）

仅使用自动签名并将产物保存在本机，不上传、不提交审核。
Xcode 必须登录有 App Store 分发权限的 Apple Developer 团队；自动签名可能访问 Apple 以获取证书和描述文件。
USAGE
}

if [[ "$archive_mode" == "--help" || "$archive_mode" == "-h" ]]; then
  usage
  exit 0
fi
if (( $# > 1 )) || [[ "$archive_mode" != "archive" && "$archive_mode" != "export" && "$archive_mode" != "all" ]]; then
  usage >&2
  exit 2
fi
if [[ -z "${DOT_MD_TEAM_ID:-}" || ! "$DOT_MD_TEAM_ID" =~ '^[A-Za-z0-9]{10}$' ]]; then
  print -u2 -- "请通过 DOT_MD_TEAM_ID 提供 10 位 Apple Developer 团队 ID。"
  exit 2
fi
if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  print -u2 -- "需要完整 Xcode 和 iOS SDK；可用 DEVELOPER_DIR 指定 Xcode。"
  exit 1
fi

version_arguments=()
if [[ -n "${DOT_MD_MARKETING_VERSION:-}" ]]; then
  if [[ ! "$DOT_MD_MARKETING_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 -- "DOT_MD_MARKETING_VERSION 应为三段数字，如 1.0.0。"
    exit 2
  fi
  version_arguments+=("MARKETING_VERSION=$DOT_MD_MARKETING_VERSION")
fi
if [[ -n "${DOT_MD_BUILD_NUMBER:-}" ]]; then
  if [[ ! "$DOT_MD_BUILD_NUMBER" =~ '^[0-9]+(\.[0-9]+){0,2}$' ]]; then
    print -u2 -- "DOT_MD_BUILD_NUMBER 应为一至三段数字。"
    exit 2
  fi
  version_arguments+=("CURRENT_PROJECT_VERSION=$DOT_MD_BUILD_NUMBER")
fi

if [[ "$archive_mode" == "export" && -z "${DOT_MD_ARCHIVE_PATH:-}" ]]; then
  print -u2 -- "export 模式必须指定 DOT_MD_ARCHIVE_PATH，不会猜测要导出的归档。"
  exit 2
fi
archive_path="${DOT_MD_ARCHIVE_PATH:-$project_dir/.build/ios/app-store/$(date +%Y%m%d-%H%M%S)/DOT MD.xcarchive}"
archive_path="${archive_path:A}"
archive_directory="${archive_path:h}"

if [[ "$archive_mode" != "export" ]]; then
  if [[ -e "$archive_path" ]]; then
    print -u2 -- "归档已存在，不会覆盖：$archive_path"
    exit 2
  fi
  icon_path="$project_dir/Support/iPad/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
  icon_alpha="$(/usr/bin/sips -g hasAlpha "$icon_path" | /usr/bin/awk '/hasAlpha:/ {print $2}')"
  if [[ "$icon_alpha" != "no" ]]; then
    print -u2 -- "App Store 图标不能含 Alpha 通道，请先将 AppIcon.png 编码为不透明 RGB PNG。"
    exit 1
  fi
  mkdir -p "$archive_directory"
  xcrun xcodebuild \
    -project "$project_dir/DOTMD-iPad.xcodeproj" \
    -scheme DOTMD-iPad -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$archive_directory/DerivedData" \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic "DEVELOPMENT_TEAM=$DOT_MD_TEAM_ID" \
    "${version_arguments[@]}" archive 2>&1 | tee "$archive_directory/archive.log"
fi

app_path="$archive_path/Products/Applications/DOT MD.app"
if [[ ! -f "$app_path/Info.plist" || ! -f "$app_path/PrivacyInfo.xcprivacy" ]]; then
  print -u2 -- "归档中缺少应用或隐私清单：$archive_path"
  exit 1
fi
/usr/bin/python3 - "$app_path/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as file:
    info = plistlib.load(file)
if info.get("CFBundleIdentifier") != "app.dotmd.ipad":
    raise SystemExit("归档 Bundle ID 必须是 app.dotmd.ipad")
if set(info.get("UIDeviceFamily", [])) != {1, 2}:
    raise SystemExit("归档必须同时支持 iPhone 和 iPad")
PY
/usr/bin/codesign --verify --strict "$app_path"
print -r -- "本地 Release 归档：$archive_path"

if [[ "$archive_mode" == "export" || "$archive_mode" == "all" ]]; then
  export_directory="${archive_path:r}-export"
  if [[ -e "$export_directory" ]]; then
    print -u2 -- "导出目录已存在，不会覆盖：$export_directory"
    exit 2
  fi
  export_options="$archive_directory/ExportOptions.generated.plist"
  /usr/bin/python3 - "$project_dir/Support/iPad/ExportOptions-AppStore.plist" "$export_options" "$DOT_MD_TEAM_ID" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as file:
    options = plistlib.load(file)
# Keep export local even if the reusable template is later changed.
options.update(teamID=sys.argv[3], destination="export", method="app-store-connect", signingStyle="automatic")
with open(sys.argv[2], "wb") as file:
    plistlib.dump(options, file, sort_keys=False)
PY
  xcrun xcodebuild -exportArchive -archivePath "$archive_path" \
    -exportPath "$export_directory" -exportOptionsPlist "$export_options" \
    -allowProvisioningUpdates 2>&1 | tee "$archive_directory/export.log"
  print -r -- "本地 App Store 导出：$export_directory"
fi
