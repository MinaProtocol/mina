terraform {
  experiments = [module_variable_optional_attrs]
}

locals {
  default_archive_node = {
    serverPort         = "3086"
    externalPort       = "11010"
    enableLocalDaemon  = true
    enablePostgresDB   = true
    postgresHost       = "archive-1-postgresql"
    postgresPort       = 5432
    postgresDB         = "archive"
    postgresqlUsername = "postgres"
    postgresqlPassword = "foobar"
    remoteSchemaFile   = var.mina_archive_schema
  }

  default_postgres_config = {
    persistence = {
      enabled      = false
      storageClass = "ssd-retain"
      accessModes  = ["ReadWriteOnce"]
      size         = "8Gi"
    }
  }
}