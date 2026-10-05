#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
installed_app="/Applications/DOT MD.app"
app_path="$project_dir/dist/DOT MD.app"

if [[ -d "$installed_app" ]] && \
   [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_app/Contents/Info.plist" 2>/dev/null)" == "app.dotmd.editor" ]]; then
  open "$installed_app"
  exit 0
fi

if [[ ! -d "$app_path" ]]; then
  "$project_dir/scripts/build-app.sh"
fi

open "$app_path"
