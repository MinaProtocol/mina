resource "null_resource" "block_producer_key_generation" {
  count = var.runtime_config == "" ? 1 : 0
  provisioner "local-exec" {
    command = "../../../scripts/generate-keys-and-ledger.sh --testnet=${var.testnet_name} --wc=${var.whale_count} --fc=${var.fish_count} --reset=false"
  }
}

resource "null_resource" "prepare_keys_for_deployment" {
  count = var.runtime_config == "" ? 1 : 0
  provisioner "local-exec" {
    command = "chmod -R a+rwX ../../../keys"
  }
  depends_on  = [kubernetes_namespace.testnet_namespace, null_resource.block_producer_key_generation]
}

resource "null_resource" "block_producer_uploads" {
  count = var.runtime_config == "" ? 1 : 0
  provisioner "local-exec" {
    command = "../../../scripts/upload-keys-k8s.sh ${var.testnet_name}"
  }
  depends_on = [
    kubernetes_namespace.testnet_namespace,
    null_resource.block_producer_key_generation,
    null_resource.prepare_keys_for_deployment
  ]
}
