#!/bin/zsh
set -euo pipefail
# Compatibility entry point for existing shortcuts.
exec "${0:A:h}/启动 md any where.command" "$@"
