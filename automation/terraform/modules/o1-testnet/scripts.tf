resource "null_resource" "block_producer_key_generation" {
  provisioner "local-exec" {
    working_dir = "${path.module}/../../.."
    command     = "./scripts/generate-keys-and-ledger.sh --testnet=${var.testnet_name} --sc=${var.seed_count} --wu=${local.whale_count_unique} --wt=${local.whale_count_total} --fu=${local.fish_count_unique} --ft=${local.fish_count_total} --reset=false --artifact-path=${var.artifact_path}"
  }
}

resource "null_resource" "block_producer_uploads" {
  provisioner "local-exec" {
    working_dir = "${path.module}/../../.."
    command     = "./scripts/upload-keys-k8s-simplified.sh ${var.testnet_name}"
    environment = {
      CLUSTER = var.k8s_context
    }
  }
  depends_on = [
    module.kubernetes_testnet.testnet_namespace,
    null_resource.block_producer_key_generation
  ]
}

resource "null_resource" "seed_list" {
  provisioner "local-exec" {
    working_dir = "${path.module}/../../.."
    command     = "./scripts/make-seeds-list.sh --testnet=${var.testnet_name} --artifact-path=${var.artifact_path}"
  }
  depends_on = [
    module.kubernetes_testnet.testnet_namespace,
    null_resource.block_producer_key_generation
  ]
}
