output "rendered_alerts_config" {
  value = data.template_file.testnet_alerts.rendered
}

output "rendered_receivers_config" {
  value     = data.template_file.testnet_alert_receivers.rendered
  sensitive = true
}
