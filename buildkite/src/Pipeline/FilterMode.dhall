-- Mode defines pipeline filter fetch mode

let Mode = < Any | All >

let show = \(mode : Mode) -> merge { Any = "any", All = "all" } mode

in  { Type = Mode, show = show }
