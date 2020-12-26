locals {
  testnet_alerts = {
    groups = [
        {
            name = "Block Production Rate"
            rules = [
                {
                    alert   = "BlockProductionStopped"
                    expr    = "increase(Coda_Transition_frontier_max_blocklength_observed{testnet=\"$testnet\"}[60m]) < 1"
                    "for"   = "60m" 
                    labels = {
                        severity = "critical"
                    }
                    annotations = {
                        description = "Zero blocks have been produced on testnet {{ $labels.testnet }} for more than 60 minutes."
                        summary     = "{{ $labels.testnet }} block production is critically low"
                    }
                }
            ]
        }
    ]
  }
  pagerduty_receivers = [
    {
        name = "pagerduty-primary"
        pagerduty_configs = [
            {
            # TODO: Store in AWS SecretManager 
            service-key = "9aefac9667004bb78681288ba4161df0"
            }
        ]
    }
  ]
}
