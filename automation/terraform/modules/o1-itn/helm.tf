provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" # Set the path to your Kubernetes config file
  }
}

resource "helm_release" "itn-services" {
  provider  = helm
  name      = "itn-services"
  chart     = "../../../../helm/itn-services"
  namespace = "testworld-2-0-final"

  wait    = false
  timeout = 600

  #   set {
  #     name  = "replicaCount"
  #     value = 3
  #   }

  #   depends_on = [
  #     kubernetes_role_binding.helm_release
  #   ]
}
