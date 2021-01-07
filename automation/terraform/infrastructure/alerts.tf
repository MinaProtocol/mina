locals {
  testnet_alerts = {
    groups = [
        {
            name = "Block Production Rate"
            rules = [
                {
                    alert   = "BlockProductionStopped"
                    expr    = "increase(Coda_Transition_frontier_max_blocklength_observed{testnet=\"$testnet\"}[1h]) < 1"
                    "for"   = "1h"
                    labels = {
                        severity = "critical"
                    }
                    annotations = {
                        description = "Zero blocks have been produced on testnet {{ $labels.testnet }} for more than 1 hour."
                        summary     = "{{ $labels.testnet }} block production is critically low"
                    }
                }
            ]
        }
    ]
  }
  pagerduty_receivers = [
    {
        name = "pagerduty-testnet-primary"
        pagerduty_configs = [
            {
                service-key = data.aws_secretsmanager_secret_version.pagerduty_testnet_primary_key_id.secret_string
            }
        ]
    }
  ]
}
