#!/bin/sh
# Local screenshot tooling; never bundled in Glintwake.
set -eu
glintwake_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
framepilot_root=${FRAMEPILOT_ROOT:-"$glintwake_root/../FramePilot"}
framepilot_cli=${FRAMEPILOT_CLI:-"$glintwake_root/Build/FramePilot/Tool/debug/framepilot"}
case "${1:-prepare}" in
    prepare|capture) action=${1:-prepare} ;;
    *) echo 'Usage: sh Scripts/framepilot.sh prepare | capture ios|ios-duo|macos' >&2; exit 2 ;;
esac
if [ -z "${FRAMEPILOT_CLI:-}" ]; then
    swift build --package-path "$framepilot_root" --scratch-path "$glintwake_root/Build/FramePilot/Tool" --product framepilot >&2
fi
if [ ! -x "$framepilot_cli" ]; then echo "Missing FramePilot CLI: $framepilot_cli" >&2; exit 1; fi
if [ "$action" = prepare ]; then
    exec python3 "$glintwake_root/Scripts/prepare-framepilot.py" "$framepilot_cli"
fi
case "${2:-}" in
    ios|ios-duo|macos) preset=$2 ;;
    *) echo 'Choose ios, ios-duo or macos.' >&2; exit 2 ;;
esac
configuration="$glintwake_root/Build/FramePilot/$preset.json"
if [ ! -f "$configuration" ]; then echo 'Run sh Scripts/framepilot.sh prepare first.' >&2; exit 1; fi
if [ "$preset" = ios-duo ]; then
    exec "$framepilot_cli" capture "$configuration" --interactive
fi
exec "$framepilot_cli" capture "$configuration"
