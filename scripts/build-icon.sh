#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
resources_dir="$project_dir/Sources/DOTMD/Resources"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/dot-md-icon.XXXXXXXX")"
iconset_dir="$temporary_dir/DOT-MD.iconset"
trap 'rm -rf "$temporary_dir"' EXIT

swift "$project_dir/scripts/render-icon.swift" \
  "$resources_dir/Brand/DOT-MD-Mark.svg" "$iconset_dir"
iconutil -c icns -o "$resources_dir/AppIcon.icns" "$iconset_dir"
