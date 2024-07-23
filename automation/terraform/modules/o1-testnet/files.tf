# terraform cannot handle file sizes above 4mb, as a result, using a genesis_ledger.json file is no longer supported

# data "local_file" "genesis_ledger" {
#   filename = "${var.artifact_path}/genesis_ledger.json"
#   depends_on = [
#     null_resource.block_producer_key_generation
#   ]
# }

# data "local_file" "libp2p_peers" {
#   for_each = toset(concat(local.whale_block_producer_libp2p_names, local.fish_block_producer_libp2p_names))
#   filename = "${path.module}/../../../keys/libp2p/${var.testnet_name}/${each.key}"
#   depends_on = [
#     null_resource.block_producer_key_generation
#   ]
# }

# Generate random strings for peer IDs
resource "random_id" "peer_id" {
  for_each = var.create_libp2p_files ? toset(local.seed_names) : []
  byte_length = 32
}

# Create the files with the generated peer IDs
resource "local_file" "libp2p_seed_peers" {
  for_each = var.create_libp2p_files ? toset(local.seed_names) : []
  filename = "${var.artifact_path}/keys/libp2p-keys/${each.key}.peerid"
  content  = random_id.peer_id[each.key].hex
}

data "local_file" "libp2p_seed_peers" {
  for_each = toset(local.seed_names)
  filename = "${var.artifact_path}/keys/libp2p-keys/${each.key}.peerid"
  depends_on = [
    local_file.libp2p_seed_peers
  ]
}
