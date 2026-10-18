let MainlineBranch = ./MainlineBranch.dhall

let Expr = < DescendantOf : { ancestor : MainlineBranch.Type, reason : Text } >

in  { Type = Expr }
