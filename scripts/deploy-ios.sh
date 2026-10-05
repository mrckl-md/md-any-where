#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"

usage() {
  cat <<'USAGE'
用法：MD_ANY_WHERE_TEAM_ID=你的团队ID MD_ANY_WHERE_DEVICE_UDID=你的设备UDID ./scripts/deploy-ios.sh

构建、自动签名、安装并启动指定 iPhone 或 iPad 上的 md any where。
必须显式指定 iPhone 或 iPad UDID；不会自动选择其他设备。
首次部署前请连接并解锁设备、信任 Mac，并在 设备设置中开启开发者模式。
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if (( $# > 0 )) || [[ -z "${MD_ANY_WHERE_TEAM_ID:-}" || -z "${MD_ANY_WHERE_DEVICE_UDID:-}" ]]; then
  usage >&2
  exit 2
fi
if ! xcrun --find devicectl >/dev/null 2>&1; then
  print -u2 -- "当前 Xcode 没有 devicectl；请使用带 iOS SDK 和 devicectl 的完整 Xcode。"
  exit 1
fi

"$project_dir/scripts/build-ios.sh" device

app_path="$project_dir/.build/ios/device/Build/Products/Debug-iphoneos/md any where.app"
log_directory="$project_dir/.build/ios/logs"

report_device_failure() {
  local log_path="$1"
  if /usr/bin/grep -Eqi 'developer.?mode|开发者模式' "$log_path"; then
    print -u2 -- "设备开发者模式尚未开启或未完成确认。请在设备的“设置 → 隐私与安全性 → 开发者模式”中开启，按提示重启并确认，然后重新运行此脚本。"
  else
    print -u2 -- "请根据日志检查：设备已连接并解锁、已信任此 Mac，且开发者模式已开启；签名信任问题可在“设置 → 通用 → VPN 与设备管理”中处理。"
  fi
  print -u2 -- "设备操作失败，日志：$log_path"
}

if ! xcrun devicectl device install app --device "$MD_ANY_WHERE_DEVICE_UDID" "$app_path" \
  2>&1 | tee "$log_directory/install.log"; then
  report_device_failure "$log_directory/install.log"
  exit 1
fi
if ! xcrun devicectl device process launch --device "$MD_ANY_WHERE_DEVICE_UDID" app.mdanywhere.ios \
  2>&1 | tee "$log_directory/launch.log"; then
  report_device_failure "$log_directory/launch.log"
  exit 1
fi
print -r -- "md any where 已安装并启动于指定 iPhone 或 iPad：$MD_ANY_WHERE_DEVICE_UDID"
