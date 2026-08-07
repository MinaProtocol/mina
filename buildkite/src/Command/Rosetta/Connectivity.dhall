let B = ../../External/Buildkite.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Network = ../../Constants/Network.dhall

let Dockers = ../../Constants/Docker/Versions.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Toolchain = ../../Constants/Toolchain.dhall

let Profiles = ../../Constants/Profiles.dhall

let Expr = ../../Pipeline/Expr.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Benchmarks = ../../Constants/Benchmarks.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let B/If = B.definitions/commandStep/properties/if/Type

let Spec =
      { Type =
          { dockerType : Dockers.Type
          , network : Network.Type
          , additionalDirtyWhen : List S.Type
          , softFail : B/SoftFail
          , syncTimeout : Natural
          , newBlockTimeout : Natural
          , profile : Profiles.Type
          , scope : List PipelineScope.Type
          , if_ : B/If
          , excludeIf : List Expr.Type
          , includeIf : List Expr.Type
          }
      , default =
          { dockerType = Dockers.Type.Bullseye
          , network = Network.Type.Devnet
          , additionalDirtyWhen = [] : List S.Type
          , softFail = B/SoftFail.Boolean False
          , syncTimeout = 1500
          , newBlockTimeout = 600
          , profile = Profiles.Type.Devnet
          , scope = PipelineScope.Full
          , includeIf = [] : List Expr.Type
          , excludeIf = [] : List Expr.Type
          , if_ =
              "build.pull_request.base_branch != \"develop\" && build.branch != \"develop\""
          }
      }

let bareBinaries =
          "mina.exe:mina"
      ++  ",archive.exe:mina-archive"
      ++  ",rosetta.exe:mina-rosetta"
      ++  ",libp2p_helper:libp2p_helper"

let envExports =
          \(spec : Spec.Type)
      ->  [ "MINA_NETWORK_DEB=${Network.lowerName spec.network}"
          , "MINA_DEB_CODENAME=${Dockers.lowerName spec.dockerType}"
          , "MINA_PROFILE=${Profiles.lowerName spec.profile}"
          , "APPS_BARE_BINARIES=${bareBinaries}"
          ]

let connectivityScript =
          \(spec : Spec.Type)
      ->      "./buildkite/scripts/tests/rosetta/connectivity.sh"
          ++  " --network ${Network.lowerName spec.network}"
          ++  " --sync-timeout ${Natural/show spec.syncTimeout}"
          ++  " --new-block-timeout ${Natural/show spec.newBlockTimeout}"
          ++  " --run-compatibility-test develop"
          ++  " --run-load-test"
          ++  " --branch \\\${BUILDKITE_BRANCH}"
          ++  " --commit \\\${BUILDKITE_COMMIT}"
          ++  " --metrics-mode"
          ++  " --perf-output-file /workdir/rosetta.perf"

let command
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  Toolchain.select
                    Toolchain.Spec::{ debVersion = spec.dockerType }
                    (envExports spec)
                    (connectivityScript spec)
                # RunInToolchain.runInDefaultToolchain
                    (Benchmarks.toEnvList Benchmarks.Type::{=})
                    "./buildkite/scripts/bench/send.sh"
            , label =
                "Rosetta ${Network.lowerName spec.network} connectivity test "
            , key =
                "rosetta-${Network.lowerName spec.network}-connectivity-test"
            , target = Size.XLarge
            , artifact_paths = [ S.contains "test_output/artifacts/**/*" ]
            , soft_fail = Some spec.softFail
            , if_ = Some spec.if_
            , depends_on =
                DebianVersions.appDependsOn
                  DebianVersions.DepsSpec::{
                  , deb_version = spec.dockerType
                  , network = spec.network
                  , profile = spec.profile
                  }
            }

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen =
                  [ S.strictlyStart (S.contains "src")
                  , S.exactly
                      "buildkite/src/Jobs/Test/RosettaIntegrationTests"
                      "dhall"
                  , S.exactly
                      "buildkite/src/Jobs/Test/Rosetta${Network.capitalName
                                                          spec.network}Connect"
                      "dhall"
                  , S.exactly
                      "buildkite/src/Command/Rosetta/Connectivity"
                      "dhall"
                  , S.strictlyStart
                      (S.contains "buildkite/scripts/tests/rosetta")
                  , S.strictlyStart (S.contains "scripts/tests/rosetta")
                  , S.exactly "buildkite/scripts/debian/restore-or-install" "sh"
                  , S.strictlyStart (S.contains "buildkite/scripts/apps")
                  , S.strictlyStart (S.contains "genesis_ledgers")
                  ]
                # spec.additionalDirtyWhen
            , path = "Test"
            , name = "Rosetta${Network.capitalName spec.network}Connect"
            , scope = spec.scope
            , excludeIf = spec.excludeIf
            , includeIf = spec.includeIf
            , tags =
              [ PipelineTag.Type.Long
              , PipelineTag.Type.Test
              , PipelineTag.Type.Stable
              , PipelineTag.Type.Rosetta
              ]
            }
          , steps = [ command spec ]
          }

in  { command = command, pipeline = pipeline, Spec = Spec }
