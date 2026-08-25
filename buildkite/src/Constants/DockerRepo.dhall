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

let publicOverride
    : Optional Text
    =
      -- Set by a release pipeline to send its images to the public registry.
      --
      -- It has to be an environment variable rather than a field on the job,
      -- because the packaging jobs are shared: nightly and a release pipeline
      -- run the very same MinaArtifact* jobs and must push to different
      -- registries. A field could only give one answer for both.
      --
      -- Presence is the whole signal and the value is ignored, deliberately.
      -- Dhall has no Text equality, so a variable carrying a registry NAME
      -- could not be matched against the alternatives of this union without
      -- splicing it in as source. A flag cannot be misspelled into a
      -- different destination -- the only two outcomes are set and unset.
      Some env:MINA_RELEASE_PUBLIC_DOCKER as Text ? None Text

let effective
    : Repo -> Repo
    =
      -- The registry to push to: public when the pipeline asked for it, else
      -- whatever the job declares.
          \(declared : Repo)
      ->  Prelude.Optional.fold
            Text
            publicOverride
            Repo
            (\(_ : Text) -> Repo.Public)
            declared

in  { Type = Repo
    , show = show
    , publicOverride = publicOverride
    , effective = effective
    }
