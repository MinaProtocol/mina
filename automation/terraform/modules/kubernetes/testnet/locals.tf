locals {
  default_archive_node = {
    image              = var.coda_archive_image
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
}
