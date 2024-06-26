let DebianRepo
    : Type
    = < Local | PackagesO1Test >

let address =
          \(repo : DebianRepo)
      ->  merge
            { Local = "http://localhost:8080"
            , PackagesO1Test = "http://packages.o1test.net"
            }
            repo

in  { Type = DebianRepo, address = address }
