-- Publish the .deb files this build produced, exactly as they were built.
--
-- The packaging jobs write their output into the CI cache and stop there.
-- This reads that output back and hands it to `release-manager publish`,
-- which uploads it and then asks the repository, package by package, whether
-- each one is really listed at the version and architecture it was built
-- with.
--
-- Nothing is rewritten on the way. The version comes from the git tag the
-- build was made from and the `Suite:` field was written at packaging time
-- from the same MINA_RELEASE_CHANNEL this step publishes into, so the package
-- that reaches the repository is the package that was tested. That is the
-- whole point of dropping the promotion step: `release-manager
-- publish-from-cache` still exists for the flows that genuinely need a
-- rewrite.
--
-- Ordering is the pipeline's job, not this file's. A release pipeline uploads
-- the packaging stage, waits, then uploads this one, so a failed test or a
-- failed package build means this step is never reached.

let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

let Text/concatSep = Prelude.Text.concatSep

let Cmd = ../../Lib/Cmds.dhall

let Command = ../Base.dhall

let Size = ../Size.dhall

let FixPermissions = ../FixPermissions.dhall

let Arch = ../../Constants/Arch.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Spec =
      { Type =
          { codenames : List DebianVersions.DebVersion
          , channel : DebianChannel.Type
          , debianRepo : DebianRepo.Type
          , verify : Bool
          , label : Text
          , key : Text
          }
      , default =
          { codenames = [ DebianVersions.DebVersion.Bullseye ]
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          , verify = True
          , label = "Publish debians"
          , key = "publish-debians"
          }
      }

let debsFolder = "_publish"

let readFromCache
    : Spec.Type -> List Cmd.Type
    =
      -- One read per codename, into its own folder.
      --
      -- read_all_from_cache.sh puts the packages of ONE codename flat into
      -- LOCAL_DEB_FOLDER, and `release-manager publish` wants a
      -- {codename}/*.deb tree, so the codename is the folder rather than
      -- something the publish step has to reconstruct from file names.
          \(spec : Spec.Type)
      ->  List/map
            DebianVersions.DebVersion
            Cmd.Type
            (     \(codename : DebianVersions.DebVersion)
              ->  let lower = DebianVersions.lowerName codename

                  in  Cmd.run
                        (     "MINA_DEB_CODENAME=${lower}"
                          ++  " ROOT=\\\${BUILDKITE_BUILD_ID}"
                          ++  " LOCAL_DEB_FOLDER=${debsFolder}/${lower}"
                          ++  " ./buildkite/scripts/debian/read_all_from_cache.sh"
                        )
            )
            spec.codenames

let publishCmd
    : Spec.Type -> Cmd.Type
    =     \(spec : Spec.Type)
      ->  let codenames =
                Text/concatSep
                  ","
                  ( List/map
                      DebianVersions.DebVersion
                      Text
                      DebianVersions.lowerName
                      spec.codenames
                  )

          let verifyArg = if spec.verify then " --verify" else ""

          let signArg =
                merge
                  { Some = \(key : Text) -> " --debian-sign-key ${key}"
                  , None = ""
                  }
                  (DebianRepo.keyId spec.debianRepo)

          in  Cmd.runInDocker
                Cmd.Docker::{
                , image = ContainerImages.minaReleaseToolkit
                , extraEnv = [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                , privileged = True
                , useRoot = True
                }
                (     "git config --global --add safe.directory /workdir && "
                  ++  ". ./buildkite/scripts/export-git-env-vars.sh && "
                  ++  "gpg --import /var/secrets/debian/key.gpg && "
                  ++  "release-manager publish"
                  ++  " --source-folder ${debsFolder}"
                  ++  " --codenames ${codenames}"
                  ++  " --channel ${DebianChannel.effective spec.channel}"
                  ++  " --debian-repo ${DebianRepo.bucket_or_default
                                          spec.debianRepo}"
                  ++  signArg
                  ++  verifyArg
                )

let step
    -- NOTE: Command.Base prepends automatic retries for infrastructure exit
    -- codes (255 agent lost, 143 SIGTERM, ...) and a job can only add to that
    -- list, not remove from it. Uploading is not idempotent: `release-manager
    -- publish` passes --fail-if-exists, so a retry after a partial upload
    -- fails with "package already exists" rather than finishing the job. That
    -- is a loud, safe failure -- nothing is overwritten and nothing is
    -- silently half-published -- but it needs a human. The real fix is to make
    -- publish idempotent (an identical package already present is success),
    -- which belongs in release-manager.
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  [ FixPermissions.command Arch.Type.Amd64 ]
                # readFromCache spec
                # [ publishCmd spec ]
            , label = spec.label
            , key = spec.key
            , target = Size.Small
            }

in  { Type = Spec.Type, Spec = Spec, step = step, debsFolder = debsFolder }
