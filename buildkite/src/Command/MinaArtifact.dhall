let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let List/concatMap = Prelude.List.concatMap

let Optional/default = Prelude.Optional.default

let Text/concatSep = Prelude.Text.concatSep

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let DockerImage = ./DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DockerPublish = ../Constants/Docker/Publish.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Profiles = ../Constants/Profiles.dhall

let Network = ../Constants/Network.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Docker = ../Constants/Docker/Package.dhall

let BaseImage = ../Constants/Docker/BaseImage.dhall

let Artifact = ../Constants/Artifact/Artifacts.dhall

let Toolchain = ../Constants/Toolchain.dhall

let Arch = ../Constants/Arch.dhall

let Expr = ../Pipeline/Expr.dhall

let PackagingSpec =
      { Type =
          { prefix : Text
          , artifacts : List Artifact.Type
          , debVersion : DebianVersions.DebVersion
          , buildFlags : BuildFlags.Type
          , toolchainSelectMode : Toolchain.SelectionMode
          , extraBuildEnvs : List Text
          , scope : List PipelineScope.Type
          , tags : List PipelineTag.Type
          , channel : DebianChannel.Type
          , debianRepo : DebianRepo.Type
          , buildScript : Text
          , arch : Arch.Type
          , deb_legacy_version : Text
          , deb_legacy_githash_config : Text
          , docker_publish : DockerPublish.Type
          , docker_repo : DockerRepo.Type
          , suffix : Optional Text
          , if_ : Optional B/If
          , includeIf : List Expr.Type
          , excludeIf : List Expr.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = [ Artifact.Type.LogProc ]
          , buildScript = "./buildkite/scripts/build-release.sh"
          , debVersion = DebianVersions.DebVersion.Bullseye
          , buildFlags = BuildFlags.Type.None
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebianAndArch
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , scope = PipelineScope.Full
          , channel = DebianChannel.Type.Unstable
          , debianRepo = DebianRepo.Type.Unstable
          , extraBuildEnvs = [] : List Text
          , suffix = None Text
          , deb_legacy_version = "3.5.0-mainnet-stop-slot-8110ede"
          , deb_legacy_githash_config = ""
          , arch = Arch.Type.Amd64
          , docker_publish = DockerPublish.Type.Essential
          , docker_repo = DockerRepo.Type.InternalEurope
          , if_ = None B/If
          , includeIf = [] : List Expr.Type
          , excludeIf = [] : List Expr.Type
          }
      }

let AppsSpec =
    -- What an app build actually needs, and nothing else.
    --
    -- The app build compiles EVERYTHING: build-artifact.sh runs a fixed set of
    -- make targets and never looks at an artifact list. Nor does anything
    -- downstream of it -- the apps cache variant is derived from arch and build
    -- flags alone (there is one cache per codename/arch/flags, not per network
    -- or profile). So an app build has no artifacts, no network and no profile:
    -- those describe what gets PACKAGED from the binaries afterwards, which is
    -- the packaging job's business.
    --
    -- nameSegment exists only so a second app job can be told apart by name; it
    -- is not a network selector. There is nothing network-specific to select.
      { Type =
          { prefix : Text
          , nameSegment : Text
          , debVersion : DebianVersions.DebVersion
          , buildFlags : BuildFlags.Type
          , arch : Arch.Type
          , toolchainSelectMode : Toolchain.SelectionMode
          , extraBuildEnvs : List Text
          , scope : List PipelineScope.Type
          , tags : List PipelineTag.Type
          , if_ : Optional B/If
          , includeIf : List Expr.Type
          , excludeIf : List Expr.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , nameSegment = ""
          , debVersion = DebianVersions.DebVersion.Bullseye
          , buildFlags = BuildFlags.Type.None
          , arch = Arch.Type.Amd64
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebianAndArch
          , extraBuildEnvs = [] : List Text
          , scope = PipelineScope.Full
          , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
          , if_ = None B/If
          , includeIf = [] : List Expr.Type
          , excludeIf = [] : List Expr.Type
          }
      }

