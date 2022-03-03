locals {


  whale_count_total = length ( flatten( [
    for bp in var.whales :
      [
        for i in range(bp.duplicates) : ""
    
   ] ]) )

  fish_count_total = length ( flatten( [
    for index, bp in var.fishes :
      [
        for i in range(bp.duplicates) : ""
    
   ] ]) )



  whale_block_producer_libp2p_names = [for i in range(local.whale_count_total) : "whale-block-producer-${i + 1}"]
  fish_block_producer_libp2p_names  = [for i in range(local.fish_count_total) : "fish-block-producer-${i + 1}"]


  whale_configs = flatten( [
    for index, bp in var.whales :
      [
        for i in range(bp.duplicates) : {
          name      = "whale-${index+1}-${i+1}"
          unique_node_index= index+1
          total_node_index= 1+ i+ length ( flatten([for b in slice(var.whales,0, index) : [ for k in range(b.duplicates):0 ]  ])) #summation of all duplicates so far
          full_peer = "/dns4/whale-${index+1}-${i+1}.${var.testnet_name}.o1test.net/tcp/${var.block_producer_starting_host_port +i+ length ( flatten([for b in slice(var.whales,0, index) : [ for k in range(b.duplicates):0 ]  ]))}/p2p/${trimspace(data.local_file.libp2p_peers[element (local.whale_block_producer_libp2p_names,i+ length ( flatten([for b in slice(var.whales,0, index) : [ for k in range(b.duplicates):0 ]  ])) )  ].content)}",

          port      = var.block_producer_starting_host_port+i + length ( flatten([for b in slice(var.whales,0, index) : [ for k in range(b.duplicates):"" ]  ]))
          class  = "whale"

        }
    
   ] ])

  fish_configs = flatten( [
    for index, bp in var.fishes :
      [
        for i in range(bp.duplicates) : {
          name      = "fish-${index+1}-${i+1}"
          unique_node_index= index+1
          total_node_index= 1+ i+length ( flatten([for b in slice(var.fishes,0, index) : [ for k in range(b.duplicates):0 ]  ]))
          full_peer = "/dns4/fish-${index+1}-${i+1}.${var.testnet_name}.o1test.net/tcp/${var.block_producer_starting_host_port +i+ length ( flatten([for b in slice(var.fishes,0, index) : [ for k in range(b.duplicates):0 ]  ]))}/p2p/${trimspace(data.local_file.libp2p_peers[element (local.fish_block_producer_libp2p_names,i+ length ( flatten([for b in slice(var.fishes,0, index) : [ for k in range(b.duplicates):0 ]  ])) )  ].content)}",

          port      = var.block_producer_starting_host_port+i + length ( flatten([for b in slice(var.fishes,0, index) : [ for k in range(b.duplicates):"" ]  ]))
          class  = "fish"

        }
    
   ] ])

  block_producer_configs = concat(local.whale_configs, local.fish_configs)

  whale_count_unique = length(var.whales)
  fish_count_unique = length(var.fishes)

  seed_names                 = [for i in range(var.seed_count) : "seed-${i + 1}"]

  seed_static_peers = [
    for index, name in keys(data.local_file.libp2p_seed_peers) : {
      full_peer = "/dns4/${name}.${var.testnet_name}.o1test.net/tcp/${var.seed_starting_host_port + index}/p2p/${trimspace(data.local_file.libp2p_seed_peers[name].content)}",
      port      = var.seed_starting_host_port + index
      name      = local.seed_names[index]
      unique_node_index= -1
      total_node_index= -1
      class = "seed"
    }
  ]

  default_archive_node = {
    image                   = var.mina_archive_image
    serverPort              = "3086"
    externalPort            = "11010"
    enableLocalDaemon       = true
    enablePostgresDB        = true

    postgresHost            = "archive-1-postgresql"
    postgresPort            = 5432
    postgresDB              = "archive"
    postgresqlUsername      = "postgres"
    postgresqlPassword      = "foobar"
    # remoteSchemaFile needs to be just the script name, not a url.  remoteSchemaAuxFiles needs to be a list of urls of scripts, one of these urls needs to be the url of the main sql script that invokes the other ones.  sorry it's confusing
    remoteSchemaFile        = var.mina_archive_schema
    remoteSchemaAuxFiles    = var.mina_archive_schema_aux_files
    
    persistenceEnabled      = true
    persistenceSize         = "8Gi"
    persistenceStorageClass = "ssd-delete"
    persistenceAccessModes  = ["ReadWriteOnce"]
    preemptibleAllowed      = "false"
  }

  static_peers = concat(local.block_producer_configs, local.seed_static_peers)

  archive_node_configs = var.archive_configs != null ? [for item in var.archive_configs : merge(local.default_archive_node, item)] : [
    for i in range(1, var.archive_node_count + 1) : merge(local.default_archive_node, {
      name              = "archive-${i}"
      postgresHost      = "archive-${i}-postgresql"
    })
  ]
}
