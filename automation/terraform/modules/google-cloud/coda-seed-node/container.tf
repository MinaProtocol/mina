locals {
  cos_image_family = "cos-stable"
  cos_project      = "cos-cloud"
}

data "google_compute_image" "coreos" {
  name    = null
  family  = local.cos_image_family
  project = local.cos_project
}
