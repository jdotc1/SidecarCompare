#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--debug|--logs|--verify|--acceptance|--launch-built) ;; *) echo "Usage: $0 [--debug|--logs|--verify|--acceptance|--launch-built]" >&2; exit 2;; esac
[[ "$(uname -s)" == Darwin ]] || { echo "The native GUI run loop requires macOS." >&2; exit 2; }
APP="$ROOT/dist/SidecarCompare.app"
# These launch-only modes reuse the last staged build and its verification receipt.
if [[ "$MODE" == --acceptance || "$MODE" == --launch-built ]]; then
    [[ -x "$APP/Contents/MacOS/SidecarCompare" ]] || { echo "Build the debug app first with ./script/build.sh debug." >&2; exit 2; }
    pkill -x SidecarCompare >/dev/null 2>&1 || true
    if [[ "$MODE" == --acceptance ]]; then
        /usr/bin/open -n "$APP" --args --native-acceptance
    else
        /usr/bin/open -n "$APP"
    fi
    exit 0
fi
# Restarting discards the old in-memory session, never its input files.
pkill -x SidecarCompare >/dev/null 2>&1 || true
"$ROOT/script/build.sh" debug
case "$MODE" in
    --debug) lldb -- "$APP/Contents/MacOS/SidecarCompare" ;;
    --logs) /usr/bin/open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "SidecarCompare"' ;;
    --verify) /usr/bin/open -n "$APP"; sleep 2; pgrep -x SidecarCompare >/dev/null; echo "Process exists; GUI acceptance still requires manual checks." ;;
    run) /usr/bin/open -n "$APP" ;;
esac
