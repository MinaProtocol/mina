-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let Optional/map = Prelude.Optional.map
let B = ../External/Buildkite.dhall
let B/Plugins/Partial = B.definitions/commandStep/properties/plugins/Type
let Map = Prelude.Map

let Cmd = ../Lib/Cmds.dhall
let Decorate = ../Lib/Decorate.dhall

let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

-- We assume we're only using the Docker plugin for now
let B/Command = B.definitions/commandStep/Type Text Text Docker.Type Docker.Type
let B/Plugins = B/Plugins/Partial Docker.Type Docker.Type

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

-- A type to make sure we don't accidentally forget the prefix on keys
let TaggedKey = {
  Type = {
    name : Text,
    key : Text
  },
  default = {=}
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
      , label : Text
      , key : Text
      , target : Size
      , docker : Optional Docker.Type
      }
  , default =
    { depends_on = [] : List TaggedKey.Type
    , docker = None Docker.Type
    }
  }

let targetToAgent = \(target : Size) ->
  merge { Large = toMap { size = "large" },
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
    key = Some c.key,
    label = Some c.label,
    plugins =
      Optional/map Docker.Type B/Plugins (\(docker: Docker.Type) -> B/Plugins.Plugins/Type (toMap { `docker#v3.5.0` = docker })) c.docker
  }

in {Config = Config, build = build, Type = B/Command.Type, TaggedKey = TaggedKey}

