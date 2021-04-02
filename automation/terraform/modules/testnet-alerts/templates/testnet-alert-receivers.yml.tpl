# $: pagerduty_service_key - service integration key to trigger PagerDuty pages
# $: pagerduty_alert_filter - regular expression indicating set of testnets to monitor/alert via PagerDuty
# $: discord_alert_webhook - Discord integration webhook for sending alert messages

global: {}
receivers:
  - name: pagerduty-testnet-primary
    pagerduty_configs:
      - service_key: ${pagerduty_service_key}
  - name: discord-alert-default
    webhook_configs:
      - url: ${discord_alert_webhook}
route:
  receiver: discord-alert-default
  group_by:
    - testnet
  routes:
    - receiver: pagerduty-testnet-primary
      match_re:
        testnet: ^(${pagerduty_alert_filter})$
        severity: critical
    - receiver: discord-alert-default
      match_re:
        testnet: ^(${pagerduty_alert_filter})$
        severity: warning
