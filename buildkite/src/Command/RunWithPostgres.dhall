{-|
## RunWithPostgres Module

This module provides functionality for running Docker containers with PostgreSQL connectivity.

### Functions

#### `runInDockerWithPostgresConn`

Runs a Docker container with PostgreSQL database connection, setting up a complete environment
for database-dependent operations.

**Parameters:**
- `environment : List Text` - Additional environment variables to pass to the container
- `initScript : Text` - Path to SQL initialization script to run against the database
- `docker : Text` - Docker image name to run the main command in
- `innerScript : Text` - Script or command to execute inside the Docker container

**Returns:** `Cmd.Type` - A command chain that sets up PostgreSQL and runs the specified container

**Behavior:**
1. Stops and removes any existing PostgreSQL container
2. Exports Git environment variables
3. Starts a PostgreSQL container with predefined credentials
4. Waits for PostgreSQL to be ready
5. Executes the initialization script against the database
6. Runs the target Docker container with database connectivity

**Process Management:**
- Uses host PID namespace (`--pid=host`) for the PostgreSQL container to enable proper process visibility and management
- Allows containers to interact with host system processes for debugging and monitoring purposes

**Database Configuration:**
- Port: 5432
- User: postgres
- Password: postgres
- Database: archive
- Connection URI format: `postgres://postgres:postgres@localhost:5432/archive`

**Environment Variables Set:**
- `PG_PORT` - PostgreSQL port number
- `POSTGRES_USER` - Database username
- `POSTGRES_PASSWORD` - Database password
- `POSTGRES_DB` - Database name
- `POSTGRES_URI` - PostgreSQL connection URI
- `PG_CONN` - Full database connection string
-}


let Prelude = ../External/Prelude.dhall

let P = Prelude

let Text/concatMap = P.Text.concatMap

let Cmd = ../Lib/Cmds.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let runInDockerWithPostgresConn
    : List Text -> Text -> Text -> Text -> Cmd.Type
    =     \(environment : List Text)
      ->  \(initScript : Text)
      ->  \(docker : Text)
      ->  \(innerScript : Text)
      ->  let port = "5432"

          let user = "postgres"

          let password = "postgres"

          let postgresDockerName = "postgres"

          let dockerVersion = ContainerImages.postgres

          let dbName = "archive"

          let pg_uri = "postgres://${user}:${password}@localhost:${port}"

          let pg_conn = "${pg_uri}/${dbName}"

          let envVars =
                Text/concatMap
                  Text
                  (\(var : Text) -> " --env ${var}")
                  (   [ "PG_PORT=${port}"
                      , "POSTGRES_USER=${user}"
                      , "POSTGRES_PASSWORD=${password}"
                      , "POSTGRES_DB=${dbName}"
                      , "POSTGRES_URI=${pg_uri}"
                      , "PG_CONN=${pg_conn}"
                      ]
                    # environment
                  )

          let outerDir
              : Text
              = "\\\$BUILDKITE_BUILD_CHECKOUT_PATH"

          in  Cmd.chain
                [ "( docker stop ${postgresDockerName} && docker rm ${postgresDockerName} ) || true"
                , "source buildkite/scripts/export-git-env-vars.sh"
                , "docker run --network host --volume ${outerDir}:/workdir --workdir /workdir --name ${postgresDockerName} -d -e POSTGRES_USER=${user} -e POSTGRES_PASSWORD=${password} -e POSTGRES_PASSWORD=${password} -e POSTGRES_DB=${dbName} ${dockerVersion}"
                , "sleep 5"
                , "docker exec ${postgresDockerName} psql ${pg_conn} -f /workdir/${initScript}"
                , "docker run --pid=container:postgres --network host --volume ${outerDir}:/workdir --workdir /workdir --entrypoint bash ${envVars} ${docker} ${innerScript}"
                ]

in  { runInDockerWithPostgresConn = runInDockerWithPostgresConn }
