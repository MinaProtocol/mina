-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let List/concat = Prelude.List.concat
let Optional/map = Prelude.Optional.map
let Optional/toList = Prelude.Optional.toList
let B = ../External/Buildkite.dhall
let B/Plugins/Partial = B.definitions/commandStep/properties/plugins/Type
let Map = Prelude.Map

let Cmd = ../Lib/Cmds.dhall
let Decorate = ../Lib/Decorate.dhall
let SelectFiles = ../Lib/SelectFiles.dhall

let Docker = ./Docker/Type.dhall
let Summon= ./Summon/Type.dhall
let Size = ./Size.dhall

-- If you are adding a new type of plugin, stick it here
let Plugins =
  < Docker : Docker.Type
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
      , artifact_paths : List SelectFiles.Type
      , label : Text
      , key : Text
      , target : Size
      , docker : Optional Docker.Type
      , summon : Optional Summon.Type
      }
  , default =
    { depends_on = [] : List TaggedKey.Type
    , artifact_paths = [] : List SelectFiles.Type
    , docker = None Docker.Type
    , summon = None Summon.Type
    }
  }

let targetToAgent = \(target : Size) ->
  merge { Large = toMap { size = "large" },
          Small = toMap { size = "small" },
          Experimental = toMap { size = "experimental" }
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
      let dockerPart =
        Optional/toList
          (Map.Type Text Plugins)
          (Optional/map
            Docker.Type
            (Map.Type Text Plugins)
            (\(docker: Docker.Type) ->
              toMap { `docker#v3.5.0` = Plugins.Docker docker })
            c.docker)
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
      let allPlugins = List/concat (Map.Entry Text Plugins) (dockerPart # summonPart) in
      if Prelude.List.null (Map.Entry Text Plugins) allPlugins then None B/Plugins else Some (B/Plugins.Plugins/Type allPlugins)
  }

in {Config = Config, build = build, Type = B/Command.Type, TaggedKey = TaggedKey}

