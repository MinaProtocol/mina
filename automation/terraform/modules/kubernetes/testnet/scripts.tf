# Copying keys from testenet instance (using var.testnet_name in relative path to keys)

resource "null_resource" "copying_keys_to_chart" {
  count    = var.deploy_bootstrap_chart ? 1 : 0
  provisioner "local-exec" {
    working_dir = "${path.module}/../../../.."
    command     = "./scripts/bootstrap-keys.sh --testnet ${var.testnet_name}"
  }
}