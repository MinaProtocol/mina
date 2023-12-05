# Copying keys from testenet instance (using var.testnet_name in relative path to keys)

resource "null_resource" "copying_keys_to_chart" {
  # Integration module does not deploy bootstrap as Secrets
  # are created directly
  count    = length(var.seed_configs) == 0 ? 1 : 0
  provisioner "local-exec" {
    working_dir = "${path.module}/../../../.."
    command     = "./scripts/bootstrap-keys.sh --testnet ${var.testnet_name}"
  }
}