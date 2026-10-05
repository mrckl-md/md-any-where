#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_mode="${1:-simulator}"

usage() {
  cat <<'USAGE'
用法：./scripts/build-ios.sh [simulator|device]

simulator  构建未签名的 iOS 模拟器应用（默认）。
device     为指定 iPhone 或 iOS 构建并自动签名，必须设置：
           DOT_MD_TEAM_ID       Xcode 中的 Apple Developer Team ID
           DOT_MD_DEVICE_UDID     目标 iPhone 或 iPad 的 UDID

产物与构建日志位于 .build/ios/；本脚本不安装应用。
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

build_root="$project_dir/.build/ios"
derived_data="$build_root/$build_mode"
sdk="iphonesimulator"
destination="generic/platform=iOS Simulator"
signing_arguments=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)
build_actions=(build)

if [[ "$build_mode" == "device" ]]; then
  if [[ -z "${DOT_MD_TEAM_ID:-}" || -z "${DOT_MD_DEVICE_UDID:-}" ]]; then
    print -u2 -- "真机构建需要 DOT_MD_TEAM_ID 和 DOT_MD_DEVICE_UDID；不会自动选择设备。"
    print -u2 -- "在 Xcode → Settings → Apple Accounts 查看团队；在 Xcode → Open Developer Tool → Device Hub 复制目标 iPhone 或 iPad 的 Identifier（旧版在 Window → Devices and Simulators）。"
    exit 2
  fi
  if [[ ! "$DOT_MD_TEAM_ID" =~ '^[A-Za-z0-9]{10}$' ]]; then
    print -u2 -- "DOT_MD_TEAM_ID 应为 10 位字母或数字。"
    exit 2
  fi
  if [[ ! "$DOT_MD_DEVICE_UDID" =~ '^([A-Fa-f0-9]{8}-[A-Fa-f0-9]{16}|[A-Fa-f0-9]{40})$' ]]; then
    print -u2 -- "DOT_MD_DEVICE_UDID 应为真实设备的 UDID，不使用设备名称或 CoreDevice UUID。"
    exit 2
  fi
  sdk="iphoneos"
  destination="platform=iOS,id=$DOT_MD_DEVICE_UDID"
  signing_arguments=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration
    CODE_SIGN_STYLE=Automatic "DEVELOPMENT_TEAM=$DOT_MD_TEAM_ID")
  # Provisioning updates and the packaged web resources must receive a fresh seal.
  # Xcode can otherwise reuse an old signature during an incremental device build.
  build_actions=(clean build)
fi

if ! xcrun --sdk "$sdk" --show-sdk-path >/dev/null 2>&1; then
  print -u2 -- "需要安装并选中完整 Xcode 及 $sdk SDK；仅 Command Line Tools 无法构建 iOS 应用。"
  print -u2 -- "可通过 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer 指定 Xcode。"
  exit 1
fi

mkdir -p "$build_root/logs"
log_path="$build_root/logs/build-$build_mode.log"
if ! xcrun xcodebuild \
  -project "$project_dir/DOTMD-iPad.xcodeproj" \
  -scheme DOTMD-iPad -configuration Debug \
  -sdk "$sdk" -destination "$destination" \
  -derivedDataPath "$derived_data" \
  "${signing_arguments[@]}" "${build_actions[@]}" 2>&1 | tee "$log_path"; then
  print -u2 -- "iOS 构建失败，日志：$log_path"
  if /usr/bin/grep -Eqi 'developer.?mode|开发者模式' "$log_path"; then
    print -u2 -- "请在设备的“设置 → 隐私与安全性 → 开发者模式”中开启，按提示重启并确认，然后重新运行。若找不到入口，先在 Xcode 的 Device Hub 中选中此设备，再重新打开 设备设置。"
  fi
  if [[ "$build_mode" == "device" ]]; then
    print -u2 -- "若签名失败，请先在 Xcode 登录 Apple Account，确认团队可用于开发签名，并让设备解锁、信任这台 Mac。"
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
if [[ "$bundle_id" != "app.dotmd.ipad" ]]; then
  print -u2 -- "构建产物的 Bundle ID 不匹配：$bundle_id"
  exit 1
fi
if [[ "$build_mode" == "device" ]]; then
  codesign --verify --strict "$app_path"
fi
print -r -- "iOS 应用已构建：$app_path"
