locals {
  graphql_ingress_dns = "${var.testnet_name}.graphql.test.o1test.net"
  snark_worker_host_port            = 10001
  block_producer_starting_host_port = 10010
  

  # seed_peer = {
  #   multiaddr = "/dns4/seed.${var.testnet_name}/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf",
  #   peerid = "12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf",
  #   private_key_secretbox = "{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"7YSQmeRbo4fGd2nYh9aS4WzNWzSXsFmmkTqKy93\",\"pwsalt\":\"9QsEJdSkFbF8PUwLPo2ZLHpgT7ja\",\"pwdiff\":[134217728,6],\"ciphertext\":\"7o8WU4cBiuUqGPaF2fNA815XqhZM5j95dhns5zztCiSehb3xVzTUSbCj1nDXG5rAteu67pvMnaGbQ57cQw1HEPB2DDdrtAAWbCt7qYjmP6cNm2L7H9DC8NKHs1LYuWvthfjDvxBDHnVidpRCyqtMBg9TPWtMPkZy1UCVRFokAA5HaA2xkh4WFgy2SCVrAeWNP5BeUGq9u779KcM9BAtg9n6rqbKDTybX4h1aSZ9qA72tg1LHzENfHLAgzJXZQcxhjvw6b8H51m9rVhwFTKPCRRCNXfcyQqjEpH4fm\"}",
  #   secret = "seed-discovery-keys",
  #   port = 10401
  # }

  seed_external_port = 10001

  seed_config = {
    name                 = "seed",
    class                = "seed",
    libp2p_secret        = "seed-discovery-keys",
    libp2p_secret_pw     = "naughty blue worm"
    external_ip          = null,
    # private_key_secret = null,
    enableArchive        = false,
    archiveAddress       = null
    persist_working_dir  = var.enable_working_dir_persitence
  }
  

  #snark_coordinator_name = "snark-coordinator-${lower(substr(var.snark_worker_public_key, -6, -1))}"

  default_archive_node = {
    image                   = var.mina_archive_image
    serverPort              = "3086"
    externalPort            = "11010"
    enableLocalDaemon       = true
    enablePostgresDB        = true

    postgresHost            = "archive-1-postgresql"
    postgresPort            = 5432
    # remoteSchemaFile needs to be just the script name, not a url.  remoteSchemaAuxFiles needs to be a list of urls of scripts, one of these urls needs to be the url of the main sql script that invokes the other ones.  sorry it's confusing
    remoteSchemaFile        = var.mina_archive_schema
    remoteSchemaAuxFiles    = var.mina_archive_schema_aux_files

    persistenceEnabled      = false
    persistenceSize         = "1Gi"
    persistenceStorageClass = "ssd-delete"
    persistenceAccessModes  = ["ReadWriteOnce"]
    spotAllowed             = "true"
    persist_working_dir     = var.enable_working_dir_persitence
  }

  archive_node_configs = var.archive_configs != null ? [for item in var.archive_configs : merge(local.default_archive_node, item)] : [
    for i in range(1, var.archive_node_count + 1) : merge(local.default_archive_node, {
      name              = "archive-${i}"
      postgresHost      = "archive-${i}-postgresql"
    })
  ]

  archive_node_names         = var.archive_node_count == 0 ? [ "" ] : [for i in range(var.archive_node_count) : "archive-${i + 1}:3086"]
}
