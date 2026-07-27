-- Selects the published `mina-base` image for a (codename, arch) pair, mirroring
-- Constants/Toolchain.dhall's imageFor for the toolchain image.
--
-- Consumers pass the result as DockerImage.ReleaseSpec.base_image, which makes
-- the docker step preload it from the CI cache (load_from_cache.sh) and hand it
-- to build.sh --base-image, so a staged build reuses the published base-deps
-- layer instead of re-running apt-get update/upgrade + the gcloud SDK download.
--
-- The reference is a frozen pin, exactly like minaToolchain*: bump it in
-- ContainerImages.dhall when the base is re-published. Nothing breaks while a
-- pin is stale or not yet published -- build.sh falls back to inlining the
-- base-deps fragment when the image is not available locally -- so the only
-- cost of a stale pin is the lost reuse.

let ContainerImages = ../ContainerImages.dhall

let DebianVersions = ../DebianVersions.dhall

let Arch = ../Arch.dhall

let imageFor
    : DebianVersions.DebVersion -> Arch.Type -> Text
    =     \(debVersion : DebianVersions.DebVersion)
      ->  \(arch : Arch.Type)
      ->  merge
            { Bookworm =
                merge
                  { Amd64 = ContainerImages.minaBaseBookworm.amd64
                  , Arm64 = ContainerImages.minaBaseBookworm.arm64
                  }
                  arch
            , Bullseye = ContainerImages.minaBaseBullseye.amd64
            , Jammy = ContainerImages.minaBaseJammy.amd64
            , Focal = ContainerImages.minaBaseFocal.amd64
            , Noble = ContainerImages.minaBaseNoble.amd64
            , Trixie = ContainerImages.minaBaseTrixie.amd64
            }
            debVersion

in  { imageFor = imageFor }
