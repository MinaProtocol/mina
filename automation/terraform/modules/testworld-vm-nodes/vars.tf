variable "gcp_project" {
  default = "o1labs-192920"
}

variable "gcp_region" {
  default = "us-east4"
}

variable "gcp_zone" {
  default = "us-east4-b"
}

variable "billing_label" {
  default = "itn3"
}

variable "firewall_label" {
  default = ["itn3-node-vms"]
}


#####################################
# Secret Vars
#####################################

variable "itn_log_backend_keys" {
  default = "itn-log-backend-keys" # name of secret in Google Cloud
}

variable "itn_node_vm_1_libp2p_pass" {
  default = "itn-node-vm-1-libp2p-pass"
}

variable "itn_node_vm_1_privkey" {
  default = "itn-node-vm-1-privkey"
}

variable "itn_node_vm_1_privkey_pass" {
  default = "itn-node-vm-1-privkey-pass" # name of secret in Google Cloud
}

variable "itn_node_vm_1_pubkey" {
  default = "itn-node-vm-1-pubkey" # name of secret in Google Cloud
}

#####################################
# Passing Secrets To Templates
#####################################

data "template_file" "mina-config-node-1" {
  template = file("templates/mina-config-node-1.tpl")
  vars = {
    mina_libp2p_pass    = data.google_secret_manager_secret_version.itn_node_vm_1_libp2p_pass.secret_data
    wallet_privkey_pass = data.google_secret_manager_secret_version.itn_node_vm_1_privkey_pass.secret_data
    wallet_privkey      = data.google_secret_manager_secret_version.itn_node_vm_1_privkey.secret_data
    wallet_pubkey       = data.google_secret_manager_secret_version.itn_node_vm_1_pubkey.secret_data
    itn_logger_keys     = data.google_secret_manager_secret_version.itn_log_backend_keys.secret_data
  }
}

data "template_file" "startup" {
  template = file("templates/startup.tpl")
}
