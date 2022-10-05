locals {
  this_id                           = compact(coalescelist(aws_instance.coda_node.*.id, [""]))
  this_availability_zone            = compact(coalescelist(aws_instance.coda_node.*.availability_zone, [""]))
  this_key_name                     = compact(coalescelist(aws_instance.coda_node.*.key_name, [""]))
  this_public_dns                   = compact(coalescelist(aws_instance.coda_node.*.public_dns, [""]))
  this_public_ip                    = compact(coalescelist(aws_instance.coda_node.*.public_ip, [""]))
  this_primary_network_interface_id = compact(coalescelist(aws_instance.coda_node.*.primary_network_interface_id, [""]))
  this_private_dns                  = compact(coalescelist(aws_instance.coda_node.*.private_dns, [""]))
  this_private_ip                   = compact(coalescelist(aws_instance.coda_node.*.private_ip, [""]))
  this_security_groups              = coalescelist(aws_instance.coda_node.*.security_groups, [""])
  this_vpc_security_group_ids       = coalescelist(flatten(aws_instance.coda_node.*.vpc_security_group_ids), [""])
  this_subnet_id                    = compact(coalescelist(aws_instance.coda_node.*.subnet_id, [""]))
  this_tags                         = coalescelist(aws_instance.coda_node.*.tags, [""])
}

output "id" {
  description = "List of IDs of instances"
  value       = local.this_id
}

output "availability_zone" {
  description = "List of availability zones of instances"
  value       = local.this_availability_zone
}

output "key_name" {
  description = "List of key names of instances"
  value       = local.this_key_name
}

output "public_dns" {
  description = "List of public DNS names assigned to the instances. For EC2-VPC, this is only available if you've enabled DNS hostnames for your VPC"
  value       = local.this_public_dns
}

output "public_ip" {
  description = "List of public IP addresses assigned to the instances, if applicable"
  value       = local.this_public_ip
}

output "primary_network_interface_id" {
  description = "List of IDs of the primary network interface of instances"
  value       = local.this_primary_network_interface_id
}

output "private_dns" {
  description = "List of private DNS names assigned to the instances. Can only be used inside the Amazon EC2, and only available if you've enabled DNS hostnames for your VPC"
  value       = local.this_private_dns
}

output "private_ip" {
  description = "List of private IP addresses assigned to the instances"
  value       = local.this_private_ip
}

output "security_groups" {
  description = "List of associated security groups of instances"
  value       = local.this_security_groups
}

output "vpc_security_group_ids" {
  description = "List of associated security groups of instances, if running in non-default VPC"
  value       = local.this_vpc_security_group_ids
}

output "subnet_id" {
  description = "List of IDs of VPC subnets of instances"
  value       = local.this_subnet_id
}

output "tags" {
  description = "List of tags of instances"
  value       = local.this_tags
}