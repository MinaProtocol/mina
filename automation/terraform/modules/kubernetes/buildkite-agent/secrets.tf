resource "kubernetes_secret" "google_application_credentials" {
  provider = kubernetes.bk_deploy

  count = var.enable_gcs_access ? 1 : 0

  metadata {
    name      = "google-application-credentials"
    namespace = kubernetes_namespace.cluster_namespace.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = google_service_account.gcp_buildkite_account[0].name,
      "kubernetes.io/service-account.namespace" = kubernetes_namespace.cluster_namespace.metadata[0].name
    }
  }

  data = {
    "credentials_json" = "${var.enable_gcs_access ? google_service_account_key.buildkite_svc_key[0].private_key : var.google_app_credentials}"
  }
}

