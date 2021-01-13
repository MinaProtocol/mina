# output "seed_one_ip" {
#   value = module.seed_one.instance_external_ip
# }

# output "seed_two_ip" {
#   value = module.seed_two.instance_external_ip
# }

output "seed_addresses" {
  value = local.seed_peers
}