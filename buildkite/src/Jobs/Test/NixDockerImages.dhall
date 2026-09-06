-- Build the daemon/archive docker images with Nix and save them to the shared
-- CI cache, as an alternative to IntegrationTestDockerImages building them from
-- freshly-built Debian packages.
--
-- Nothing consumes these images: the script writes them under <service>-nix, so
-- this runs alongside the .deb-built ones without disturbing anything. The job
-- exists to keep the nix image definitions honest -- that they build at all,
-- carry no config, satisfy the daemon runtime contract (entrypoint + puppeteer
-- scripts) and land in the cache in a loadable shape.
--
-- Runs in the nixos container like NixBuildTest, and needs the same nix binary
-- cache credentials, otherwise it would compile mina from scratch.
--
-- dirtyWhen covers what the images are built out of: the nix expressions, the
-- scripts, and the entrypoint/puppeteer scripts nix/docker.nix copies in from
-- dockerfiles/. default.nix and opam.export need entries of their own, being
-- neither under nix/ nor caught by any prefix here. Deliberately not src/: the
-- binaries come out of the shared nix cache and nothing consumes these images,
-- so rebuilding them on every source change would put an XLarge job back onto
-- PRs for no gain.
--
-- depends_on NixBuildTest because that job is what puts .#devnet into the shared
-- cache -- it builds it and `nix copy`s the result up. A nightly runs on a
-- commit whose sources have moved, so those paths reach the cache only once it
-- has finished; running the two concurrently would leave this one compiling
-- mina from scratch on an XLarge agent instead of fetching it.

let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "dockerfiles")
          , S.strictlyStart (S.contains "nix")
          , S.exactly "flake" "nix"
          , S.exactly "flake" "lock"
          , S.exactly "default" "nix"
          , S.exactly "opam" "export"
          , S.strictlyStart (S.contains "buildkite/scripts/nix")
          , S.exactly "buildkite/src/Jobs/Test/NixDockerImages" "dhall"
          ]
        , path = "Test"
        , name = "NixDockerImages"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Docker
          ]
        , scope = [ PipelineScope.Type.PullRequest, PipelineScope.Type.Nightly ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.nixos
                  , privileged = True
                  , useBash = False
                  }
                  "./buildkite/scripts/nix/build-images.sh"
              ]
            , label = "Build daemon/archive docker images with Nix"
            , key = "nix-docker-images"
            , target = Size.XLarge
            , depends_on =
              [ { name = "NixBuildTest", key = "nix-build-tests" } ]
            }
        ]
      }
