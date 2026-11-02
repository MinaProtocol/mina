let Prelude = ../External/Prelude.dhall

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

let Optional/toList = Prelude.Optional.toList

let DebianRepo
    : Type
    = < Unstable | Nightly | Stable | O1Test >

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

let lowerName =
          \(repo : DebianRepo)
      ->  merge
            { Unstable = "unstable"
            , Nightly = "nightly"
            , Stable = "stable"
            , O1Test = "o1test"
            }
            repo

let envOverride
    : Optional DebianRepo
    =
      -- The repository a release pipeline publishes its debians to, if it
      -- says. An environment variable rather than a field on the job, for the
      -- same reason as MINA_RELEASE_DOCKER_REPO (see DockerRepo.dhall): the
      -- job is shared by every release pipeline, and only the environment of
      -- the render can tell them apart. The value is a Dhall alternative,
      -- spelled out in full:
      --
      --   MINA_RELEASE_DEBIAN_REPO='< Unstable | Nightly | Stable | O1Test >.Stable'
      --
      -- Verbose for the reason given in DockerRepo.dhall: a plain word cannot
      -- be turned into an alternative, and a typo must fail the type check
      -- rather than pass as a string. A value that does not resolve collapses
      -- into None here, the same as unset, which the ? cannot tell apart;
      -- validate-release-env.sh checks the spelling before the render so that
      -- case stops the build instead of publishing to the default.
      --
      -- WARNING: do not write an import here (see DockerRepo.dhall).
      Some (env:MINA_RELEASE_DEBIAN_REPO : DebianRepo) ? None DebianRepo

let mirror
    : Optional DebianRepo
    =
      -- A second repository that gets the same packages, if the pipeline
      -- names one. A release goes to the unsigned packages.o1test.net that
      -- every consumer still reads and to the signed repository of its
      -- channel, so the publish stage needs two targets, not one; the mirror
      -- is the second. Same form as MINA_RELEASE_DEBIAN_REPO:
      --
      --   MINA_RELEASE_DEBIAN_MIRROR='< Unstable | Nightly | Stable | O1Test >.Stable'
      --
      -- Unset means no second publish.
      Some (env:MINA_RELEASE_DEBIAN_MIRROR : DebianRepo) ? None DebianRepo

let effective
    : DebianRepo -> DebianRepo
    =
      -- The repository to publish to: what the pipeline asked for, else what
      -- the job declares.
          \(declared : DebianRepo)
      ->  Optional/default DebianRepo declared envOverride

let targets
    : DebianRepo -> List DebianRepo
    =
      -- Every repository the publish stage writes to: the effective one, then
      -- the mirror when there is one.
          \(declared : DebianRepo)
      ->  [ effective declared ] # Optional/toList DebianRepo mirror

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
    , lowerName = lowerName
    , envOverride = envOverride
    , mirror = mirror
    , effective = effective
    , targets = targets
    }
