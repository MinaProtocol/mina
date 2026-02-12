let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Devnet
          , scope = PipelineScope.AllButPullRequest
          , excludeIf =
            [ Expr.Type.DescendantOf
                { ancestor = MainlineBranch.Type.Develop
                , reason =
                    "Develop branch is incompatible with current devnet network"
                }
            , Expr.Type.DescendantOf
                { ancestor = MainlineBranch.Type.Mesa
                , reason =
                    "Mesa branch is incompatible with current devnet network"
                }
            ]
          }
      )
