let Prelude = ../../External/Prelude.dhall

let Package = ./Package.dhall

let DockerPublish
    : Type
    = < Enabled | Disabled | Essential >

let shouldPublish =
          \(publish : DockerPublish)
      ->  \(package : Package.Type)
      ->  merge
            { Disabled = False
            , Enabled = True
            , Essential = Package.isEssential package
            }
            publish

let show =
          \(publish : DockerPublish)
      ->  merge
            { Enabled = "Enabled"
            , Disabled = "Disabled"
            , Essential = "Essential"
            }
            publish

let effective
    : DockerPublish -> DockerPublish
    =
      -- What the pipeline asked for, else what the job declares.
      --
      -- Set in the Buildkite settings of a pipeline, not here: the jobs are
      -- shared, so only the environment of the render can tell pipelines
      -- apart. mina-artifacts (!ci-artifacts-me) sets Enabled: its images are
      -- used after the build, and a --load-only image is gone when its job
      -- ends.
      --
      -- A Dhall value, spelled out in full, as MINA_RELEASE_DOCKER_REPO is
      -- (see DockerRepo.dhall):
      --
      --   MINA_DOCKER_PUBLISH='< Enabled | Disabled | Essential >.Enabled'
          \(declared : DockerPublish)
      ->  Prelude.Optional.default
            DockerPublish
            declared
            (   Some (env:MINA_DOCKER_PUBLISH : DockerPublish)
              ? None DockerPublish
            )

in  { Type = DockerPublish
    , shouldPublish = shouldPublish
    , show = show
    , effective = effective
    }
