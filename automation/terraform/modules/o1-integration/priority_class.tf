resource "kubernetes_priority_class" "testnet_priority_class" {
  depends_on = [
    module.kubernetes_testnet.testnet_namespace
  ]
  metadata {
    name      = "${var.testnet_name}-nonpreemptible-priority-class"
    namespace = module.kubernetes_testnet.testnet_namespace.metadata[0].name
  }

  value             = var.pod_priority
  preemption_policy = "Never"
  global_default    = false
}
