-- Promote Nightly
--
-- Standalone entrypoint that promotes nightly build artifacts (Debian packages
-- and Docker images). Designed to run as a separate pipeline invoked hours after
-- the nightly build completes. Uses the nightly-promoter Go binary to:
--   1. Find the latest nightly build via Buildkite API
--   2. Verify all packaging jobs passed
--   3. Compute source/target versions from git
--   4. Call manager.sh publish to promote artifacts
--
-- All commands run in a single step so they share the same agent/filesystem.
-- The Go binary is built inside Docker (has Go).
-- Debian publish runs inside Docker (needs GPG, deb-s3, AWS creds).
-- Docker publish runs on the host (needs Docker daemon).

let Cmd = ../Lib/Cmds.dhall

let Command = ../Command/Base.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let FixPermissions = ../Command/FixPermissions.dhall

let Architecture = ../Constants/Arch.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

let Size = ../Command/Size.dhall

let promote_nightly =
          \(branch : Text)
      ->  \(profile : Text)
      ->  \(channel : Text)
      ->  \(force : Bool)
      ->  let forceFlag = if force then " --force" else ""

          let promoterBin =
                    "./buildkite/scripts/pipeline/bin/nightly-promoter"
                ++  " --branch ${branch}"
                ++  " --profile ${profile}"
                ++  " --channel ${channel}"
                ++  forceFlag

          let buildGoBinaryCmd =
                Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.minaToolchain
                  , extraEnv = [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                  , privileged = True
                  , useRoot = True
                  }
                  "cd buildkite/scripts/pipeline && make build-nightly-promoter"

          let publishDebiansCmd =
                Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.minaToolchain
                  , extraEnv = [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                  , privileged = True
                  , useRoot = True
                  }
                  (     "git config --global --add safe.directory /workdir && "
                    ++  ". ./buildkite/scripts/export-git-env-vars.sh && "
                    ++  "gpg --import /var/secrets/debian/key.gpg && "
                    ++  "mkdir -p ./cache && "
                    ++  "DEBIAN_CACHE_FOLDER=/workdir/cache "
                    ++  promoterBin
                    ++  " --only-debians"
                  )

          let publishDockersCmd =
                Cmd.run
                  (     ". ./buildkite/scripts/export-git-env-vars.sh && "
                    ++  promoterBin
                    ++  " --only-dockers"
                  )

          let pipeline =
                Pipeline.build
                  Pipeline.Config::{
                  , spec = JobSpec::{
                    , dirtyWhen = [ SelectFiles.everything ]
                    , path = "Entrypoints"
                    , name = "PromoteNightly"
                    , tags = [ PipelineTag.Type.Promote ]
                    }
                  , steps =
                    [ Command.build
                        Command.Config::{
                        , commands =
                              [ FixPermissions.command Architecture.Type.Amd64 ]
                            # [ buildGoBinaryCmd ]
                            # [ publishDebiansCmd ]
                            # [ publishDockersCmd ]
                        , label = "Promote Nightly (${branch}/${profile})"
                        , key = "promote-nightly-${branch}-${profile}"
                        , target = Size.Small
                        }
                    ]
                  }

          in  pipeline.pipeline

in  { promote_nightly = promote_nightly }
