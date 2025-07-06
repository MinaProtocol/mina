#!/usr/bin/env bash

CHECK_INTERVAL=10s
SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN:-""}  # Slack bot token
SLACK_BOT_CHANNEL=${SLACK_BOT_CHANNEL:-"#n8n-bot-hub"}  # Slack channel to post alerts
MAX_FREEZE_SEC=$((60 * 60)) #

# Ensure inotifywait is available
if ! command -v inotifywait &>/dev/null; then
  echo "Error: inotifywait is not installed."
  exit 1
fi

# Ensure the file exists
if [ ! -f "$FILE_TO_WATCH" ]; then
  echo "File $FILE_TO_WATCH does not exist."
  exit 1
fi

LAST_CHANGE_TIME=$(mktemp)
date +%s > $LAST_CHANGE_TIME
echo $LAST_CHANGE_TIME

echo "Watching $FILE_TO_WATCH for changes..."

(
while [ -f "$LAST_CHANGE_TIME" ]; do
  inotifywait -e modify "$FILE_TO_WATCH" >/dev/null 2>&1
  echo "File $FILE_TO_WATCH changed at $(date)"
  echo "$(date +%s)" > "$LAST_CHANGE_TIME"
done
) &
NOTIFY_PID=$!

cleanup() {
  kill -KILL "$NOTIFY_PID"
}

trap cleanup EXIT

while true; do
  sleep "$CHECK_INTERVAL"
  now=$(date +%s)
  last=$(cat "$LAST_CHANGE_TIME")
  elapsed=$((now - last))
  if [ "$elapsed" -ge "$MAX_FREEZE_SEC" ]; then
    echo "⚠️ ALERT: No changes to $FILE_TO_WATCH in the past $elapsed seconds!"
    echo "Time: $(date)"  # prevent repeated alerts
    
    # Send Slack notification
    if [ -n "$SLACK_BOT_TOKEN" ]; then
      curl -X POST https://slack.com/api/chat.postMessage \
        -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"channel\": \"$SLACK_BOT_TOKEN\",
          \"text\": \"<!here> 🚨 FREEZE ALERT: No changes to $FILE_TO_WATCH in the past $elapsed seconds! Time: $(date)\"
        }"
    else
      echo "Warning: SLACK_BOT_TOKEN not set, skipping Slack notification"
    fi
    rm -f "$LAST_CHANGE_TIME"
    exit 1
  fi
done

echo "Exiting watcher."
