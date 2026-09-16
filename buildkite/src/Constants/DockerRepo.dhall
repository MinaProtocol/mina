let Repo
    : Type
    = < Internal | InternalEurope >

let show =
          \(repo : Repo)
      ->  merge
            { Internal = "gcr.io/o1labs-192920"
            , InternalEurope =
                "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo"
            }
            repo

in  { Type = Repo, show = show }
