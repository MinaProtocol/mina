resource "kubernetes_priority_class" "testnet_priority_class" {
  metadata {
    name      = "${var.testnet_name}-nonpreemptible-priority-class"
    namespace = kubernetes_namespace.testnet_namespace.metadata[0].name
  }

  value             = var.pod_priority
  preemption_policy = "Never"
  global_default    = false
}