let appsLabelSuffix
    : AppsSpec.Type -> Text
    =     \(spec : AppsSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion} ${BuildFlags.toSuffixUppercase
                                    spec.buildFlags}${Arch.labelSuffix
                                                        spec.arch}"

let appsSpecVariant
    : AppsSpec.Type -> Text
    =     \(spec : AppsSpec.Type)
      ->  merge
            { None = merge { Amd64 = "", Arm64 = "arm64" } spec.arch
            , Instrumented =
                merge
                  { Amd64 = "instrumented", Arm64 = "instrumented-arm64" }
                  spec.arch
            }
            spec.buildFlags

let appsSpecTreeVariant
    : AppsSpec.Type -> Text
    =     \(spec : AppsSpec.Type)
      ->  "${DebianVersions.lowerName
               spec.debVersion}${BuildFlags.toLabelSegment
                                   spec.buildFlags}${Arch.toSuffixLowercase
                                                       spec.arch}"

let appsBuildEnvs =
    -- Deliberately excludes MINA_BUILD_MAINNET and the PREFORK_* pair that the
    -- packaging envs carry: MINA_BUILD_MAINNET is read by nothing at all, and
    -- PREFORK_LEGACY_VERSION / PREFORK_GITHASH_CONFIG are read only by
    -- scripts/debian/builder-helpers.sh when it assembles the prefork packages.
    -- None of them influence compilation.
          \(spec : AppsSpec.Type)
      ->    [ "AWS_ACCESS_KEY_ID"
            , "AWS_SECRET_ACCESS_KEY"
            , "MINA_BRANCH=\$BUILDKITE_BRANCH"
            , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
            , "MINA_DEB_CODENAME=${DebianVersions.lowerName spec.debVersion}"
            , "ARCHITECTURE=${Arch.lowerName spec.arch}"
            ]
          # BuildFlags.buildEnvs spec.buildFlags
          # spec.extraBuildEnvs
          # DebianVersions.overrideEnvs

let primaryNetwork
    : PackagingSpec.Type -> Network.Type
    =     \(spec : PackagingSpec.Type)
      ->  Optional/default
            Network.Type
            Network.Type.Devnet
            (List/head Network.Type (Artifact.networks spec.artifacts))

let labelSuffix
    : PackagingSpec.Type -> Text
    =
      -- The network is named here, and not only in the name of the job, because
      -- one codename has a devnet packaging step AND a mainnet one. Without it
      -- both read "Debian: Build Bullseye" and the two look like the same work
      -- done twice, which is what they are not: they build different packages.
      --
      -- Network.capitalName and not Network.namePrefixSegment, which is empty
      -- for devnet: a label that says nothing is what is being fixed.
          \(spec : PackagingSpec.Type)
      ->  "${Network.capitalName
               ( primaryNetwork spec
               )} ${DebianVersions.capitalName
                      spec.debVersion} ${BuildFlags.toSuffixUppercase
                                           spec.buildFlags}${Arch.labelSuffix
                                                               spec.arch}"

let baseNameSuffix
    : PackagingSpec.Type -> Text
    =     \(spec : PackagingSpec.Type)
      ->  "${DebianVersions.capitalName
               spec.debVersion}${BuildFlags.toSuffixUppercase
                                   spec.buildFlags}${Arch.nameSuffix spec.arch}"

let nameSuffix
    : PackagingSpec.Type -> Text
    =     \(spec : PackagingSpec.Type)
      ->  "${Network.namePrefixSegment (primaryNetwork spec)}${baseNameSuffix
                                                                 spec}"

let selfName
    : PackagingSpec.Type -> Text
    = \(spec : PackagingSpec.Type) -> "${spec.prefix}${nameSuffix spec}"

let genericBuildName
    : PackagingSpec.Type -> Text
    = \(spec : PackagingSpec.Type) -> "${spec.prefix}${baseNameSuffix spec}"

let DockerService =
      { service : Docker.Type, network : Network.Type, profile : Profiles.Type }

