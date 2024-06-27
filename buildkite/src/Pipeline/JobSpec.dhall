let SelectFiles = ../Lib/SelectFiles.dhall

let PipelineMode = ./Mode.dhall

let PipelineTag = ./Tag.dhall

in  { Type =
        { path : Text
        , name : Text
        , mode : PipelineMode.Type
        , tags : List PipelineTag.Type
        , dirtyWhen : List SelectFiles.Type
        }
    , default =
        { path = "."
        , mode = PipelineMode.Type.PullRequest
        , tags = [ PipelineTag.Type.Fast ]
        }
    }
