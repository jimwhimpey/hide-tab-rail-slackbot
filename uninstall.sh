#!/bin/zsh
# Removes the launchd agent. Slack keeps running; restart it normally to drop
# the debug port.
set -uo pipefail

LABEL="hide-tab-rail-slackbot"
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
echo "Removed $LABEL. Quit and reopen Slack to close the debug port."
