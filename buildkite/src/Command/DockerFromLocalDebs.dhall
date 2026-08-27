-- Bottom-to-top image builds: package the debs an image needs out of the
-- app-build binaries, then build the image locally, all inside the job that
-- consumes it.
--
-- This is the counterpart to Command/DockerImage.dhall. DockerImage builds the
-- shared, published artifacts in the packaging job; everything downstream then
-- depends on those steps, which is why selecting one test drags the whole
-- Debian + Docker build into a PR. A job that only needs an image for its own
-- assertions can use this instead and depend on nothing but the apps build.
--
-- A caller assembles one step out of:
--   MinaArtifact.buildDebianFromApps  -- toolchain: debs from the apps cache
--   DockerFromLocalDebs.buildImages   -- agent: one image per Spec, --load-only
--
-- Both halves are ordinary commands in the same Buildkite step, so the .deb
-- files the first writes to _build/ are still there for the second.
--
-- See buildkite/scripts/docker/build-from-local-debs.sh for what actually runs.

let Prelude = ../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let List/map = Prelude.List.map

let Cmd = ../Lib/Cmds.dhall

let Docker = ../Constants/Docker/Package.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let Network = ../Constants/Network.dhall

let Profiles = ../Constants/Profiles.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let script = "./buildkite/scripts/docker/build-from-local-debs.sh"

let ciDockerCacheMountedRoot = "/var/storagebox/docker-cache"

let Spec =
      { Type =
          { service : Docker.Type
          , network : Network.Type
          , profile : Profiles.Type
          , dockerRepo : DockerRepo.Type
          , baseImage : Optional Text
          , legacyVersion : Optional Text
          , saveToCiCache : Bool
          }
      , default =
          { network = Network.Type.Devnet
          , profile = Profiles.Type.Devnet
          , dockerRepo = DockerRepo.Type.InternalEurope
          , baseImage = None Text
          , legacyVersion = None Text
          , saveToCiCache = False
          }
      }

let optionalArg =
          \(flag : Text)
      ->  \(value : Optional Text)
      ->  merge { Some = \(v : Text) -> " ${flag} ${v}", None = "" } value

let buildImage
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->      script
          ++  " --service ${Docker.serviceName spec.service}"
          ++  " --network ${Network.lowerName spec.network}"
          ++  " --profile ${Profiles.lowerName spec.profile}"
          ++  " --docker-registry ${DockerRepo.show spec.dockerRepo}"
          ++  optionalArg "--base-image" spec.baseImage
          ++  optionalArg "--legacy-version" spec.legacyVersion
          ++  (       if Docker.isGeneric spec.service

                then  " --deb-suffix generic"

                else  ""
              )
          ++  (       if spec.saveToCiCache

                then  " --save-to-ci-cache ${ciDockerCacheMountedRoot}"

                else  ""
              )

let buildImages
    : DebianVersions.DebVersion -> List Spec.Type -> Cmd.Type
    =     \(debVersion : DebianVersions.DebVersion)
      ->  \(specs : List Spec.Type)
      ->  Cmd.run
            (     "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                debVersion}"
              ++  " && export BRANCH_NAME=\\\${BUILDKITE_BRANCH}"
              ++  " && source ./buildkite/scripts/export-git-env-vars.sh && "
              ++  Text/concatSep
                    " && "
                    (List/map Spec.Type Text buildImage specs)
            )

in  { Spec = Spec, buildImage = buildImage, buildImages = buildImages }
