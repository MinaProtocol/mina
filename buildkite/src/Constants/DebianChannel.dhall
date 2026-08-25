let Channel
    : Type
    = < Unstable
      | Develop
      | Compatible
      | Master
      | Itn
      | Umt
      | UmtMainnet
      | Devnet
      | Alpha
      | Beta
      | Experimental
      | Stable
      >

let capitalName =
          \(channel : Channel)
      ->  merge
            { Unstable = "Unstable"
            , Develop = "Develop"
            , Compatible = "Compatible"
            , Master = "Master"
            , Itn = "Itn"
            , Umt = "Umt"
            , UmtMainnet = "UmtMainnet"
            , Devnet = "Devnet"
            , Alpha = "Alpha"
            , Beta = "Beta"
            , Stable = "Stable"
            , Experimental = "Experimental"
            }
            channel

let lowerName =
          \(channel : Channel)
      ->  merge
            { Unstable = "unstable"
            , Develop = "develop"
            , Compatible = "compatible"
            , Master = "master"
            , Itn = "itn"
            , Umt = "umt"
            , UmtMainnet = "umt-mainnet"
            , Devnet = "devnet"
            , Alpha = "alpha"
            , Beta = "beta"
            , Stable = "stable"
            , Experimental = "experimental"
            }
            channel

let Prelude = ../External/Prelude.dhall

let envOverride
    : Optional Text
    =
      -- The channel a release pipeline is publishing to, if it says.
      --
      -- Read here rather than declared per job because the alternative is a
      -- job file per channel: ten packaging jobs times three channels. The
      -- env var is absent everywhere except a release pipeline, so every
      -- other render keeps the channel its job declares.
      --
      -- Text, not Channel, on purpose. Dhall cannot turn a string into a
      -- union alternative -- it has no Text equality at all -- so a typed
      -- value would have to be spliced into the expression as source, which
      -- is how the pipeline filters do it and is a code-execution hole when
      -- the value is not trusted. Passing Text keeps the value inert here;
      -- scripts/debian/builder-helpers.sh rejects a name that is not a real
      -- channel, where string comparison actually exists.
      Some env:MINA_RELEASE_CHANNEL as Text ? None Text

let effective
    : Channel -> Text
    =
      -- The channel to build for: what the pipeline asked for, else what the
      -- job declares.
          \(declared : Channel)
      ->  Prelude.Optional.default Text (lowerName declared) envOverride

in  { Type = Channel
    , capitalName = capitalName
    , lowerName = lowerName
    , envOverride = envOverride
    , effective = effective
    }
