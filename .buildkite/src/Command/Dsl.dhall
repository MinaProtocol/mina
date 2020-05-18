-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let B = ../External/Buildkite.dhall
let B/Plugins/Partial = B.definitions/commandStep/properties/plugins/Type
let Map = Prelude.Map

let Docker = ./Docker/Type.dhall

let Command/Base/Partial = ./Base.dhall
let Command/Docker = ./Docker/Dsl.dhall
let Size = ./Size.dhall

-- We assume we're only using the Docker plugin for now
let Command/Base = Command/Base/Partial Docker.Type
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

-- Everything here is taken directly from the buildkite Command documentation
-- https://buildkite.com/docs/pipelines/command-step#command-step-attributes
-- except "target" replaces "agents"
--
-- Target is our explicit union of large or small instances. As we build more
-- complicated targeting rules we can replace this abstraction with something
-- more powerful.
let Config =
  { Type =
      { commands : List Text
      , depends_on : List Text
      , label : Text
      , key : Text
      , target : Size
      , docker : Command/Docker.Config.Type
      }
  , default = {
      depends_on = [] : List Text
    }
  }

let targetToAgent = \(target : Size) ->
  merge { Large = toMap { size = "large" },
          Small = toMap { size = "small" }
        }
        target

let build : Config.Type -> Command/Base.Type = \(c : Config.Type) ->
  Command/Base.build Command/Base.Config::{
    agents =
      let agents = targetToAgent c.target in
      if Prelude.List.null (Map.Entry Text Text) agents then None (Map.Type Text Text) else Some agents,
    commands = Some (B.definitions/commandStep/properties/commands/Type.ListString c.commands),
    depends_on = if Prelude.List.null Text c.depends_on then
        None B/DependsOn.Type
      else
        Some (B/DependsOn.depends c.depends_on),
    key = Some c.key,
    label = Some c.label,
    plugins =
      Some (B/Plugins.Plugins/Type (toMap { `docker#v3.5.0` = Command/Docker.build c.docker }))
  }

in {Config = Config, build = build, Type = Command/Base.Type}

