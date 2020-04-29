let Prelude = ../External/Prelude.dhall

let Map = ../Lib/Map.dhall

let Shared =
    { Type =
        { command : List Text
        , label : Text
        , key : Text
        }
    , default = {=}
    }

let Config =
    { Type = Shared.Type  //\\
        { target : <Large | Small>
        , depends_on : List Text
        }
    , default = Shared.default /\ {
        depends_on = [] : List Text
      }
    }
in
let Result =
  { Type = Shared.Type //\\
    { agents : Optional (Map.Type Text)
    , depends_on : Optional (List Text)
    }
  , default = Shared.default /\ {
      depends_on = None (List Text)
    }
  }
in

let targetToAgent = \(target : <Large | Small>) ->
  merge { Large = [ { mapKey = "size", mapValue = "large" } ],
          Small = [ { mapKey = "size", mapValue = "small" } ]
        }
        target

let build : Config.Type -> Result.Type = \(c : Config.Type) ->
  {
    command = c.command,
    label = c.label,
    key = c.key,
    depends_on = if Prelude.List.null Text c.depends_on then None (List Text) else Some c.depends_on,
    agents =
      let agents = targetToAgent c.target in
      if Prelude.List.null (Map.Entry.Type Text) agents then None (Map.Type Text) else Some agents
  }

in {Config = Config, build = build} /\ Result