let expandDockerServices =
          \(artifact : Artifact.Type)
      ->  let net = Artifact.resolvedNetwork artifact

          let prof = Artifact.profile artifact

          let mk =
                    \(svc : Docker.Type)
                ->  { service = svc, network = net, profile = prof }

          let none = [] : List DockerService

          in  merge
                { Daemon =
                        \(_ : { network : Network.Type })
                    ->  [ mk (Docker.Type.Daemon { network = net }) ]
                , DaemonGeneric = [ mk Docker.Type.DaemonGeneric ]
                , DaemonProfiled =
                        \(_ : { profile : Profiles.Type })
                    ->  [ mk (Docker.Type.DaemonProfiled { profile = prof }) ]
                , DaemonLegacyHardfork =
                        \(_ : { network : Network.Type })
                    ->  [ mk
                            (Docker.Type.DaemonLegacyHardfork { network = net })
                        ]
                , DaemonAutoHardfork =
                        \(_ : { network : Network.Type })
                    ->  [ mk (Docker.Type.DaemonAutoHardfork { network = net })
                        ]
                , DaemonPrefork = \(_ : { network : Network.Type }) -> none
                , DaemonPostfork = \(_ : { network : Network.Type }) -> none
                , CreatePreforkGenesis =
                    \(_ : { network : Network.Type }) -> none
                , DaemonStorageToolbox = none
                , LogProc = none
                , ArchiveGeneric = none
                , Archive =
                        \(_ : { network : Network.Type })
                    ->  [ mk (Docker.Type.Archive { network = net }) ]
                , RosettaGeneric = none
                , Rosetta =
                        \(_ : { network : Network.Type })
                    ->  [ mk Docker.Type.RosettaGeneric
                        , mk (Docker.Type.Rosetta { network = net })
                        ]
                , TestExecutive = none
                , TxTools = none
                , FunctionalTestSuite = none
                , DelegationVerifier = [ mk Docker.Type.DelegationVerifier ]
                , Toolchain = none
                }
                artifact

let appsVariant
    : PackagingSpec.Type -> Text
    =     \(spec : PackagingSpec.Type)
      ->  merge
            { None = merge { Amd64 = "", Arm64 = "arm64" } spec.arch
            , Instrumented =
                merge
                  { Amd64 = "instrumented", Arm64 = "instrumented-arm64" }
                  spec.arch
            }
            spec.buildFlags

let profileTents
    : PackagingSpec.Type -> Text
    =
      -- The mina-<network>-generic tents this job's own artifacts call for.
      --
      -- Both tents used to be appended to EVERY packaging job. Two jobs of one
      -- codename then built the same two packages and wrote them into the same
      -- cache directory at the same time, and a codename with no mainnet job
      -- still shipped mina-mainnet-generic, whose dependency
      -- mina-mainnet-profile that codename never builds -- an uninstallable
      -- package. A tent now goes with the profile it names.
          \(spec : PackagingSpec.Type)
      ->  Text/concatSep " " (Artifact.profileTents spec.artifacts)

