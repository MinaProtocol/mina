let Prelude = ../../External/Prelude.dhall

let Network = ../Network.dhall

let Profile = ../Artifact/Profiles.dhall

let BuildFlags = ../Artifact/BuildFlags.dhall

let Repo = ./Repo.dhall

let Package =
      < DaemonGeneric
      | DaemonProfiled : { profile : Profile.Type }
      | Daemon : { network : Network.Type }
      | DaemonLegacyHardfork : { network : Network.Type }
      | DaemonAutoHardfork : { network : Network.Type }
      | Archive : { network : Network.Type }
      | RosettaGeneric
      | Rosetta : { network : Network.Type }
      | TxTools
      | DelegationVerifier
      | Toolchain
      >

let capitalName =
          \(package : Package)
      ->  merge
            { DaemonGeneric = "DaemonGeneric"
            , DaemonProfiled =
                \(args : { profile : Profile.Type }) -> "DaemonProfiled"
            , Daemon = \(args : { network : Network.Type }) -> "Daemon"
            , DaemonLegacyHardfork =
                \(args : { network : Network.Type }) -> "DaemonLegacyHardfork"
            , DaemonAutoHardfork =
                \(args : { network : Network.Type }) -> "DaemonAutoHardfork"
            , Archive = \(args : { network : Network.Type }) -> "Archive"
            , RosettaGeneric = "RosettaGeneric"
            , Rosetta = \(args : { network : Network.Type }) -> "Rosetta"
            , TxTools = "TxTools"
            , DelegationVerifier = "DelegationVerifier"
            , Toolchain = "Toolchain"
            }
            package

let lowerName =
          \(package : Package)
      ->  merge
            { DaemonGeneric = "daemon_apps_only"
            , DaemonProfiled =
                \(args : { profile : Profile.Type }) -> "daemon_profile"
            , Daemon = \(args : { network : Network.Type }) -> "daemon_config"
            , DaemonLegacyHardfork =
                \(args : { network : Network.Type }) -> "daemon_hardfork"
            , DaemonAutoHardfork =
                \(args : { network : Network.Type }) -> "daemon_auto_hardfork"
            , Archive = \(args : { network : Network.Type }) -> "archive"
            , RosettaGeneric = "rosetta_apps_only"
            , Rosetta = \(args : { network : Network.Type }) -> "rosetta_config"
            , TxTools = "tx_tools"
            , DelegationVerifier = "delegation_verify"
            , Toolchain = "toolchain"
            }
            package

let isEssential =
          \(package : Package)
      ->  merge
            { DaemonGeneric = True
            , DaemonProfiled = \(args : { profile : Profile.Type }) -> True
            , Daemon = \(args : { network : Network.Type }) -> True
            , DaemonLegacyHardfork =
                \(args : { network : Network.Type }) -> True
            , DaemonAutoHardfork = \(args : { network : Network.Type }) -> True
            , Archive = \(args : { network : Network.Type }) -> True
            , RosettaGeneric = True
            , Rosetta = \(args : { network : Network.Type }) -> True
            , TxTools = False
            , DelegationVerifier = True
            , Toolchain = True
            }
            package

let isGeneric =
          \(package : Package)
      ->  merge
            { DaemonGeneric = True
            , DaemonProfiled = \(args : { profile : Profile.Type }) -> False
            , Daemon = \(args : { network : Network.Type }) -> False
            , DaemonLegacyHardfork =
                \(args : { network : Network.Type }) -> False
            , DaemonAutoHardfork = \(args : { network : Network.Type }) -> False
            , Archive = \(args : { network : Network.Type }) -> False
            , RosettaGeneric = True
            , Rosetta = \(args : { network : Network.Type }) -> False
            , TxTools = False
            , DelegationVerifier = False
            , Toolchain = False
            }
            package

