-- Mesa related helper functions --
let MainlineBranch = ../Pipeline/MainlineBranch.dhall

let Expr = ../Pipeline/Expr.dhall

let mesaBranch
    : MainlineBranch.Type
    = MainlineBranch.Type.Mesa

let forMesa
    : Expr.Type
    = Expr.Type.DescendantOf
        { ancestor = mesaBranch
        , reason = "This job is only relevant on Mesa mainline branches"
        }

let notForMesa
    : Expr.Type
    = Expr.Type.DescendantOf
        { ancestor = mesaBranch
        , reason = "This job is not applicable for Mesa mainline branches"
        }

in  { forMesa = forMesa, notForMesa = notForMesa }
