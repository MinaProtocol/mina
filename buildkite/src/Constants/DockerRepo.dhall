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

let effective
    : Repo -> Repo
    =
      -- The registry to push to: what the pipeline asked for, else what the
      -- job declares.
      \(declared : Repo) -> Prelude.Optional.default Repo declared envOverride

in  { Type = Repo
    , show = show
    , envOverride = envOverride
    , effective = effective
    }
