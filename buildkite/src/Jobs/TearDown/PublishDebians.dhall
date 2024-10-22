let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Command = ../../Command/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let name = "PublishDebians"

let dependsOnCodename =
          \(codename : DebianVersions.DebVersion)
      ->  [ { name = name
            , key = "publish-${DebianVersions.lowerName codename}-deb-pkg"
            }
          ]

let specBuilder =
          \(debVersion : DebianVersions.DebVersion)
      ->  ArtifactPipelines.MinaBuildSpec::{
          , channel = DebianChannel.Type.Unstable
          , prefix = name
          , debVersion = debVersion
          }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
            DebianVersions.dirtyWhen DebianVersions.DebVersion.Bullseye
        , path = "TearDown"
        , name = name
        , tags = [ PipelineTag.Type.TearDown ]
        , mode = PipelineMode.Type.Stable
        }
      , steps =
        [ ArtifactPipelines.publishToDebian
            (specBuilder DebianVersions.DebVersion.Bullseye)
            ([] : List Command.TaggedKey.Type)
        , ArtifactPipelines.publishToDebian
            (specBuilder DebianVersions.DebVersion.Focal)
            (dependsOnCodename DebianVersions.DebVersion.Bullseye)
        ]
      }
