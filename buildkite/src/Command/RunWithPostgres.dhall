let Prelude = ../External/Prelude.dhall
let P = Prelude
let Text/concatMap = P.Text.concatMap

let Cmd = ../Lib/Cmds.dhall
let Mina = ../Command/Mina.dhall
let S = ../Lib/SelectFiles.dhall
let ContainerImages = ../Constants/ContainerImages.dhall
let Artifacts= ../Constants/Artifacts.dhall

let r = Cmd.run

let runInDockerWithPostgresConn : List Text -> Text -> Artifacts.Type -> Text -> Cmd.Type =
  \(environment : List Text) ->
  \(initScript: Text ) -> 
  \(docker: Artifacts.Type) ->
  \(innerScript : Text) ->
    let port="5433"
    let user="postgres"
    let password="postgres"
    let postgresDockerName="postgres"
    let dockerVersion= ContainerImages.postgres
    let dbName="archive"
    let pg_conn="postgres://${user}:${password}@localhost:${port}/${dbName}"

    let envVars =
      Text/concatMap
        Text
        (\(var : Text) -> " --env ${var}")
        ([
            "PG_PORT=${port}",
            "POSTGRES_USER=${user}",
            "POSTGRES_PASSWORD=${password}",
            "POSTGRES_DB=${dbName}",
            "PG_CONN=${pg_conn}"
        ] # environment)
    in
    Cmd.chainWithTearDown [
         "source buildkite/scripts/export-git-env-vars.sh",
         "docker run --network host --volume $BUILDKITE_BUILD_CHECKOUT_PATH:/workdir --volume ./dataset:/docker-entrypoint-initdb.d --name ${postgresDockerName} -d -p ${port}:5432 -e POSTGRES_USER=${user} -e POSTGRES_PASSWORD=${password} -e POSTGRES_DB=${dbName} ${dockerVersion}",
         "sleep 5",
         "docker exec replayer-postgres psql $PG_CONN -f /workdir/${initScript}",
         "docker run --network host --volume $BUILDKITE_BUILD_CHECKOUT_PATH:/workdir gcr.io/o1labs-192920/${Artifacts.dockerName docker}:$MINA_DOCKER_TAG ${innerScript}"
    ] 
    " docker stop postgres && docker rm postgres"
    
in

{
  runInDockerWithPostgresConn = runInDockerWithPostgresConn
}