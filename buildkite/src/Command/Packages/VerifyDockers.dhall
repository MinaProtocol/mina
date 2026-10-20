-- Check a docker image that the same job just built, in the local daemon.
--
-- The image is named by the ID build.sh wrote to imageRefFile, so no tag is
-- recomputed here and nothing is pulled: the check covers exactly the bytes
-- that were built.

let Docker = ../../Constants/Docker/Package.dhall

let Arch = ../../Constants/Arch.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let Spec =
      { Type = { service : Docker.Type, arch : Arch.Type, imageRefFile : Text }
      , default = {=}
      }

let verify
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->      "RELEASE_TOOLKIT_VERSION=${ContainerImages.minaReleaseToolkitVersion} "
          ++  "./buildkite/scripts/release/release-manager.sh docker verify "
          ++  "--image \\\$(cat ${spec.imageRefFile}) "
          ++  "--package ${Docker.dockerName spec.service} "
          ++  "--check-scripts-dir scripts/verify "
          ++  "--arch ${Arch.lowerName spec.arch} "
          ++  "--no-pull"

in  { verify = verify, Spec = Spec }
