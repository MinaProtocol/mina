let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

let Engine = < Docker | Native >

let script =
          \(engine : Engine)
      ->  merge
            { Docker = "run-test-executive-docker.sh"
            , Native = "run-test-executive-native.sh"
            }
            engine

let extraArgs =
          \(engine : Engine)
      ->  merge
            { Docker = " ${DockerRepo.show DockerRepo.Type.InternalEurope}"
            , Native = ""
            }
            engine

let suffix =
      \(engine : Engine) -> merge { Docker = "local", Native = "native" } engine

let tests
    : List Text
    = [ "block-prod-prio"
      , "block-reward"
      , "chain-reliability"
      , "epoch-ledger"
      , "genesis-export"
      , "gossip-consis"
      , "medium-bootstrap"
      , "payments"
      , "peers-reliability"
      , "slot-end"
      , "verification-key"
      , "zkapps"
      , "zkapps-timing"
      , "zkapps-nonce"
      ]

let execute =
          \(engine : Engine)
      ->  \(testName : Text)
      ->  \(dependsOn : List Command.TaggedKey.Type)
      ->  Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "MINA_DEB_CODENAME=bullseye ; source ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/${script
                                                                                                                             engine} ${testName}${extraArgs
                                                                                                                                                    engine}"
              ]
            , artifact_paths =
              [ SelectFiles.contains "${testName}*.local.test.log" ]
            , label = "${testName} integration test ${suffix engine}"
            , key = "integration-test-${testName}-${suffix engine}"
            , target = Size.Integration
            , depends_on = dependsOn
            }

in  { Engine = Engine, Type = Command.Type, tests = tests, execute = execute }
