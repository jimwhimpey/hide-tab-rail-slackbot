#!/bin/zsh
# Supervisor: keeps Slack running with the remote-debugging port and runs the
# CSS injector whenever Slack is up. Runs forever under launchd.
#
#   - At login (or when this script starts), it launches Slack with the port.
#   - If you quit Slack, it stays quit. This script just waits.
#   - If you relaunch Slack from the Dock/Spotlight (i.e. without the port),
#     it quits that instance and relaunches it with the port, then injects.
set -uo pipefail

PORT="${SLACK_DEBUG_PORT:-9222}"
DIR="${0:A:h}"
LAUNCH_AT_START="${SLACK_CSS_LAUNCH_AT_START:-1}"

slack_running() { pgrep -xq Slack; }
port_open()     { nc -z 127.0.0.1 "$PORT" 2>/dev/null; }

launch_slack() {
  echo "$(date -Iseconds) launching Slack with debug port $PORT"
  open -a Slack --args --remote-debugging-port="$PORT"
}

restart_slack() {
  echo "$(date -Iseconds) Slack running without debug port; restarting"
  osascript -e 'quit app "Slack"'
  for _ in {1..40}; do slack_running || break; sleep 0.5; done
  slack_running && pkill -x Slack
  sleep 1
  launch_slack
}

[[ "$LAUNCH_AT_START" == 1 ]] && ! slack_running && launch_slack

while true; do
  if slack_running; then
    # Give a fresh launch a moment to open the port before judging it.
    for _ in {1..10}; do port_open && break; sleep 0.5; done
    if port_open; then
      node "$DIR/inject.mjs"     # blocks until Slack quits
    else
      restart_slack
    fi
  fi
  sleep 2
done
