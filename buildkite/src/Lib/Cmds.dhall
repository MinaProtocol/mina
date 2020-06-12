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

  let binop : Text -> List Cmd -> Cmd =
    \(op : Text) ->
    \(cmds : List Cmd) ->
    let encodedLine : Text =
      Text/concatSep
        " ${op} "
        (List/map Cmd Text (\(cmd : Cmd) -> cmd.line) cmds)
    let encodedReadable : Optional Text =
      -- skip over the quiet commands
      let xs =
        List/concatMap Cmd Text
          (\(cmd : Cmd) ->
            Optional/toList
              Text
              cmd.readable)
          cmds
      in

      if P.List.null Text xs then
        None Text
      else
        Some (
          Text/concatSep
            " ${op} "
            xs
        )
    in
    { line = "( ${encodedLine} )"
    , readable = Optional/map Text Text (\(txt : Text) -> "( ${txt} )") encodedReadable
    }

  let seq = binop ";"
  let and = binop "&&"
  let or = binop "||"

  let exampleVeryQuiet = assert :
    (None Text) === (and [ quietly "a", quietly "b" ]).readable
  let exampleTwoQuiet = assert :
    (Some "( a && d )") === (and [ run "a", quietly "b", quietly "c", run "d" ]).readable


  let inDocker : Docker.Type -> Cmd -> Cmd =
    \(docker : Docker.Type) ->
    \(inner : Cmd) ->
    let envVars =
      P.Text.concatMap
        Text
        (\(var : Text) -> " --env ${var}")
        (docker.extraEnv # environment)
    let outerDir : Text =
      "/var/buildkite/builds/\$BUILDKITE_AGENT_NAME/\$BUILDKITE_ORGANIZATION_SLUG/\$BUILDKITE_PIPELINE_SLUG"
    in
    { line = "docker run -it --rm --init --volume ${outerDir}:/workdir --workdir /workdir${envVars} ${docker.image} bash -c '${inner.line}'"
    , readable = Optional/map Text Text (\(readable : Text) -> "Docker@${docker.image} ( ${readable} )") inner.readable
    }

  let runInDocker : Docker.Type -> Text -> Cmd =
    \(docker : Docker.Type) ->
    \(script : Text) ->
    inDocker docker (run script)

  -- Handles the ugly workdir prefix for you
  let load : Text -> Cmd =
    \(path : Text) ->
    run "buildkite-agent artifact download ${path} ."
  let store : Text -> Cmd =
    \(path : Text) ->
    run "buildkite-agent artifact upload ${path} gs://buildkite_k8s/coda/shared"

  let CompoundCmd = {
    Type = {
      preprocess : Cmd,
      postprocess : Cmd,
      inner : Cmd
    },
    default = {=}
  }

  -- Loads through cache, innards with docker, buildkite-agent interactions outside
  let cacheThrough : Docker.Type -> Text -> CompoundCmd.Type -> Cmd =
    \(docker : Docker.Type) ->
    \(cachePath : Text) ->
    \(cmd : CompoundCmd.Type) ->
    and [
      seq [
        or [ load cachePath, true ],
        inDocker
          docker
          (or [ cmd.preprocess, cmd.inner, cmd.postprocess ])
      ],
      store cachePath
    ]

  let format : Cmd -> Text =
    \(cmd : Cmd) -> cmd.line

  in

  { Type = Cmd
  , Docker = Docker
  , CompoundCmd = CompoundCmd
  , quietly = quietly
  , run = run
  , seq = seq
  , and = and
  , true = true
  , false = false
  , or = or
  , runInDocker = runInDocker
  , inDocker = inDocker
  , cacheThrough = cacheThrough
  , load = load
  , store = store
  , format = format
  }

let tests =
  let M = module ["TEST"] in

  let dockerExample = assert :
  { line =
"docker run -it --rm --init --volume /var/buildkite/builds/$BUILDKITE_AGENT_NAME/$BUILDKITE_ORGANIZATION_SLUG/$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag bash -c '( echo hello && echo hello2 )'"
  , readable =
    Some "Docker@foo/bar:tag ( ( echo hello ) )"
  }
  ===
    M.inDocker
      M.Docker::{
        image = "foo/bar:tag",
        extraEnv = [ "ENV1", "ENV2" ]
      }
      (M.and [ M.run "echo hello", M.quietly "echo hello2" ])

  let combinators = assert :
''
  ( ( echo "hello" || echo "goodbye" || echo "oh well" ) && echo "and then" )''
===
  M.format (
    M.and [
      M.or [
        M.run "echo \"hello\"",
        M.run "echo \"goodbye\"",
        M.run "echo \"oh well\""
      ],
      M.run "echo \"and then\""
    ]
  )

  let cacheExample = assert :
''
  ( ( ( buildkite-agent artifact download data.tar . || true ) ; docker run -it --rm --init --volume /var/buildkite/builds/$BUILDKITE_AGENT_NAME/$BUILDKITE_ORGANIZATION_SLUG/$BUILDKITE_PIPELINE_SLUG:/workdir --workdir /workdir --env ENV1 --env ENV2 --env TEST foo/bar:tag bash -c '( tar cvf data.tar /tmp/data || echo hello > /tmp/data/foo.txt || tar xvf data.tar -C /tmp/data )' ) && buildkite-agent artifact upload data.tar gs://buildkite_k8s/coda/shared )''
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

