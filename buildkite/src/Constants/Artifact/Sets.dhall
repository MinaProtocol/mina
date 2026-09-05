-- What a developer can ask to be built, named the way the work is talked about.
--
-- A set names ONE artifact of the product -- the daemon, the archive, rosetta,
-- automode -- and says how that artifact appears in each layer:
--
--   dockers   patterns for docker step keys
--   debians   patterns for debian package tokens
--
-- The LAYER is not part of the name, because the command already carries it:
-- !ci-docker-me builds images and !ci-debian-me builds packages. So there is no
-- "dockers" set and no "debians" set, and a tier such as "configured" is not a
-- name a developer has to know either: asking for the daemon gives the daemon,
-- at every tier it has.
--
-- An artifact that has nothing in a layer says so with an empty list, and the
-- run stops rather than building nothing: prefork makes packages and no image.
--
-- The names of the steps come from the rendered pipelines. A key holds what is
-- built, for which tier and for which network or profile:
--
--   daemon_apps_only-devnet-docker-image     no profile, no config
--   daemon_profile-lightnet-docker-image     a profile
--   daemon_config-devnet-docker-image        a network config
--   daemon_auto_hardfork-devnet-docker-image
--   archive-devnet-docker-image
--   rosetta_profile-devnet-docker-image
--   rosetta_config-devnet-docker-image
--   build-deb-pkg                            every debian package of a pipeline
--
-- The codename and the architecture are in the NAME OF THE JOB, not in the key,
-- so a set covers every codename and every architecture. Narrow it with
-- codename= and arch=, and narrow the network or the profile with network= and
-- profile=, rather than by writing a longer pattern.

let Set =
      { name : Text
      , dockers : List Text
      , debians : List Text
      , description : Text
      }

let segments =
    -- What network= and profile= may say. It is the two networks of
    -- Constants/Network.dhall together with lightnet, which is a profile and
    -- not a network but sits in the same place of a step key
    -- (daemon_profile-lightnet-docker-image), so a developer cannot tell them
    -- apart and does not have to.
    --
    -- Naming one of these narrows to it. The list is needed to know what the
    -- OTHERS are, so that asking for devnet can drop the mainnet packages.
      [ "devnet", "mainnet", "lightnet" ]

let sets
    : List Set
    = [ { name = "daemon"
        , dockers =
          [ "daemon_apps_only-*-docker-image"
          , "daemon_profile-*-docker-image"
          , "daemon_config-*-docker-image"
          ]
        , debians =
          [ "runtime", "daemon_devnet", "daemon_mainnet", "profile_*" ]
        , description = "the daemon: apps only, profiled and configured"
        }
      , { name = "archive"
        , dockers = [ "archive-*-docker-image" ]
        , debians = [ "archive_*" ]
        , description = "the archive node"
        }
      , { name = "rosetta"
        , dockers =
          [ "rosetta_profile-*-docker-image", "rosetta_config-*-docker-image" ]
        , debians = [ "rosetta_*" ]
        , description = "rosetta: profiled and configured"
        }
      , { name = "automode"
        , dockers = [ "daemon_auto_hardfork-*-docker-image" ]
        , debians = [ "daemon_*_automode", "daemon_*_postfork" ]
        , description =
            "the automatic hardfork: the auto-hardfork image, and the automode and postfork packages"
        }
      , { name = "prefork"
        , dockers = [] : List Text
        , debians = [ "daemon_*_prefork", "prefork_*_genesis_ledger" ]
        , description =
            "what is built FOR the next hardfork: the prefork daemon and its genesis ledger. Packages only, no image"
        }
      , { name = "logproc"
        , dockers = [] : List Text
        , debians = [ "logproc" ]
        , description = "the log processor. Package only, no image"
        }
      , { name = "toolbox"
        , dockers = [] : List Text
        , debians = [ "daemon_storage_toolbox" ]
        , description = "the daemon storage toolbox. Package only, no image"
        }
      , { name = "delegation-verifier"
        , dockers = [ "delegation_verifier-*-docker-image" ]
        , debians = [ "delegation_verify" ]
        , description = "the delegation verifier"
        }
      , { name = "test-tools"
        , dockers = [] : List Text
        , debians = [ "test_executive", "functional_test_suite", "tx_tools" ]
        , description =
            "the test executive, the functional test suite and the transaction tools"
        }
      , { name = "all"
        , dockers = [ "*-docker-image" ]
        , debians = [ "*" ]
        , description = "everything the pipeline builds in this layer"
        }
      ]

in  { Type = Set, sets = sets, segments = segments }