let build_artifacts
    : PackagingSpec.Type -> Command.Type
    =     \(spec : PackagingSpec.Type)
      ->  let nets = Artifact.networks spec.artifacts

          let debianTokens =
                Text/concatSep
                  " "
                  ( List/map
                      Artifact.Type
                      Text
                      Artifact.toDebianToken
                      spec.artifacts
                  )

          let appsCacheWrite =
                Cmd.run
                  "./buildkite/scripts/apps/write_to_cache.sh ${DebianVersions.lowerName
                                                                  spec.debVersion} ${appsVariant
                                                                                       spec}"

          in  Command.build
                Command.Config::{
                , commands =
                      Toolchain.select
                        Toolchain.Spec::{
                        , mode = spec.toolchainSelectMode
                        , debVersion = spec.debVersion
                        , arch = spec.arch
                        , submodules = True
                        }
                        (   [ "AWS_ACCESS_KEY_ID"
                            , "AWS_SECRET_ACCESS_KEY"
                            , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                            , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                            , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                     spec.debVersion}"
                            , "ARCHITECTURE=${Arch.lowerName spec.arch}"
                            , Network.foldMinaBuildMainnetEnv nets
                            , "PREFORK_LEGACY_VERSION=${spec.deb_legacy_version}"
                            , "PREFORK_GITHASH_CONFIG=${spec.deb_legacy_githash_config}"
                            , "MINA_DEB_RELEASE=${DebianChannel.effective
                                                    spec.channel}"
                            ]
                          # BuildFlags.buildEnvs spec.buildFlags
                          # spec.extraBuildEnvs
                          # DebianVersions.overrideEnvs
                        )
                        "${spec.buildScript} ${debianTokens} ${profileTents
                                                                 spec}"
                    # [ Cmd.run
                          "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                            spec.debVersion}"
                      , appsCacheWrite
                      ]
                , label = "Debian: Build ${labelSuffix spec}"
                , key = "build-deb-pkg${Optional/default Text "" spec.suffix}"
                , target = Size.Multi
                , if_ = spec.if_
                , retries =
                  [ Command.Retry::{
                    , exit_status = Command.ExitStatus.Code +2
                    , limit = Some 2
                    }
                  ]
                }

let commonBuildEnvs =
    -- MINA_DEB_RELEASE is the channel. builder-helpers.sh writes it into every
    -- control file as `Suite:` and defaults it to "unstable", so before it was
    -- passed here a package built for stable still declared itself unstable,
    -- and only the promotion step put that right.
          \(spec : PackagingSpec.Type)
      ->  let nets = Artifact.networks spec.artifacts

          in    [ "AWS_ACCESS_KEY_ID"
                , "AWS_SECRET_ACCESS_KEY"
                , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                         spec.debVersion}"
                , "ARCHITECTURE=${Arch.lowerName spec.arch}"
                , "FORCE_DOCKER_OVERWRITE"
                , Network.foldMinaBuildMainnetEnv nets
                , "PREFORK_LEGACY_VERSION=${spec.deb_legacy_version}"
                , "PREFORK_GITHASH_CONFIG=${spec.deb_legacy_githash_config}"
                , "MINA_DEB_RELEASE=${DebianChannel.effective spec.channel}"
                ]
              # BuildFlags.buildEnvs spec.buildFlags
              # spec.extraBuildEnvs
              # DebianVersions.overrideEnvs

let treeVariant =
          \(spec : PackagingSpec.Type)
      ->  "${DebianVersions.lowerName
               spec.debVersion}${BuildFlags.toLabelSegment
                                   spec.buildFlags}${Arch.toSuffixLowercase
                                                       spec.arch}"

let appsJobName
    : PackagingSpec.Type -> Text
    =
      -- genericBuildName, not selfName: the app build carries no network (see
      -- AppsSpec), so every packaging job of one codename/flags/arch shares the
      -- single network-less app job.
      \(spec : PackagingSpec.Type) -> "${genericBuildName spec}Apps"

let build_apps
    : AppsSpec.Type -> Command.Type
    =     \(spec : AppsSpec.Type)
      ->  let appsCacheWrite =
                Cmd.run
                  "./buildkite/scripts/apps/write_to_cache.sh ${DebianVersions.lowerName
                                                                  spec.debVersion} ${appsSpecVariant
                                                                                       spec}"

          in  Command.build
                Command.Config::{
                , commands =
                      Toolchain.select
                        Toolchain.Spec::{
                        , mode = spec.toolchainSelectMode
                        , debVersion = spec.debVersion
                        , arch = spec.arch
                        , submodules = True
                        }
                        (appsBuildEnvs spec)
                        "./buildkite/scripts/build-artifact.sh"
                    # [ appsCacheWrite
                      , Cmd.run
                          "./buildkite/scripts/apps/write_build_manifest_to_cache.sh ${DebianVersions.lowerName
                                                                                         spec.debVersion} ${appsSpecTreeVariant
                                                                                                              spec}"
                      ]
                , label = "Build apps: ${appsLabelSuffix spec}"
                , key = "build-apps"
                , target = Size.Multi
                , if_ = spec.if_
                , retries =
                  [ Command.Retry::{
                    , exit_status = Command.ExitStatus.Code +2
                    , limit = Some 2
                    }
                  ]
                }

