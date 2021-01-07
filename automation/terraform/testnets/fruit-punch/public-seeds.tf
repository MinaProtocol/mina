 # # Defaults to the provider project
 data "google_project" "project" {
   provider = google.google-us-east1
 }

 module "seed_network" {
   source         = "../../modules/google-cloud/vpc-network"
   project_id     = "o1labs-192920"
   network_name   = "${local.testnet_name}-testnet-network-${local.seed_region}"
   network_region = local.seed_region
   subnet_name    = "${local.testnet_name}-testnet-subnet-${local.seed_region}"
 }

 module "seed_one" {
   source             = "../../modules/google-cloud/coda-seed-node"
   coda_image         = local.coda_image
   project_id         = "o1labs-192920"
   runtime_config     = local.runtime_config
   subnetwork_project = "o1labs-192920"
   subnetwork         = module.seed_network.subnet_link
   network            = module.seed_network.network_link
   instance_name      = "${local.testnet_name}-seed-one-${local.seed_region}"
   zone               = local.seed_zone
   region             = local.seed_region
   client_email       = "1020762690228-compute@developer.gserviceaccount.com"
   discovery_keypair  = local.seed_discovery_keypairs[0]
   seed_peers         = ""
 }

 module "seed_two" {
   source             = "../../modules/google-cloud/coda-seed-node"
   coda_image         = local.coda_image
   runtime_config     = local.runtime_config
   project_id         = "o1labs-192920"
   subnetwork_project = "o1labs-192920"
   subnetwork         = module.seed_network.subnet_link
   network            = module.seed_network.network_link
   instance_name      = "${local.testnet_name}-seed-two-${local.seed_region}"
   zone               = local.seed_zone
   region             = local.seed_region
   client_email       = "1020762690228-compute@developer.gserviceaccount.com"
   discovery_keypair  = local.seed_discovery_keypairs[1]
   seed_peers         = "-peer /ip4/${module.seed_one.instance_external_ip}/tcp/10002/p2p/${split(",", module.seed_one.discovery_keypair)[2]}"
 }

 # Seed DNS
 data "aws_route53_zone" "selected" {
   name = "o1test.net."
 }

 resource "aws_route53_record" "seed_one" {
   zone_id = data.aws_route53_zone.selected.zone_id
   name    = "seed-one.${local.testnet_name}.${data.aws_route53_zone.selected.name}"
   type    = "A"
   ttl     = "300"
   records = [module.seed_one.instance_external_ip]
 }

 resource "aws_route53_record" "seed_two" {
   zone_id = data.aws_route53_zone.selected.zone_id
   name    = "seed-two.${local.testnet_name}.${data.aws_route53_zone.selected.name}"
   type    = "A"
   ttl     = "300"
   records = [module.seed_two.instance_external_ip]
 }
