let Prelude = ../External/Prelude.dhall

let P = Prelude

let Text/concatMap = P.Text.concatMap

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

let Cmd = ../Lib/Cmds.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Network = ../Constants/Network.dhall

let runInDockerWithPostgresConn
    :     List Text
      ->  Text
      ->  Artifacts.Type
      ->  Optional Network.Type
      ->  Text
      ->  Cmd.Type
    =     \(environment : List Text)
      ->  \(initScript : Text)
      ->  \(docker : Artifacts.Type)
      ->  \(network : Optional Network.Type)
      ->  \(innerScript : Text)
      ->  let port = "5432"

          let user = "postgres"

          let password = "postgres"

          let postgresDockerName = "postgres"

          let dockerVersion = ContainerImages.postgres

          let dbName = "archive"

          let pg_conn =
                "postgres://${user}:${password}@localhost:${port}/${dbName}"

          let envVars =
                Text/concatMap
                  Text
                  (\(var : Text) -> " --env ${var}")
                  (   [ "PG_PORT=${port}"
                      , "POSTGRES_USER=${user}"
                      , "POSTGRES_PASSWORD=${password}"
                      , "POSTGRES_DB=${dbName}"
                      , "PG_CONN=${pg_conn}"
                      ]
                    # environment
                  )

          let outerDir
              : Text
              = "\\\$BUILDKITE_BUILD_CHECKOUT_PATH"

          let minaDockerTag
              : Text
              = "\\\$MINA_DOCKER_TAG"

          let maybeNetwork =
                Optional/map
                  Network.Type
                  Text
                  (\(network : Network.Type) -> "-${Network.lowerName network}")
                  network

          let networkOrDefault = Optional/default Text "" maybeNetwork

          in  Cmd.chain
                [ "( docker stop ${postgresDockerName} && docker rm ${postgresDockerName} ) || true"
                , "source buildkite/scripts/export-git-env-vars.sh"
                , "docker run --network host --volume ${outerDir}:/workdir --workdir /workdir --name ${postgresDockerName} -d -e POSTGRES_USER=${user} -e POSTGRES_PASSWORD=${password} -e POSTGRES_PASSWORD=${password} -e POSTGRES_DB=${dbName} ${dockerVersion}"
                , "sleep 5"
                , "docker exec ${postgresDockerName} psql ${pg_conn} -f /workdir/${initScript}"
                , "docker run --network host --volume ${outerDir}:/workdir --workdir /workdir --entrypoint bash ${envVars} gcr.io/o1labs-192920/${Artifacts.dockerName
                                                                                                                                                    docker}:${minaDockerTag}${networkOrDefault} ${innerScript}"
                ]

in  { runInDockerWithPostgresConn = runInDockerWithPostgresConn }
