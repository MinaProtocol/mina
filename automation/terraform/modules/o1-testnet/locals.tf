locals {
  static_peers = {
    for index, name in keys(data.local_file.libp2p_peers) : name => {
      full_peer = "/dns4/${name}.${var.testnet_name}/tcp/${var.block_producer_starting_host_port + index }/p2p/${trimspace(data.local_file.libp2p_peers[name].content)}",
      port      = var.block_producer_starting_host_port + index
      name      = name
    }
  }

  whale_block_producer_names = [for i in range(var.whale_count): "whale-block-producer-${i + 1}"]
  fish_block_producer_names = [for i in range(var.fish_count): "fish-block-producer-${i + 1}"]
}
