-- Commands are the individual command steps that CI runs

let Prelude = ../External/Prelude.dhall
let Map = Prelude.Map

let Docker = ./Docker.dhall
let Size = ./Size.dhall

let Shared =
    { Type =
        { command : List Text
        , label : Text
        , key : Text
        }
    , default = {=}
    }

-- Everything here is taken directly from the buildkite Command documentation
-- https://buildkite.com/docs/pipelines/command-step#command-step-attributes
-- except "target" replaces "agents"
--
-- Target is our explicit union of large or small instances. As we build more
-- complicated targeting rules we can replace this abstraction with something
-- more powerful.
let Config =
    let Typ = Shared.Type //\\
        { target : Size
        , depends_on : List Text
        , docker : Docker.Config.Type
        }
    let upcast : Typ -> Shared.Type =
      \(c : Typ) -> Shared::{
        command = c.command,
        label = c.label,
        key = c.key
      }
    in
    { Type = Typ
    , default = Shared.default /\ {
        depends_on = [] : List Text
      }
    , upcast = upcast
    }

-- The result type wraps our containers in optionals so that they are omitted
-- from the rendered yaml if they are empty.
let Result =
  { Type = Shared.Type //\\
    { agents : Optional (Map.Type Text Text)
    , depends_on : Optional (List Text)
    , plugins : Map.Type Text Docker.Type
    }
  , default = Shared.default /\ {
      depends_on = None (List Text)
    }
  }
in

let targetToAgent = \(target : Size) ->
  merge { Large = [ { mapKey = "size", mapValue = "large" } ],
          Small = [ { mapKey = "size", mapValue = "small" } ]
        }
        target

let build : Config.Type -> Result.Type = \(c : Config.Type) ->
  Config.upcast c /\ {
    depends_on = if Prelude.List.null Text c.depends_on then None (List Text) else Some c.depends_on,
    agents =
      let agents = targetToAgent c.target in
      if Prelude.List.null (Map.Entry Text Text) agents then None (Map.Type Text Text) else Some agents,
    plugins =
      [ { mapKey = "docker#v3.5.0"
      , mapValue = Docker.build c.docker
      } ]
  }

in {Config = Config, build = build} /\ Result