let debianTokens
    : PackagingSpec.Type -> Text
    =     \(spec : PackagingSpec.Type)
      ->  Text/concatSep
            " "
            (List/map Artifact.Type Text Artifact.toDebianToken spec.artifacts)

let buildDebianFromApps
    : PackagingSpec.Type -> Text -> List Cmd.Type
    =     \(spec : PackagingSpec.Type)
      ->  \(tokens : Text)
      ->  Toolchain.select
            Toolchain.Spec::{
            , mode = spec.toolchainSelectMode
            , debVersion = spec.debVersion
            , arch = spec.arch
            , submodules = False
            }
            (commonBuildEnvs spec)
            "APPS_VARIANT=${appsVariant
                              spec} ./buildkite/scripts/debian/build-from-cache.sh ${treeVariant
                                                                                       spec} ${tokens}"

let build_debian
    : PackagingSpec.Type -> Command.Type
    =     \(spec : PackagingSpec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  buildDebianFromApps
                    spec
                    "${debianTokens spec} ${profileTents spec}"
                # [ Cmd.run
                      "./buildkite/scripts/debian/write_to_cache.sh ${DebianVersions.lowerName
                                                                        spec.debVersion}"
                  ]
            , label = "Debian: Build ${labelSuffix spec}"
            , key = "build-deb-pkg${Optional/default Text "" spec.suffix}"
            , depends_on = [ { name = appsJobName spec, key = "build-apps" } ]
            , target = Size.Multi
            , if_ = spec.if_
            , retries =
              [ Command.Retry::{
                , exit_status = Command.ExitStatus.Code +2
                , limit = Some 2
                }
              ]
            }

