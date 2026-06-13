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

in  { Type = Repo, show = show }
