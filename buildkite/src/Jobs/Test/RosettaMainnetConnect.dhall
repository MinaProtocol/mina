let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Profile = ../../Constants/Profiles.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Mainnet
          , profile = Profile.Type.Mainnet
          , timeout = 2400
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          , excludeIf =
            [ Expr.Type.DescendantOf
                { ancestor = MainlineBranch.Type.Develop
                , reason =
                    "Develop branch is incompatible with current mainnet network"
                }
            , Expr.Type.DescendantOf
                { ancestor = MainlineBranch.Type.Mesa
                , reason =
                    "Mesa branch is incompatible with current mainnet network"
                }
            ]
          }
      )
