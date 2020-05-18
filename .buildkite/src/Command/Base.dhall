-- This component hides the "useless" parts of the Buildkite command step bindings

let Prelude = ../External/Prelude.dhall
let Map = Prelude.Map
let B = ../External/Buildkite.dhall
in

\(plugin : Type) ->

let B/Command = B.definitions/commandStep/Type Text Text plugin plugin

let Config = {
  Type = {
    agents : Optional (Map.Type Text Text),
    artifact_paths : Optional (B.definitions/commandStep/properties/artifact_paths/Type),
    branches : Optional (B.definitions/commandStep/properties/branches/Type),
    commands : Optional (B.definitions/commandStep/properties/commands/Type),
    depends_on : Optional (B.definitions/commandStep/properties/depends_on/Type),
    `env` : Optional (Map.Type Text Text),
    `if` : Optional Text,
    key : Optional Text,
    label : Optional Text,
    plugins : Optional (B.definitions/commandStep/properties/plugins/Type plugin plugin),
    retry : Optional (B.definitions/commandStep/properties/retry/Type),
    timeout_in_minutes : Optional Natural
  },
  default = {
    artifact_paths = None (B.definitions/commandStep/properties/artifact_paths/Type),
    branches = None (B.definitions/commandStep/properties/branches/Type),
    `env` = None (Map.Type Text Text),
    `if` = None Text,
    retry = None (B.definitions/commandStep/properties/retry/Type),
    timeout_in_minutes = None Natural
  }
}

let build : Config.Type -> B/Command = \(c : Config.Type) ->
  c //
    { allow_dependency_failure = None Bool,
      command = None (B.definitions/commandStep/properties/command/Type),
      concurrency = None Natural,
      concurrency_group = None Text,
      `id` = None Text,
      identifier = None Text,
      name = None Text,
      parallelism = None Natural,
      skip = None (B.definitions/commandStep/properties/skip/Type),
      soft_fail = None (B.definitions/commandStep/properties/soft_fail/Type),
      type = None Text
    }

in {build = build, Config = Config, Type = B/Command}
