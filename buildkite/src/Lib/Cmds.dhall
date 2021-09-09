-- A DSL for manipulating commands and their execution environments
let Prelude = ../External/Prelude.dhall
let P = Prelude
let List/map = P.List.map
let List/null = P.List.null
let Optional/toList = P.Optional.toList
let Optional/default = P.Optional.default
let Optional/map = P.Optional.map
let List/concatMap = P.List.concatMap
let List/concat = P.List.concat
let Text/concatSep = P.Text.concatSep
let Text/concatMap = P.Text.concatMap

-- abstract out defaultEnv so tests are less verbose
let module = \(environment : List Text) ->

  let Docker = {
    Type = {
      image : Text,
      extraEnv : List Text
    },
    default = {
      extraEnv = ([] : List Text)
    }
  }

  let Cmd = { line: Text, readable: Optional Text }
  let run : Text -> Cmd =
    \(script: Text) -> { line = script, readable = Some script }

  let quietly : Text -> Cmd =
    \(script: Text) -> { line = script, readable = None Text }
  let true : Cmd = quietly "true"
  let false : Cmd = quietly "false"

  let inDocker : Docker.Type -> Cmd -> Cmd =
    \(docker : Docker.Type) ->
    \(inner : Cmd) ->
    let envVars =
      Text/concatMap
        Text
        (\(var : Text) -> " --env ${var}")
        (docker.extraEnv # environment)
    let outerDir : Text =
      "/var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG"
    let sharedDir : Text = "/var/buildkite/shared"
    in
    { line = "docker run -it --rm --init --volume ${sharedDir}:/shared --volume ${outerDir}:/workdir --workdir /workdir${envVars} ${docker.image} /bin/sh -c '${inner.line}'"
    , readable = Optional/map Text Text (\(readable : Text) -> "Docker@${docker.image} ( ${readable} )") inner.readable
    }

  let runInDocker : Docker.Type -> Text -> Cmd =
    \(docker : Docker.Type) ->
    \(script : Text) ->
    inDocker docker (run script)

  let CacheSetupCmd = {
    Type = {
      -- run your command to create data (only on miss)
      create : Cmd,
      -- package data before an upload to gcloud (only on miss)
      package : Cmd
    },
    default = {=}
  }

  let format : Cmd -> Text =
    \(cmd : Cmd) -> cmd.line

  -- Loads through cache, innards with docker, buildkite-agent interactions outside, continues in docker after hit or miss with continuation
  let cacheThrough : Docker.Type -> Text -> CacheSetupCmd.Type -> Cmd =
    \(docker : Docker.Type) ->
    \(cachePath : Text) ->
    \(cmd : CacheSetupCmd.Type) ->
      let missScript =
        ( format cmd.create ) ++ " && " ++
        ( format cmd.package )
      let missCmd =
        runInDocker docker missScript
      in
      { line = "./buildkite/scripts/cache-through.sh ${cachePath} \"${format missCmd}\""
      , readable =
          Optional/map
            Text
            Text
            (\(readable : Text) -> "Cache@${cachePath} ( onMiss = ${readable} )")
            missCmd.readable
      }
  in

  { Type = Cmd
  , Docker = Docker
  , CacheSetupCmd = CacheSetupCmd
  , quietly = quietly
  , run = run
  , true = true
  , false = false
  , runInDocker = runInDocker
  , inDocker = inDocker
  , cacheThrough = cacheThrough
  , format = format
  }

let tests =
  let M = module ["TEST"] in

  let dockerExample = assert :
  { line =
"docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag /bin/sh -c 'echo hello'"
  , readable =
    Some "Docker@foo/bar:tag ( echo hello )"
  }
  ===
    M.inDocker
      M.Docker::{
        image = "foo/bar:tag",
        extraEnv = [ "ENV1", "ENV2" ]
      }
      ( M.run "echo hello" )

  let cacheExample = assert :
''
  ./buildkite/scripts/cache-through.sh data.tar "docker run -it --rm --init --volume /var/buildkite/shared:/shared --volume /var/buildkite/builds/\$BUILDKITE_AGENT_NAME/\$BUILDKITE_ORGANIZATION_SLUG/\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag /bin/sh -c 'echo hello > /tmp/data/foo.txt && tar cvf data.tar /tmp/data'"''
  ===
  M.format (
    M.cacheThrough
      M.Docker::{
        image = "foo/bar:tag",
        extraEnv = [ "ENV1", "ENV2" ]
      }
      "data.tar"
      M.CacheSetupCmd::{
        create = M.run "echo hello > /tmp/data/foo.txt",
        package = M.run "tar cvf data.tar /tmp/data"
      }
  )
  in
  ""

in
module ../Constants/ContainerEnvVars.dhall

