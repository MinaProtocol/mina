let Prelude = ../External/Prelude.dhall

let P = Prelude

let Text/concatMap = P.Text.concatMap

let Cmd = ../Lib/Cmds.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let runInDockerWithPostgresConn
    : List Text -> Text -> Text -> Cmd.Type
    =     \(environment : List Text)
      ->  \(docker : Text)
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

          -- read the latest archive data version from the version file 
          let version = ../../../src/test/archive/sample_db/latest_version as Text
          

          let initUrl
              : Text
              = "https://storage.googleapis.com/o1labs-ci-test-data/replay/v${version}/archive_db.sql"

          in  Cmd.chain
                [ "( docker stop ${postgresDockerName} && docker rm ${postgresDockerName} ) || true"
                , "source buildkite/scripts/export-git-env-vars.sh"
                , "docker run --network host --volume ${outerDir}:/workdir --workdir /workdir --name ${postgresDockerName} -d -e POSTGRES_USER=${user} -e POSTGRES_PASSWORD=${password} -e POSTGRES_PASSWORD=${password} -e POSTGRES_DB=${dbName} ${dockerVersion}"
                , "sleep 5"
                , "curl -L -o ${outerDir}/initScript.sql ${initUrl}"
                , "mkdir -p ${outerDir}/_build/default/src/test/archive/sample_db"
                , "cp ${outerDir}/initScript.sql ${outerDir}/_build/default/src/test/archive/sample_db/archive_db.sql"
                , "cp ${outerDir}/src/test/archive/sample_db/replayer_input_file.json ${outerDir}/_build/default/src/test/archive/sample_db/"
                , "cp src/test/archive/sample_db/replayer_input_file.json ${outerDir}/_build/default/src/test/archive/sample_db/"
                , "docker exec ${postgresDockerName} psql ${pg_conn} -f /workdir/initScript.sql"
                , "docker run --network host --volume ${outerDir}:/workdir --workdir /workdir --entrypoint bash ${envVars} ${docker} ${innerScript}"
                ]

in  { runInDockerWithPostgresConn = runInDockerWithPostgresConn }
