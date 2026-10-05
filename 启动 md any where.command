#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
app_path="$project_dir/dist/md any where.app"

# Build the current app if it is missing; old command names delegate here.
for candidate in "/Applications/md any where.app" "$app_path"; do
  if [[ -d "$candidate" ]] && \
     [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$candidate/Contents/Info.plist" 2>/dev/null)" == "app.mdanywhere.editor" ]]; then
    open "$candidate"
    exit 0
  fi
done

"$project_dir/scripts/build-app.sh"
open "$app_path"
