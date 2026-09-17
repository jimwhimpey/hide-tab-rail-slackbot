#!/bin/zsh
# Installs the launchd agent so slack-css.sh runs at login and stays running.
set -euo pipefail

DIR="${0:A:h}"
LABEL="hide-tab-rail-slackbot"
SRC="$DIR/$LABEL.plist"
DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

NODE_BIN="$(command -v node || true)"
[[ -n "$NODE_BIN" ]] || { echo "node not found in PATH (Node 22+ required)"; exit 1; }
MAJOR="$("$NODE_BIN" -p 'process.versions.node.split(".")[0]')"
(( MAJOR >= 22 )) || { echo "Node 22+ required, found $("$NODE_BIN" -v)"; exit 1; }

mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s#__DIR__#$DIR#g" -e "s#__NODE_DIR__#${NODE_BIN:h}#g" "$SRC" > "$DEST"
plutil -lint "$DEST" >/dev/null

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$DEST"

echo "Installed: $DEST"
echo "Logs:      tail -f /tmp/$LABEL.log"
