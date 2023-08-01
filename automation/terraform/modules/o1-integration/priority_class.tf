resource "kubernetes_priority_class" "testnet_priority_class" {
  metadata {
    name = "${var.testnet_name}-nonpreemptible-priority-class"
  }

  value = var.pod_priority
  preemption_policy = "Never"
  global_default = false
}
