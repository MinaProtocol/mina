output "cluster_svc_name" {

  value = var.enable_gcs_access ? google_service_account.gcp_buildkite_account[0].name : "custom"
}

output "cluster_svc_email" {

  value = var.enable_gcs_access ? google_service_account.gcp_buildkite_account[0].email : "custom"
}
