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

variable "berkeley_testnet" {
  type        = string 
  description = "Filter that selects out berkeley network"
  default     = "testnet=\"berkeley\""
}

variable "berkeley_rule_filter" {
  type        = string
  description = "Filter that only applies to berkeley network with syncStatus labels"
  default     = "syncStatus=\"SYNCED\""
}

variable "alert_timeframe" {
  type        = string
  description = "Range of time to inspect for alert rule violations"
}

variable "alert_duration" {
  type        = string
  description = "Duration an alert is evaluated as in violation prior to becoming active "
}

variable "pagerduty_alert_filter" {
  type        = string
  description = "Filter to apply to alert rule violation space for managing which trigger PagerDuty notifications"
}