let docker_step
    : DockerService -> PackagingSpec.Type -> List DockerImage.ReleaseSpec.Type
    =     \(entry : DockerService)
      ->  \(spec : PackagingSpec.Type)
      ->  let network = entry.network

          let profile = entry.profile

          let netSeg = "-${Network.lowerName network}-docker-image"

          let genericJobDebs
              : List Command.TaggedKey.Type
              =
                -- Every image of a codename installs its .deb files out of ONE
                -- directory of the build cache, which every packaging job of
                -- that codename writes into. So a mainnet image needs the
                -- packages of the network-less job as well as its own: the
                -- mainnet archive image installs mina-archive-generic, and the
                -- mainnet job builds archive_mainnet and not archive_generic.
                --
                -- That was already true and nothing said so. Both jobs happened
                -- to run and the file happened to be there in time. A selection
                -- that asks for mainnet alone does not run the other job at
                -- all, so the package would simply not exist.
                --
                -- The network decides it, because dhall cannot compare the two
                -- job names: Network.namePrefixSegment is empty for devnet, so
                -- the devnet job IS the network-less one and needs nothing
                -- added.
                merge
                  { Devnet = [] : List Command.TaggedKey.Type
                  , Mainnet =
                    [ { name = genericBuildName spec, key = "build-deb-pkg" } ]
                  }
                  (primaryNetwork spec)

          let deps
              : List Command.TaggedKey.Type
              =   [ { name = selfName spec, key = "build-deb-pkg" } ]
                # genericJobDebs

          let withDocker =
                    \(dep : Docker.Type)
                ->    deps
                    # [ { name = selfName spec
                        , key = "${Docker.lowerName dep}${netSeg}"
                        }
                      ]

          let genericNetwork = Network.Type.Devnet

          let baseImage =
              -- Only the services whose Dockerfile is assembled from the shared
              -- base-deps fragment take this; the *-configured/-profiled images
              -- are FROM an already-built mina image, and rosetta has its own
              -- (postgres-heavy) base.
                Some (BaseImage.imageFor spec.debVersion spec.arch)

          let dependsOnGeneric =
                  deps
                # [ { name = genericBuildName spec
                    , key =
                        "${Docker.lowerName
                             Docker.Type.DaemonGeneric}-${Network.lowerName
                                                            genericNetwork}-docker-image"
                    }
                  ]

          let size = Size.XLarge

          in  merge
                { DaemonAutoHardfork =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps =
                              withDocker
                                (Docker.Type.Daemon { network = network })
                          , service =
                              Docker.Type.DaemonAutoHardfork
                                { network = network }
                          , network = network
                          , base_image = baseImage
                          , deb_codename = spec.debVersion
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , docker_publish = spec.docker_publish
                          , deb_legacy_version = spec.deb_legacy_version
                          , size = size
                          }
                        ]
                , DaemonLegacyHardfork =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps =
                              withDocker
                                ( Docker.Type.DaemonLegacyHardfork
                                    { network = network }
                                )
                          , service =
                              Docker.Type.DaemonLegacyHardfork
                                { network = network }
                          , network = network
                          , base_image = baseImage
                          , deb_codename = spec.debVersion
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , docker_publish = spec.docker_publish
                          , deb_legacy_version = spec.deb_legacy_version
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , DaemonGeneric =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.DaemonGeneric
                    , network = genericNetwork
                    , base_image = baseImage
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_legacy_version = spec.deb_legacy_version
                    , generic = True
                    , verify = True
                    , arch = spec.arch
                    , size = size
                    }
                  ]
                , DaemonProfiled =
                        \(args : { profile : Profiles.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = dependsOnGeneric
                          , service = entry.service
                          , network = network
                          , deb_codename = spec.debVersion
                          , docker_publish = spec.docker_publish
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , deb_install_mode =
                              DockerImage.DebianInstallMode.DownloadOnly
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , Daemon =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = dependsOnGeneric
                          , service = Docker.Type.Daemon { network = network }
                          , network = network
                          , deb_codename = spec.debVersion
                          , docker_publish = spec.docker_publish
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , deb_install_mode =
                              DockerImage.DebianInstallMode.DownloadOnly
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , TxTools =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.TxTools
                    , network = network
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , DelegationVerifier =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.DelegationVerifier
                    , network = network
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_legacy_version = spec.deb_legacy_version
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , Archive =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = deps
                          , service = Docker.Type.Archive { network = network }
                          , network = network
                          , base_image = baseImage
                          , deb_codename = spec.debVersion
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , docker_publish = spec.docker_publish
                          , deb_legacy_version = spec.deb_legacy_version
                          , verify = True
                          , arch = spec.arch
                          , if_ = spec.if_
                          , size = size
                          }
                        ]
                , RosettaGeneric =
                  [ DockerImage.ReleaseSpec::{
                    , deps = deps
                    , service = Docker.Type.RosettaGeneric
                    , network = network
                    , deb_codename = spec.debVersion
                    , deb_profile = profile
                    , build_flags = spec.buildFlags
                    , docker_publish = spec.docker_publish
                    , deb_legacy_version = spec.deb_legacy_version
                    , generic = True
                    , verify = True
                    , arch = spec.arch
                    , if_ = spec.if_
                    , size = size
                    }
                  ]
                , Rosetta =
                        \(args : { network : Network.Type })
                    ->  [ DockerImage.ReleaseSpec::{
                          , deps = withDocker Docker.Type.RosettaGeneric
                          , service = Docker.Type.Rosetta { network = network }
                          , network = network
                          , deb_profile = profile
                          , build_flags = spec.buildFlags
                          , image_name = Some
                              ( Docker.dockerName
                                  (Docker.Type.Rosetta { network = network })
                              )
                          , deb_codename = spec.debVersion
                          , docker_publish = spec.docker_publish
                          , deb_install_mode =
                              DockerImage.DebianInstallMode.DownloadOnly
                          , arch = spec.arch
                          , size = size
                          }
                        ]
                , Toolchain = [] : List DockerImage.ReleaseSpec.Type
                , Base = [] : List DockerImage.ReleaseSpec.Type
                }
                entry.service

