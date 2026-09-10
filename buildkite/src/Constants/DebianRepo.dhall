let Prelude = ../External/Prelude.dhall

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

let Optional/toList = Prelude.Optional.toList

let DebianRepo
    : Type
    = -- O1Test is packages.o1test.net: one unsigned repository carrying every
      -- channel, and the one the release pipelines publish to. The three
      -- minaprotocol.com repositories are signed and split by channel.
      < Unstable | Nightly | Stable | O1Test >

let address =
          \(repo : DebianRepo)
      ->  merge
            { Unstable = "https://unstable.apt.packages.minaprotocol.com"
            , Nightly = "https://nightly.apt.packages.minaprotocol.com"
            , Stable = "https://stable.apt.packages.minaprotocol.com"
            , O1Test = "https://packages.o1test.net"
            }
            repo

let bucket =
          \(repo : DebianRepo)
      ->  merge
            { Unstable = Some "unstable.apt.packages.minaprotocol.com"
            , Nightly = Some "nightly.apt.packages.minaprotocol.com"
            , Stable = Some "stable.apt.packages.minaprotocol.com"
            , O1Test = Some "packages.o1test.net"
            }
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
      ->  merge
            { Unstable = Some "386E9DAC378726A48ED5CE56ADB30D9ACE02F414"
            , Nightly = Some "386E9DAC378726A48ED5CE56ADB30D9ACE02F414"
            , Stable = Some "386E9DAC378726A48ED5CE56ADB30D9ACE02F414"
            , O1Test = None Text
            }
            repo

let isSigned =
          \(repo : DebianRepo)
      ->  merge
            { Unstable = True, Nightly = True, Stable = True, O1Test = False }
            repo

let keyAddress =
          \(repo : DebianRepo)
      ->  let keyPath = "/key.asc"

          in  merge
                { Unstable = Some (address repo ++ keyPath)
                , Nightly = Some (address repo ++ keyPath)
                , Stable = Some (address repo ++ keyPath)
                , O1Test = None Text
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

let keyIdEnvList =
          \(repo : DebianRepo)
      ->  let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "SIGN=" ++ repo)
                  (keyId repo)

          in  Optional/toList Text maybeKey

let bucketEnvList =
          \(repo : DebianRepo)
      ->  let maybeBucket =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "BUCKET=" ++ repo)
                  (bucket repo)

          in  Optional/toList Text maybeBucket

in  { Type = DebianRepo
    , keyIdEnvList = keyIdEnvList
    , bucketEnvList = bucketEnvList
    , keyAddressArg = keyAddressArg
    , address = address
    , bucket = bucket
    , bucket_or_default = bucket_or_default
    , bucketArg = bucketArg
    , keyId = keyId
    , keyArg = keyArg
    , isSigned = isSigned
    }
