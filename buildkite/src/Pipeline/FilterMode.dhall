-- Mode defines pipeline filter fetch mode

let Mode = < Any | All >

in  { Type = Mode
    , any = \(mode : Mode) -> merge { Any = True, All = False } mode
    , all = \(mode : Mode) -> merge { Any = False, All = True } mode
    }
