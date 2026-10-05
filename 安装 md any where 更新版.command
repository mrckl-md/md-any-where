#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
installed_app="$project_dir/dist/md any where.app"
legacy_installed_app="$project_dir/dist/DOT MD.app"
update_app="$project_dir/dist/md any where 更新版.app"

# Accept a previously named update package without changing identifiers or data.
if [[ ! -d "$update_app" && -d "$project_dir/dist/DOT MD 更新版.app" ]]; then
  update_app="$project_dir/dist/DOT MD 更新版.app"
fi
if [[ ! -d "$update_app" ]]; then
  print -u2 -- "找不到更新版：$update_app"
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$update_app/Contents/Info.plist" 2>/dev/null)" != "app.dotmd.editor" ]]; then
  print -u2 -- "更新包的应用标识不匹配，未执行安装。"
  exit 1
fi

for app in "$installed_app" "$legacy_installed_app" "$update_app" "/Applications/md any where.app" "/Applications/DOT MD.app"; do
  candidate="$app/Contents/MacOS/DOTMD"
  process_status=0
  /usr/bin/pgrep -f -x "$candidate" >/dev/null || process_status=$?
  case "$process_status" in
    0)
      print -u2 -- "请先在 md any where 中保存文稿并正常退出，再双击此安装脚本。不会强制退出应用。"
      exit 1 ;;
    1) ;;
    *)
      print -u2 -- "无法确认 md any where 是否仍在运行，为保护文稿，拒绝安装。"
      exit 1 ;;
  esac
done

/usr/bin/codesign --verify --deep --strict "$update_app"

replacement_app="$installed_app"
if [[ ! -e "$replacement_app" && -e "$legacy_installed_app" ]]; then
  replacement_app="$legacy_installed_app"
fi
if [[ -e "$replacement_app" ]]; then
  backup_app="${replacement_app%.app}-before-$(date +%Y%m%d-%H%M%S).app"
  if [[ -e "$backup_app" ]]; then
    print -u2 -- "备份名称已存在，请稍后重试：$backup_app"
    exit 1
  fi
  /bin/mv "$replacement_app" "$backup_app"
  print -r -- "旧版已备份：$backup_app"
fi

if ! /bin/mv "$update_app" "$installed_app"; then
  if [[ -n "${backup_app:-}" && -d "$backup_app" && ! -e "$replacement_app" ]]; then
    /bin/mv "$backup_app" "$replacement_app"
  fi
  print -u2 -- "安装失败；旧版已尽量恢复。"
  exit 1
fi

print -r -- "已安装：$installed_app"
if ! /usr/bin/pluginkit -a "$installed_app/Contents/PlugIns/DOTMDQuickLook.appex"; then
  print -u2 -- "应用已安装，但 Quick Look 扩展登记失败；可稍后重启 Finder 再试。"
fi
if ! /usr/bin/qlmanage -r >/dev/null; then
  print -u2 -- "应用已安装，但 Quick Look 缓存未刷新；可稍后重启 Finder 再试。"
fi
/usr/bin/open "$installed_app"
