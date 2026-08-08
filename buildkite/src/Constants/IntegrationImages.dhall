-- The docker images the local-engine integration tests run against, and the
-- Buildkite steps that produce them.
--
-- Single source of truth shared by the producer (Jobs/Test/IntegrationTestDockerImages)
-- and its consumers (Jobs/Test/TestnetIntegrationTests, ...Long). The step keys
-- used to be spelled out as string literals on the consumer side, which is how
-- TestnetIntegrationTestsLong ended up pointing at the packaging job's docker
-- steps instead: nothing tied the two ends together, so they drifted.
--
-- Keys are derived from DockerImage.stepKey, the same function that names the
-- producer's steps, so a rename cannot desynchronise them.

let Command = ../Command/Base.dhall

let DockerImage = ../Command/DockerImage.dhall

let Docker = ./Docker/Package.dhall

let DebianVersions = ./DebianVersions.dhall

let Network = ./Network.dhall

let Profiles = ./Profiles.dhall

let Size = ../Command/Size.dhall

let producerJob = "IntegrationTestDockerImages"

let network = Network.Type.Devnet

let profile = Profiles.Type.Devnet

let debVersion = DebianVersions.DebVersion.Bullseye

let keySpec =
          \(service : Docker.Type)
      ->  DockerImage.ReleaseSpec::{
          , service = service
          , network = network
          , deb_codename = debVersion
          , deb_profile = profile
          , size = Size.XLarge
          }

let daemonService = Docker.Type.DaemonProfiled { profile = profile }

let archiveService = Docker.Type.Archive { network = network }

let services = [ daemonService, archiveService ]

let dependsOn
    : List Command.TaggedKey.Type
    = [ { name = producerJob
        , key = DockerImage.stepKey (keySpec daemonService)
        }
      , { name = producerJob
        , key = DockerImage.stepKey (keySpec archiveService)
        }
      ]

in  { producerJob = producerJob
    , network = network
    , profile = profile
    , debVersion = debVersion
    , keySpec = keySpec
    , daemonService = daemonService
    , archiveService = archiveService
    , services = services
    , dependsOn = dependsOn
    }
