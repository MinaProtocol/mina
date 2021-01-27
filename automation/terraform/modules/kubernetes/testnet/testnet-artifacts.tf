resource "null_resource" "block_producer_key_generation" {
  count = var.generate_and_upload_artifacts ? 1 : 0
  provisioner "local-exec" {
    command = "${path.module}/../../../../scripts/generate-keys-and-ledger.sh --testnet=${var.testnet_name} --wc=${var.whale_count} --fc=${var.fish_count} --reset=false"
  }
}

resource "null_resource" "block_producer_uploads" {
  count = var.generate_and_upload_artifacts ? 1 : 0
  provisioner "local-exec" {
    command = "${path.module}/../../../../scripts/upload-keys-k8s.sh ${var.testnet_name}"
  }
  depends_on = [
    kubernetes_namespace.testnet_namespace,
    null_resource.block_producer_key_generation,
  ]
}
