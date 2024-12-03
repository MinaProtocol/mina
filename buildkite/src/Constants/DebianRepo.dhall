let Prelude = ../External/Prelude.dhall

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

let Optional/toList = Prelude.Optional.toList

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

let bucket =
          \(repo : DebianRepo)
      ->  merge
            { Local = None Text, PackagesO1Test = Some "packages.o1test.net" }
            repo

let bucket_or_default =
          \(repo : DebianRepo)
      ->  let maybeBucket =
                Optional/map
                  Text
                  Text
                  (\(bucket : Text) -> bucket)
                  (bucket repo)

          in  Optional/default Text "" maybeBucket

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
      ->  merge { Local = None Text, PackagesO1Test = None Text } repo

let keyAddress =
          \(repo : DebianRepo)
      ->  merge { Local = None Text, PackagesO1Test = None Text } repo

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

let keyIdEnvList =
          \(repo : DebianRepo)
      ->  let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "SIGN=" ++ repo)
                  (keyId repo)

          in  Optional/toList Text maybeKey

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
    , keyIdEnvList = keyIdEnvList
    , keyAddressArg = keyAddressArg
    , address = address
    , bucket = bucket
    , bucket_or_default = bucket_or_default
    , bucketArg = bucketArg
    , bucketEnv = bucketEnv
    , keyId = keyId
    , keyArg = keyArg
    }
