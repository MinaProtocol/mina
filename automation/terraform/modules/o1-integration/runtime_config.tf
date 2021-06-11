resource "google_storage_bucket_object" "runtime_config" {
  bucket  = local.integration_test_bucket
  name    = local.runtime_config_object_name
  # content = var.runtime_config
  source  = "daemon.json"
}

data "google_storage_object_signed_url" "runtime_config" {
  provider = "google.gke"
  bucket   = local.integration_test_bucket
  path     = local.runtime_config_object_name
}
