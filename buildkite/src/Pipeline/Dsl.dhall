-- A Pipeline is a series of build steps
--
-- Pipelines are rendered by separate invocations to dhall-to-yaml when our
-- monorepo triage step determines it be necessary.

let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map

let Command = ../Command/Base.dhall
let JobSpec = ./JobSpec.dhall
let Pipeline/Type = ./Type.dhall

-- We build a pipeline out of a spec and the commands in a step
let Config = {
  Type = {
    spec: JobSpec.Type,
    -- TODO: Union type with block steps
    steps: List Command.Config.Type
  },
  default = {=}
}

let build : Config.Type -> Pipeline/Type = \(c : Config.Type) ->
  let name = c.spec.name
  let buildCommand = \(c : Command.Config.Type) ->
    Command.build c // { key = Some "_${name}-${c.key}" }
  in
  { steps = List/map Command.Config.Type Command.Type buildCommand c.steps }

in {Config = Config, build = build, Type = Pipeline/Type}
