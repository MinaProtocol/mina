-- Named groups of steps, so that a developer asks for "the automode images"
-- instead of writing the patterns out.
--
-- A set is only sugar. It becomes patterns for step keys, and select_steps.sh
-- then adds everything those steps depend on, exactly as if the patterns had
-- been given by hand. Nothing here can select something that a pattern could
-- not.
--
-- The names of the steps come from the rendered pipelines. A key holds what is
-- built, for which tier and for which network:
--
--   daemon_apps_only-devnet-docker-image   the daemon with no profile, no config
--   daemon_profile-lightnet-docker-image   the daemon with a profile
--   daemon_config-devnet-docker-image      the daemon with a network config
--   daemon_auto_hardfork-devnet-docker-image
--   archive-devnet-docker-image
--   rosetta_profile-devnet-docker-image
--   rosetta_config-devnet-docker-image
--   build-deb-pkg                          every debian package of a pipeline
--
-- The codename and the architecture are in the name of the job, not in the key,
-- so a set covers EVERY codename.
--
-- A set and a pattern ADD UP, they do not narrow each other: asking for the set
-- "automode" and the pattern "_MinaArtifactBullseye-*" gives the automode images
-- of every codename AND every step of Bullseye. To keep to one codename, write
-- the whole key instead of using a set:
--
--   --select '_MinaArtifactBullseye-daemon_auto_hardfork-*-docker-image'
--
-- Not sets:
--
-- * prefork, and any single package. DaemonPrefork, DaemonPostfork and
--   CreatePreforkGenesis make a debian but no docker image, and one step builds
--   every debian, so a set of steps cannot reach them. They become sets with A5.
-- * a profile such as lightnet. Only the daemon has one, and one pattern needs
--   no name: --select '*_profile-lightnet-docker-image'

let Set = { name : Text, patterns : List Text, description : Text }

let sets
    : List Set
    =
      -- Whole layers
      [ { name = "dockers"
        , patterns = [ "*-docker-image" ]
        , description = "every docker image"
        }
      , { name = "debians"
        , patterns = [ "build-deb-pkg" ]
        , description =
            "every debian package (one step builds them all, so this cannot be narrowed further)"
        }
      , { name = "daemon"
        , patterns = [ "daemon_*-docker-image" ]
        , description =
            "the daemon images: apps only, profiled, configured, auto hardfork"
        }
      , { name = "archive"
        , patterns = [ "archive-*-docker-image" ]
        , description = "the archive images"
        }
      , { name = "rosetta"
        , patterns = [ "rosetta_*-docker-image" ]
        , description = "the rosetta images: profiled and configured"
        }
      , { name = "automode"
        , patterns = [ "daemon_auto_hardfork-*-docker-image" ]
        , description = "the automode (auto hardfork) images"
        }
      , { name = "apps-only"
        , patterns = [ "*_apps_only-*-docker-image" ]
        , description = "the images with no profile and no config"
        }
      , { name = "configured"
        , patterns = [ "*_config-*-docker-image" ]
        , description = "the images that hold a network config"
        }
      ]

in  { Type = Set, sets = sets }
