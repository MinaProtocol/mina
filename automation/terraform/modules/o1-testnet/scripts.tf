resource "null_resource" "block_producer_key_generation" {
  provisioner "local-exec" {
    command = "${path.module}/../../../scripts/generate-keys-and-ledger.sh --testnet=${var.testnet_name} --wc=${var.whale_count} --fc=${var.fish_count} --reset=false --artifact-path=${var.artifact_path}"
  }
}

resource "null_resource" "block_producer_uploads" {
  provisioner "local-exec" {
    command = "${path.module}/../../../scripts/upload-keys-k8s.sh ${var.testnet_name}"
    environment = {
      CLUSTER = var.k8s_context
    }
  }
  depends_on = [
    module.kubernetes_testnet.testnet_namespace,
    null_resource.block_producer_key_generation
  ]
}
