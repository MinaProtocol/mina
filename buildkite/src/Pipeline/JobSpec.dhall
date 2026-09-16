let SelectFiles = ../Lib/SelectFiles.dhall

let PipelineTag = ./Tag.dhall

let Scope = ./Scope.dhall

let Expr = ./Expr.dhall

in  { Type =
        { path : Text
        , name : Text
        , scope : List Scope.Type
        , tags : List PipelineTag.Type
        , dirtyWhen : List SelectFiles.Type
        , excludeIf : List Expr.Type
        , includeIf : List Expr.Type
        }
    , default =
        { path = "."
        , scope = Scope.Full
        , tags = [ PipelineTag.Type.Fast ]
        , excludeIf = [] : List Expr.Type
        , includeIf = [] : List Expr.Type
        }
    }
