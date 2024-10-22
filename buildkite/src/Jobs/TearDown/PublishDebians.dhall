let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Command = ../../Command/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let dependsOn = [] : List Command.TaggedKey.Type

let specBuilder =
          \(debVersion : DebianVersions.DebVersion)
      ->  ArtifactPipelines.MinaBuildSpec::{
          , channel = DebianChannel.Type.Unstable
          , prefix = "DebianPublish"
          , debVersion = debVersion
          }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
            DebianVersions.dirtyWhen DebianVersions.DebVersion.Bullseye
        , path = "TearDown"
        , name = "PublishDebians"
        , tags = [ PipelineTag.Type.TearDown ]
        , mode = PipelineMode.Type.Stable
        }
      , steps =
        [ ArtifactPipelines.publishToDebian
            (specBuilder DebianVersions.DebVersion.Bullseye)
            dependsOn
        , ArtifactPipelines.publishToDebian
            (specBuilder DebianVersions.DebVersion.Focal)
            dependsOn
        ]
      }