let isNetworked =
          \(package : Package)
      ->  merge
            { DaemonGeneric = False
            , DaemonProfiled = \(args : { profile : Profile.Type }) -> False
            , Daemon = \(args : { network : Network.Type }) -> True
            , DaemonLegacyHardfork =
                \(args : { network : Network.Type }) -> True
            , DaemonAutoHardfork = \(args : { network : Network.Type }) -> True
            , Archive = \(args : { network : Network.Type }) -> True
            , RosettaGeneric = False
            , Rosetta = \(args : { network : Network.Type }) -> True
            , TxTools = False
            , DelegationVerifier = False
            , Toolchain = False
            }
            package

let isProfiled =
          \(package : Package)
      ->  merge
            { DaemonGeneric = False
            , DaemonProfiled = \(args : { profile : Profile.Type }) -> True
            , Daemon = \(args : { network : Network.Type }) -> False
            , DaemonLegacyHardfork =
                \(args : { network : Network.Type }) -> False
            , DaemonAutoHardfork = \(args : { network : Network.Type }) -> False
            , Archive = \(args : { network : Network.Type }) -> False
            , RosettaGeneric = False
            , Rosetta = \(args : { network : Network.Type }) -> False
            , TxTools = False
            , DelegationVerifier = False
            , Toolchain = False
            }
            package

let serviceName =
          \(package : Package)
      ->  merge
            { DaemonGeneric = "mina-daemon"
            , DaemonProfiled =
                \(args : { profile : Profile.Type }) -> "mina-daemon-profiled"
            , Daemon =
                \(args : { network : Network.Type }) -> "mina-daemon-configured"
            , DaemonLegacyHardfork =
                    \(args : { network : Network.Type })
                ->  "mina-daemon-legacy-hardfork"
            , DaemonAutoHardfork =
                    \(args : { network : Network.Type })
                ->  "mina-daemon-auto-hardfork"
            , Archive = \(args : { network : Network.Type }) -> "mina-archive"
            , RosettaGeneric = "mina-rosetta"
            , Rosetta =
                    \(args : { network : Network.Type })
                ->  "mina-rosetta-configured"
            , TxTools = "mina-tx-tools"
            , DelegationVerifier = "mina-delegation-verify"
            , Toolchain = "mina-toolchain"
            }
            package

let dockerName =
          \(package : Package)
      ->  merge
            { DaemonGeneric = "mina-daemon"
            , DaemonProfiled =
                \(args : { profile : Profile.Type }) -> "mina-daemon"
            , Daemon = \(args : { network : Network.Type }) -> "mina-daemon"
            , DaemonLegacyHardfork =
                    \(args : { network : Network.Type })
                ->  "mina-daemon-legacy-hardfork"
            , DaemonAutoHardfork =
                    \(args : { network : Network.Type })
                ->  "mina-daemon-auto-hardfork"
            , Archive = \(args : { network : Network.Type }) -> "mina-archive"
            , RosettaGeneric = "mina-rosetta"
            , Rosetta = \(args : { network : Network.Type }) -> "mina-rosetta"
            , TxTools = "mina-tx-tools"
            , DelegationVerifier = "mina-delegation-verify"
            , Toolchain = "mina-toolchain"
            }
            package

let Tag =
      { Type =
          { package : Package
          , version : Text
          , profile : Profile.Type
          , network : Network.Type
          , buildFlags : BuildFlags.Type
          , remove_profile_from_name : Bool
          }
      , default =
          { package = Package.Daemon { network = Network.Type.Devnet }
          , version = "\\\${MINA_DOCKER_TAG}"
          , profile = Profile.Type.Devnet
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Devnet
          , remove_profile_from_name = False
          }
      }

let dockerTag =
          \(spec : Tag.Type)
      ->  let network_part =
                      if isNetworked spec.package

                then  merge
                        { Devnet = Network.toLabelSegment spec.network
                        , Mainnet = Network.toLabelSegment spec.network
                        , Lightnet = ""
                        , Dev = ""
                        }
                        spec.profile

                else  ""

          let generic_part = if isGeneric spec.package then "-generic" else ""

          let profiled_part =
                      if isProfiled spec.package

                then  merge
                        { Devnet = "-devnet-generic"
                        , Mainnet = "-mainnet-generic"
                        , Lightnet = "-lightnet"
                        , Dev = "-dev"
                        }
                        spec.profile

                else  ""

          let profile_part =
                      if spec.remove_profile_from_name

                then  ""

                else  if isProfiled spec.package

                then  ""

                else  Profile.toExtraLabelSegment spec.profile

          let flags_part = BuildFlags.toLabelSegment spec.buildFlags

          in  "${spec.version}${network_part}${generic_part}${profiled_part}${profile_part}${flags_part}"

