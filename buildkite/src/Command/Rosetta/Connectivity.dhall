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

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let Arch = ../../Constants/Arch.dhall

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
          { dockerType = Dockers.Type.Bookworm
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
    -- The test app plus everything it starts. Restoring every binary here
    -- makes restore-or-install.sh skip the deb install, so anything the test
    -- calls must be listed. The guardian's helpers (auditor, archive-blocks)
    -- back-fill the gap between the archive dump and the daemon's first block;
    -- the healthcheck waits for the database.
          "rosetta_connectivity_test.exe:mina-rosetta-connectivity-test"
      ++  ",mina.exe:mina"
      ++  ",archive.exe:mina-archive"
      ++  ",mina_archive_healthcheck.exe:mina-archive-healthcheck"
      ++  ",rosetta.exe:mina-rosetta"
      ++  ",missing_blocks_auditor.exe:mina-missing-blocks-auditor"
      ++  ",archive_blocks.exe:mina-archive-blocks"
      ++  ",libp2p_helper:libp2p_helper"

let debs =
          \(spec : Spec.Type)
      ->  let network = Network.lowerName spec.network

          in      "mina-generic,mina-archive-${network},mina-rosetta-${network}"
              ++  ",mina-archive-generic,mina-rosetta-generic"
              ++  ",mina-${network}-profile,mina-tx-tools"

let envExports =
          \(spec : Spec.Type)
      ->  [ "MINA_DEB_CODENAME=${Dockers.lowerName spec.dockerType}"
          , "MINA_PROFILE=${Profiles.lowerName spec.profile}"
          , "APPS_BARE_BINARIES=${bareBinaries}"
          , "APPS_BARE_SCRIPTS=scripts/archive/missing-blocks-guardian.sh:mina-missing-blocks-guardian"
          ]

let connectivityScript =
          \(spec : Spec.Type)
      ->      "mina-rosetta-connectivity-test"
          ++  " --network ${Network.lowerName spec.network}"
          ++  " --postgres-uri postgres://postgres:postgres@localhost:5432/archive"
          ++  " --workdir \\\${HOME}/rosetta-connectivity"
          ++  " --sync-timeout ${Natural/show spec.syncTimeout}"
          ++  " --new-block-timeout ${Natural/show spec.newBlockTimeout}"
          ++  " --compatibility"
          ++  " --branch \\\${BUILDKITE_BRANCH}"
          ++  " --commit \\\${BUILDKITE_COMMIT}"
          ++  " --perf-output-file /workdir/rosetta.perf"

let command
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                      (envExports spec)
                      (None RunWithPostgres.ScriptOrArchive)
                      (Toolchain.imageFor spec.dockerType Arch.Type.Amd64)
                      (debs spec)
                      (connectivityScript spec)
                  ]
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
                  DebianVersions.DepsSpec::{ deb_version = spec.dockerType }
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
                  , S.exactly "scripts/archive/missing-blocks-guardian" "sh"
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
