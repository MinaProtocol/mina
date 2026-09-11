let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let DaemonDockerSync = ../../Command/DaemonDockerSync.dhall

in  Pipeline.build
      ( DaemonDockerSync.pipeline
          DaemonDockerSync.Spec::{
          , network = Network.Type.Devnet
          , scope = PipelineScope.AllButPullRequest
          }
      )