let dockerNames =
          \(packages : List Package)
      ->  Prelude.List.map Package Text dockerName packages

let fullDockerTag =
          \(spec : Tag.Type)
      ->  "${Repo.show Repo.Type.InternalEurope}/${dockerName
                                                     spec.package}:${dockerTag
                                                                       spec}"

let test_daemon_devnet =
        assert
      :     "1.0.0-devnet"
        ===  dockerTag
               Tag::{
               , package = Package.Daemon { network = Network.Type.Devnet }
               , version = "1.0.0"
               , profile = Profile.Type.Devnet
               , network = Network.Type.Devnet
               }

let test_daemon_generic =
        assert
      :     "1.0.0-generic"
        ===  dockerTag
               Tag::{
               , package = Package.DaemonGeneric
               , version = "1.0.0"
               , profile = Profile.Type.Devnet
               , network = Network.Type.Devnet
               }

let test_daemon_lightnet_instrumented =
        assert
      :     "1.0.0-lightnet-instrumented"
        ===  dockerTag
               Tag::{
               , package = Package.Daemon { network = Network.Type.Devnet }
               , version = "1.0.0"
               , profile = Profile.Type.Lightnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.Instrumented
               }

let test_daemon_profiled_devnet =
        assert
      :     "1.0.0-devnet-generic"
        ===  dockerTag
               Tag::{
               , package =
                   Package.DaemonProfiled { profile = Profile.Type.Devnet }
               , version = "1.0.0"
               , profile = Profile.Type.Devnet
               , network = Network.Type.Devnet
               }

let test_daemon_profiled_mainnet =
        assert
      :     "1.0.0-mainnet-generic"
        ===  dockerTag
               Tag::{
               , package =
                   Package.DaemonProfiled { profile = Profile.Type.Mainnet }
               , version = "1.0.0"
               , profile = Profile.Type.Mainnet
               , network = Network.Type.Devnet
               }

let test_daemon_profiled_lightnet =
        assert
      :     "1.0.0-lightnet"
        ===  dockerTag
               Tag::{
               , package =
                   Package.DaemonProfiled { profile = Profile.Type.Lightnet }
               , version = "1.0.0"
               , profile = Profile.Type.Lightnet
               , network = Network.Type.Devnet
               }

let test_archive_mainnet =
        assert
      :     "1.0.0-mainnet"
        ===  dockerTag
               Tag::{
               , package = Package.Archive { network = Network.Type.Mainnet }
               , version = "1.0.0"
               , profile = Profile.Type.Mainnet
               , network = Network.Type.Mainnet
               }

let test_rosetta_generic_mainnet_instrumented =
        assert
      :     "1.0.0-generic-instrumented"
        ===  dockerTag
               Tag::{
               , package = Package.RosettaGeneric
               , version = "1.0.0"
               , profile = Profile.Type.Mainnet
               , network = Network.Type.Mainnet
               , buildFlags = BuildFlags.Type.Instrumented
               , remove_profile_from_name = True
               }

let test_toolchain_networkless =
        assert
      :     "1.0.0"
        ===  dockerTag
               Tag::{
               , package = Package.Toolchain
               , version = "1.0.0"
               , profile = Profile.Type.Devnet
               , network = Network.Type.Devnet
               }

in  { Type = Package
    , Tag = Tag
    , isEssential = isEssential
    , capitalName = capitalName
    , lowerName = lowerName
    , serviceName = serviceName
    , isGeneric = isGeneric
    , isNetworked = isNetworked
    , isProfiled = isProfiled
    , dockerName = dockerName
    , dockerNames = dockerNames
    , dockerTag = dockerTag
    , fullDockerTag = fullDockerTag
    }
