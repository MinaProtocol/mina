let DebianRepo
    : Type
    = < Local | PackagesO1Test | Unstable | Nightly >

let address =
          \(repo : DebianRepo)
      ->  merge
            { Local = "http://localhost:8080"
            , PackagesO1Test = "http://packages.o1test.net"
            , Unstable = "https://unstable.apt.packages.minaprotocol.com"
            , Stable = "https://stable.apt.packages.minaprotocol.com"
            }
            repo

in  { Type = DebianRepo, address = address }
