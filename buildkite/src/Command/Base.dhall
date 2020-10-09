-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall
let B = ../External/Buildkite.dhall

let Map = Prelude.Map
let List/map = Prelude.List.map
let List/concat = Prelude.List.concat
let Optional/map = Prelude.Optional.map
let Optional/toList = Prelude.Optional.toList

let B/Plugins/Partial = B.definitions/commandStep/properties/plugins/Type
-- Retry bits
let B/ExitStatus = B.definitions/automaticRetry/properties/exit_status/Type
let B/AutoRetryChunk = B.definitions/automaticRetry/Type.Type
let B/Retry = B.definitions/commandStep/properties/retry/properties/automatic/Type
let B/Manual = B.definitions/commandStep/properties/retry/properties/manual/Type

-- Job requirement/flake mgmt bits
let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type
let B/Skip = B.definitions/commandStep/properties/skip/Type

let Cmd = ../Lib/Cmds.dhall
let Decorate = ../Lib/Decorate.dhall
let SelectFiles = ../Lib/SelectFiles.dhall

let Docker = ./Docker/Type.dhall
let DockerLogin = ./DockerLogin/Type.dhall
let Summon= ./Summon/Type.dhall
let Size = ./Size.dhall

-- If you are adding a new type of plugin, stick it here
let Plugins =
  < Docker : Docker.Type
  | DockerLogin : DockerLogin.Type
  | Summon : Summon.Type
  >

let B/Command = B.definitions/commandStep/Type Text Text Plugins Plugins
let B/Plugins = B/Plugins/Partial Plugins Plugins

-- Depends on takes several layers of unions, but we can just choose the most
-- general of them
let B/DependsOn =
  let OuterUnion/Type = B.definitions/dependsOn/Type
  let InnerUnion/Type = B.definitions/dependsOn/union/Type
  in
  { Type = OuterUnion/Type,
    depends =
    \(keys : List Text) ->
        OuterUnion/Type.ListDependsOn/Type
          (List/map Text InnerUnion/Type (\(k: Text) -> InnerUnion/Type.DependsOn/Type { allow_failure = None Bool, step = Some k }) keys)
  }

let B/ArtifactPaths = B.definitions/commandStep/properties/artifact_paths/Type
let B/Env = B.definitions/commandStep/properties/env/Type

-- A type to make sure we don't accidentally forget the prefix on keys
let TaggedKey = {
  Type = {
    name : Text,
    key : Text
  },
  default = {=}
}

-- Retry requires you feed an exit status (as a string so we can support
-- negative codes), and optionally a limit to the number of times this command
-- should be retried.
let Retry = {
  Type = {
    exit_status : Integer,
    limit : Optional Natural
  },
  default = {
    limit = None Natural
  }
}

-- Everything here is taken directly from the buildkite Command documentation
-- https://buildkite.com/docs/pipelines/command-step#command-step-attributes
-- except "target" replaces "agents"
--
-- Target is our explicit union of large or small instances. As we build more
-- complicated targeting rules we can replace this abstraction with something
-- more powerful.
let Config =
  { Type =
      { commands : List Cmd.Type
      , depends_on : List TaggedKey.Type
      , artifact_paths : List SelectFiles.Type
      , env : List TaggedKey.Type
      , label : Text
      , key : Text
      , target : Size
      , docker : Optional Docker.Type
      , docker_login : Optional DockerLogin.Type
      , summon : Optional Summon.Type
      , retries : List Retry.Type
      , soft_fail : Optional B/SoftFail
      , skip: Optional B/Skip
      }
  , default =
    { depends_on = [] : List TaggedKey.Type
    , docker = None Docker.Type
    , docker_login = None DockerLogin.Type
    , summon = None Summon.Type
    , artifact_paths = [] : List SelectFiles.Type
    , env = [] : List TaggedKey.Type
    , retries = [] : List Retry.Type
    , soft_fail = None B/SoftFail
    , skip = None B/Skip
    }
  }

let targetToAgent = \(target : Size) ->
  merge { XLarge = toMap { size = "xlarge" },
          Large = toMap { size = "large" },
          Medium = toMap { size = "medium" },
          Small = toMap { size = "small" }
        }
        target

let build : Config.Type -> B/Command.Type = \(c : Config.Type) ->
  B/Command::{
    agents =
      let agents = targetToAgent c.target in
      if Prelude.List.null (Map.Entry Text Text) agents then None (Map.Type Text Text) else Some agents,
    commands =
      B.definitions/commandStep/properties/commands/Type.ListString (Decorate.decorateAll c.commands),
    depends_on =
      let flattened =
        List/map
          TaggedKey.Type
          Text
          (\(k : TaggedKey.Type) -> "_${k.name}-${k.key}")
          c.depends_on
      in
      if Prelude.List.null Text flattened then
        None B/DependsOn.Type
      else
        Some (B/DependsOn.depends flattened),
    artifact_paths = if Prelude.List.null SelectFiles.Type c.artifact_paths
                     then None B/ArtifactPaths
                     else Some (B/ArtifactPaths.String (SelectFiles.compile c.artifact_paths)),
    key = Some c.key,
    label = Some c.label,
    retry =
          Some {
              -- we only consider automatic retries
              automatic = Some (
                -- and for every retry
                let xs : List B/AutoRetryChunk =
                    List/map
                      Retry.Type
                      B/AutoRetryChunk
                      (\(retry : Retry.Type) ->
                      {
                        -- we always require the exit status
                        exit_status = Some (B/ExitStatus.Integer retry.exit_status),
                        -- but limit is optional
                        limit =
                          Optional/map
                          Natural
                          Integer
                          Natural/toInteger
                          retry.limit
                    })
                    -- per https://buildkite.com/docs/agent/v3#exit-codes, ensure automatic retries on -1 exit status (infra error)
                    ([Retry::{ exit_status = -1, limit = Some 2 }] #
                    -- and the retries that are passed in (if any)
                    c.retries)
                in
                B/Retry.ListAutomaticRetry/Type xs),
              manual = None B/Manual
          },
    soft_fail = c.soft_fail,
    skip = c.skip,
    plugins =
      let dockerPart =
        Optional/toList
          (Map.Type Text Plugins)
          (Optional/map
            Docker.Type
            (Map.Type Text Plugins)
            (\(docker: Docker.Type) ->
              toMap { `docker#v3.5.0` = Plugins.Docker docker })
            c.docker)
      let dockerLoginPart =
        Optional/toList
          (Map.Type Text Plugins)
          (Optional/map
            DockerLogin.Type
            (Map.Type Text Plugins)
            (\(dockerLogin: DockerLogin.Type) ->
              toMap { `docker-login#v2.0.1` = Plugins.DockerLogin dockerLogin })
            c.docker_login)
      let summonPart =
        Optional/toList
          (Map.Type Text Plugins)
          (Optional/map
            Summon.Type
            (Map.Type Text Plugins)
            (\(summon: Summon.Type) ->
              toMap { `angaza/summon#v0.1.0` = Plugins.Summon summon })
            c.summon)

      -- Add more plugins here as needed, empty list omits that part from the
      -- plugins map
      let allPlugins = List/concat (Map.Entry Text Plugins) (dockerPart # summonPart # dockerLoginPart) in
      if Prelude.List.null (Map.Entry Text Plugins) allPlugins then None B/Plugins else Some (B/Plugins.Plugins/Type allPlugins)
  }

in {Config = Config, build = build, Type = B/Command.Type, TaggedKey = TaggedKey}

