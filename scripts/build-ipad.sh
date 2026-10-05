#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_mode="${1:-simulator}"

usage() {
  cat <<'USAGE'
用法：./scripts/build-ipad.sh [simulator|device]

simulator  构建未签名的 iPad 模拟器应用（默认）。
device     为指定 iPad 构建并自动签名，必须设置：
           MD_ANY_WHERE_TEAM_ID       Xcode 中的 Apple Developer Team ID
           MD_ANY_WHERE_IPAD_UDID     目标 iPad 的 UDID

产物与构建日志位于 .build/ipad/；本脚本不安装应用。
USAGE
}

if [[ "$build_mode" == "--help" || "$build_mode" == "-h" ]]; then
  usage
  exit 0
fi
if (( $# > 1 )) || [[ "$build_mode" != "simulator" && "$build_mode" != "device" ]]; then
  usage >&2
  exit 2
fi

build_root="$project_dir/.build/ipad"
derived_data="$build_root/$build_mode"
sdk="iphonesimulator"
destination="generic/platform=iOS Simulator"
signing_arguments=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
build_actions=(build)

if [[ "$build_mode" == "device" ]]; then
  if [[ -z "${MD_ANY_WHERE_TEAM_ID:-}" || -z "${MD_ANY_WHERE_IPAD_UDID:-}" ]]; then
    print -u2 -- "真机构建需要 MD_ANY_WHERE_TEAM_ID 和 MD_ANY_WHERE_IPAD_UDID；不会自动选择设备。"
    print -u2 -- "在 Xcode → Settings → Apple Accounts 查看团队；在 Xcode → Open Developer Tool → Device Hub 复制目标 iPad 的 Identifier（旧版在 Window → Devices and Simulators）。"
    exit 2
  fi
  if [[ ! "$MD_ANY_WHERE_TEAM_ID" =~ '^[A-Za-z0-9]{10}$' ]]; then
    print -u2 -- "MD_ANY_WHERE_TEAM_ID 应为 10 位字母或数字。"
    exit 2
  fi
  if [[ ! "$MD_ANY_WHERE_IPAD_UDID" =~ '^([A-Fa-f0-9]{8}-[A-Fa-f0-9]{16}|[A-Fa-f0-9]{40})$' ]]; then
    print -u2 -- "MD_ANY_WHERE_IPAD_UDID 应为真实设备的 UDID，不使用设备名称或 CoreDevice UUID。"
    exit 2
  fi
  sdk="iphoneos"
  destination="platform=iOS,id=$MD_ANY_WHERE_IPAD_UDID"
  signing_arguments=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration
    CODE_SIGN_STYLE=Automatic "DEVELOPMENT_TEAM=$MD_ANY_WHERE_TEAM_ID")
  # Provisioning updates and the packaged web resources must receive a fresh seal.
  # Xcode can otherwise reuse an old signature during an incremental device build.
  build_actions=(clean build)
fi

if ! xcrun --sdk "$sdk" --show-sdk-path >/dev/null 2>&1; then
  print -u2 -- "需要安装并选中完整 Xcode 及 $sdk SDK；仅 Command Line Tools 无法构建 iPad 应用。"
  print -u2 -- "可通过 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer 指定 Xcode。"
  exit 1
fi

mkdir -p "$build_root/logs"
log_path="$build_root/logs/build-$build_mode.log"
if ! xcrun xcodebuild \
  -project "$project_dir/MDAnyWhere-iOS.xcodeproj" \
  -scheme MDAnyWhere-iOS -configuration Debug \
  -sdk "$sdk" -destination "$destination" \
  -derivedDataPath "$derived_data" \
  "${signing_arguments[@]}" "${build_actions[@]}" 2>&1 | tee "$log_path"; then
  print -u2 -- "iPad 构建失败，日志：$log_path"
  if /usr/bin/grep -Eqi 'developer.?mode|开发者模式' "$log_path"; then
    print -u2 -- "请在 iPad 的“设置 → 隐私与安全性 → 开发者模式”中开启，按提示重启并确认，然后重新运行。若找不到入口，先在 Xcode 的 Device Hub 中选中此 iPad，再重新打开 iPad 设置。"
  fi
  if [[ "$build_mode" == "device" ]]; then
    print -u2 -- "若签名失败，请先在 Xcode 登录 Apple Account，确认团队可用于开发签名，并让 iPad 解锁、信任这台 Mac。"
  fi
  exit 1
fi

app_path="$derived_data/Build/Products/Debug-$sdk/md any where.app"
for resource in Info.plist Editor/index.html Editor/app.js Editor/ipad.js Editor/ipad.css; do
  if [[ ! -f "$app_path/$resource" ]]; then
    print -u2 -- "构建产物缺少 $resource：$app_path"
    exit 1
  fi
done
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
if [[ "$bundle_id" != "app.mdanywhere.mobile" ]]; then
  print -u2 -- "构建产物的 Bundle ID 不匹配：$bundle_id"
  exit 1
fi
if [[ "$build_mode" == "device" ]]; then
  codesign --verify --strict "$app_path"
fi
print -r -- "iPad 应用已构建：$app_path"