let docker_commands
    -- Packaging builds images and writes them to the CI cache. It does not
    -- push them: pushing is what the publish stage does, for images exactly as
    -- for debians, so a release puts out everything or nothing.
    --
    -- These jobs are shared -- nightly runs them too -- and nightly has no
    -- publish stage, which is now the whole reason nightly cannot push. It is
    -- structural rather than conditional: there is no flag to set, and no way
    -- to set it wrong.
    : PackagingSpec.Type -> List Command.Type
    =     \(spec : PackagingSpec.Type)
      ->  let services =
                List/concatMap
                  Artifact.Type
                  DockerService
                  expandDockerServices
                  spec.artifacts

          let flattened_docker_steps =
                List/concatMap
                  DockerService
                  DockerImage.ReleaseSpec.Type
                  (\(e : DockerService) -> docker_step e spec)
                  services

          in  List/map
                DockerImage.ReleaseSpec.Type
                Command.Type
                (     \(s : DockerImage.ReleaseSpec.Type)
                  ->  DockerImage.generateStep
                        (     s
                          //  { deb_release =
                                  DebianChannel.effective spec.channel
                              , docker_repo = spec.docker_repo
                              , docker_publish = DockerPublish.Type.Disabled
                              , save_to_ci_cache = True
                              }
                        )
                )
                flattened_docker_steps

let pipelineBuilder
    : PackagingSpec.Type -> List Command.Type -> Pipeline.Config.Type
    =     \(spec : PackagingSpec.Type)
      ->  \(steps : List Command.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen spec.debVersion
            , path = "Release"
            , name = "${spec.prefix}${nameSuffix spec}"
            , tags = spec.tags
            , scope = spec.scope
            , includeIf = spec.includeIf
            , excludeIf = spec.excludeIf
            }
          , steps = steps
          }

let onlyDebianPipeline
    -- The one job that still compiles AND packages in a single step
    -- (build_artifacts), rather than restoring the tree an app build produced.
    -- So this is the one place PackagingSpec drives a compile too; splitting it
    -- like the other codenames would make the name exact.
    : PackagingSpec.Type -> Pipeline.Config.Type
    =     \(spec : PackagingSpec.Type)
      ->  pipelineBuilder spec [ build_artifacts spec ]

let appsPipeline
    : AppsSpec.Type -> Pipeline.Config.Type
    =     \(spec : AppsSpec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen spec.debVersion
            , path = "Release"
            , name =
                "${spec.prefix}${spec.nameSegment}${DebianVersions.capitalName
                                                      spec.debVersion}${BuildFlags.toSuffixUppercase
                                                                          spec.buildFlags}${Arch.nameSuffix
                                                                                              spec.arch}Apps"
            , tags = spec.tags
            , scope = spec.scope
            , includeIf = spec.includeIf
            , excludeIf = spec.excludeIf
            }
          , steps = [ build_apps spec ]
          }

let packagePipeline
    : PackagingSpec.Type -> Pipeline.Config.Type
    =     \(spec : PackagingSpec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.packageDirtyWhen
            , path = "Release"
            , name = "${spec.prefix}${nameSuffix spec}"
            , tags = spec.tags
            , scope = spec.scope
            , includeIf = spec.includeIf
            , excludeIf = spec.excludeIf
            }
          , steps = [ build_debian spec ] # docker_commands spec
          }

in  { onlyDebianPipeline = onlyDebianPipeline
    , appsPipeline = appsPipeline
    , packagePipeline = packagePipeline
    , PackagingSpec = PackagingSpec
    , AppsSpec = AppsSpec
    , labelSuffix = labelSuffix
    , buildArtifacts = build_artifacts
    , buildApps = build_apps
    , buildDebian = build_debian
    , buildDebianFromApps = buildDebianFromApps
    , debianTokens = debianTokens
    }
