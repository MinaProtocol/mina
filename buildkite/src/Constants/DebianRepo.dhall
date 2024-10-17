let Prelude = ../External/Prelude.dhall

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

let DebianRepo
    : Type
    = < Local | PackagesO1Test | Unstable | Nightly >

let address =
          \(repo : DebianRepo)
      ->  merge
            { Local = "http://localhost:8080"
            , PackagesO1Test = "http://packages.o1test.net"
            , Unstable = "https://unstable.apt.packages.minaprotocol.com"
            , Nightly = "https://stable.apt.packages.minaprotocol.com"
            }
            repo

let bucket =
          \(repo : DebianRepo)
      ->  merge
            { Local = None Text
            , PackagesO1Test = Some "packages.o1test.net"
            , Unstable = Some "unstable.apt.packages.minaprotocol.com"
            , Nightly = Some "stable.apt.packages.minaprotocol.com"
            }
            repo

let bucketArg =
          \(repo : DebianRepo)
      ->  let maybeBucket =
                Optional/map
                  Text
                  Text
                  (\(bucket : Text) -> "--bucket " ++ bucket)
                  (bucket repo)

          in  Optional/default Text "" maybeBucket

let keyId =
          \(repo : DebianRepo)
      ->  merge
            { Local = None Text
            , PackagesO1Test = None Text
            , Unstable = Some "B40D16B1A4773DE415DAF9DBFE236881C07523DC"
            , Nightly = Some "B40D16B1A4773DE415DAF9DBFE236881C07523DC"
            }
            repo

let keyAddress =
          \(repo : DebianRepo)
      ->  let keyPath = "/key.asc"

          in  merge
                { Local = None Text
                , PackagesO1Test = None Text
                , Unstable = Some (address repo ++ keyPath)
                , Nightly = Some (address repo ++ keyPath)
                }
                repo

let keyAddressArg =
          \(repo : DebianRepo)
      ->  let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(key : Text) -> "--key-path " ++ key)
                  (keyAddress repo)

          in  Optional/default Text "" maybeKey

let keyArg =
          \(repo : DebianRepo)
      ->  let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "--sign " ++ repo)
                  (keyId repo)

          in  Optional/default Text "" maybeKey

let keyIdEnv =
          \(repo : DebianRepo)
      ->  let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "SIGN=" ++ repo)
                  (keyId repo)

          in  Optional/default Text "" maybeKey

let bucketEnv =
          \(repo : DebianRepo)
      ->  let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "BUCKET=" ++ repo)
                  (bucket repo)

          in  Optional/default Text "" maybeKey

in  { Type = DebianRepo
    , keyIdEnv = keyIdEnv
    , keyAddressArg = keyAddressArg
    , address = address
    , bucket = bucket
    , bucketArg = bucketArg
    , bucketEnv = bucketEnv
    , keyId = keyId
    , keyArg = keyArg
    }
