let Repo
    : Type
    = < Internal | Public >

let show =
          \(repo : Repo)
      ->  merge
            { Internal = "gcr.io/o1labs-192920"
            , Public = "docker.io/minaprotocol"
            }
            repo

in  { Type = Repo, show = show }
