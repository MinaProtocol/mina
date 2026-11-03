let Prelude = ../External/Prelude.dhall

let Repo
    : Type
    = < Internal | InternalEurope | Public >

let show =
          \(repo : Repo)
      ->  merge
            { Internal = "gcr.io/o1labs-192920"
            , InternalEurope =
                "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo"
            , Public = "docker.io/minaprotocol"
            }
            repo

let envValue
    : Repo -> Text
    =
      -- The value of MINA_RELEASE_DOCKER_REPO that names this registry: what
      -- a pipeline passes on to another one it triggers, so that both read
      -- the same registry. The spelling envOverride below accepts.
          \(repo : Repo)
      ->  "< Internal | InternalEurope | Public >.${merge
                                                      { Internal = "Internal"
                                                      , InternalEurope =
                                                          "InternalEurope"
                                                      , Public = "Public"
                                                      }
                                                      repo}"

let test_envValue_public =
        assert
      : envValue Repo.Public === "< Internal | InternalEurope | Public >.Public"

let test_envValue_round_trips =
    -- The spelled value is what the gate accepts
    -- (buildkite/scripts/pipeline/validate-release-env.sh, DOCKER_ACCEPTED).
        assert
      :     envValue Repo.InternalEurope
        ===  "< Internal | InternalEurope | Public >.InternalEurope"

let envOverride
    : Optional Repo
    =
      -- The registry a release pipeline pushes to, if it says.
      --
      -- It has to be an environment variable rather than a field on the job,
      -- because the packaging jobs are shared: nightly and a release pipeline
      -- run the very same MinaArtifact* jobs and must push to different
      -- registries. A field could only give one answer for both.
      --
      -- The variable holds a Dhall value, spelled out in full:
      --
      --   MINA_RELEASE_DOCKER_REPO='< Internal | InternalEurope | Public >.Public'
      --
      -- Verbose, and deliberately so. Dhall 1.30 has no Text equality, so a
      -- plain word cannot be turned into one of these alternatives at all,
      -- and a plain registry address would be an unchecked string pointing
      -- anywhere. Written this way the value is type checked when the
      -- pipeline renders, and both ways of getting it wrong are loud:
      --
      --   .Pubic                  -> Missing constructor: Pubic
      --   < Foo | Bar >.Foo       -> Expression doesn't match annotation
      --
      -- WARNING: do not write an import here. A path is resolved relative to
      -- neither the repository root nor this file, so it fails to resolve,
      -- the ? below treats that as absent, and the release pushes to the
      -- job's default registry with no warning at all. The alternatives must
      -- be spelled out, and they must match Repo above exactly -- adding an
      -- alternative there is a change every release pipeline has to be told
      -- about, which is why it errors rather than passing silently.
      Some (env:MINA_RELEASE_DOCKER_REPO : Repo) ? None Repo

let mirror
    : Optional Repo
    =
      -- A second registry that gets a copy of the release images, if the
      -- pipeline names one. The packaging jobs bake ONE registry into the
      -- image tags (envOverride above); the publish stage pushes those tags,
      -- then retags for the mirror and pushes again, narrowed by
      -- MINA_RELEASE_DOCKER_MIRROR_TAGS (see publish_from_cache.sh). A
      -- release goes to docker.io for everyone and keeps one codename on the
      -- internal registry for the deployments that read from there; the
      -- mirror is the second of those. Same form as MINA_RELEASE_DOCKER_REPO:
      --
      --   MINA_RELEASE_DOCKER_MIRROR='< Internal | InternalEurope | Public >.InternalEurope'
      --
      -- Unset means no second push. The pair reads as
      -- MINA_RELEASE_DEBIAN_REPO and MINA_RELEASE_DEBIAN_MIRROR do (see
      -- DebianRepo.dhall).
      Some (env:MINA_RELEASE_DOCKER_MIRROR : Repo) ? None Repo

let effective
    : Repo -> Repo
    =
      -- The registry to push to: what the pipeline asked for, else what the
      -- job declares.
      \(declared : Repo) -> Prelude.Optional.default Repo declared envOverride

let hashTag
    : Repo -> Bool
    =
      -- Whether a push also adds the short hash tag (<hash>-<codename>-...).
      -- Internal registries keep it: CI and tests look images up by it. The
      -- public registry gets only the version tag users are told to pull.
          \(repo : Repo)
      ->  merge { Internal = True, InternalEurope = True, Public = False } repo

in  { Type = Repo
    , show = show
    , hashTag = hashTag
    , envValue = envValue
    , envOverride = envOverride
    , mirror = mirror
    , effective = effective
    }
