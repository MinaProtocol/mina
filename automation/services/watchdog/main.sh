#!/bin/bash

set -e

trap 'kill $(jobs -p)' EXIT

echo "====="
echo "Restart nodes: $RESTART_NODES every $RESTART_EVERY_MINS minutes"
echo "Make reports: $MAKE_REPORTS every $MAKE_REPORT_EVERY_MINS minutes to $MAKE_REPORT_DISCORD_WEBHOOK_URL"
echo "====="

echo "sleeping 20 minutes for nodes to start up..."
sleep $((60*20))

if [ ! -z "$RESTART_NODES" ] && [ "$RESTART_NODES" != "false" ]; then
  echo "starting restart script"
  python3 /scripts/random_restart.py -n '' -i $RESTART_EVERY_MINS -ic true &
fi

if [ ! -z "$MAKE_REPORTS" ] && [ "$MAKE_REPORTS" != "false" ]; then
  while true; do
    echo "making a report"
    python3 make_report.py -n '' -ic true --discord_webhook_url "$MAKE_REPORT_DISCORD_WEBHOOK_URL" -a "$MAKE_REPORT_ACCOUNTS"
    sleep $((60*$MAKE_REPORT_EVERY_MINS))
  done &
fi

while true; do sleep 86400; done
