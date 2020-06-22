-- A DSL for manipulating commands and their execution environments
let Prelude = ../External/Prelude.dhall
let P = Prelude
let List/map = P.List.map
let Optional/toList = P.Optional.toList
let Optional/map = P.Optional.map
let List/concatMap = P.List.concatMap
let Text/concatSep = P.Text.concatSep

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
      P.Text.concatMap
        Text
        (\(var : Text) -> " --env ${var}")
        (docker.extraEnv # environment)
    let outerDir : Text =
      "/var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG"
    in
    { line = "docker run -it --rm --init --volume ${outerDir}:/workdir --workdir /workdir${envVars} ${docker.image} /bin/sh -c '${inner.line}'"
    , readable = Optional/map Text Text (\(readable : Text) -> "Docker@${docker.image} ( ${readable} )") inner.readable
    }

  let runInDocker : Docker.Type -> Text -> Cmd =
    \(docker : Docker.Type) ->
    \(script : Text) ->
    inDocker docker (run script)

  let CompoundCmd = {
    Type = {
      preprocess : Cmd,
      postprocess : Cmd,
      inner : Cmd
    },
    default = {=}
  }

  let format : Cmd -> Text =
    \(cmd : Cmd) -> cmd.line

  -- Loads through cache, innards with docker, buildkite-agent interactions outside
  let cacheThrough : Docker.Type -> Text -> CompoundCmd.Type -> Cmd =
    \(docker : Docker.Type) ->
    \(cachePath : Text) ->
    \(cmd : CompoundCmd.Type) ->
      let script =
        "( ${format cmd.postprocess} || true ) && " ++
        ( format cmd.inner ) ++ " && " ++
        ( format cmd.preprocess )
      in
      let cmd =
        runInDocker docker script
      in
      { line = "./buildkite/scripts/cache-through.sh ${cachePath} \"${format ( runInDocker docker script )}\""
      , readable = Optional/map Text Text (\(readable : Text) -> "Cache@${cachePath} ( ${readable} ) ") cmd.readable
      }
  in

  { Type = Cmd
  , Docker = Docker
  , CompoundCmd = CompoundCmd
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
"docker run -it --rm --init --volume /var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag /bin/sh -c 'echo hello'"
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
  ./buildkite/scripts/cache-through.sh data.tar "docker run -it --rm --init --volume /var/buildkite/builds/\$BUILDKITE_AGENT_NAME/\$BUILDKITE_ORGANIZATION_SLUG/\$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag /bin/sh -c '( tar xvf data.tar -C /tmp/data || true ) && echo hello > /tmp/data/foo.txt && tar cvf data.tar /tmp/data'"''
===
  M.format (
    M.cacheThrough
      M.Docker::{
        image = "foo/bar:tag",
        extraEnv = [ "ENV1", "ENV2" ]
      }
      "data.tar"
      M.CompoundCmd::{
        preprocess = M.run "tar cvf data.tar /tmp/data",
        postprocess = M.run "tar xvf data.tar -C /tmp/data",
        inner = M.run "echo hello > /tmp/data/foo.txt"
      }
  )
  in
  ""

in
module ../Constants/ContainerEnvVars.dhall

