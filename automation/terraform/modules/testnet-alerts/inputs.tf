terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.11.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

variable "rule_namespace" {
  type        = string
  description = "Grafanacloud namespace for grouping rule sets"
  default     = "testnet-alerts"
}

variable "rule_filter" {
  type        = string
  description = "Filter to apply to monitoring search space for managing the scope of alert rule checks"
}

variable "rule_timeframe" {
  type        = string
  description = "Span of time a rule must be violated prior to triggering an alert"
}

variable "pagerduty_alert_filter" {
  type        = string
  description = "Filter to apply to alert rule violation space for managing which trigger PagerDuty notifications"
}
