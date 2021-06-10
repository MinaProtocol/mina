resource "google_storage_bucket_object" "runtime_config" {
  bucket  = local.integration_test_bucket
  name    = local.runtime_config_object_name
  # content = var.runtime_config
  source  = "daemon.json"
}
