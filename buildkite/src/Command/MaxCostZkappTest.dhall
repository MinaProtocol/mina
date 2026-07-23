let Command = ./Base.dhall

let RunInToolchain = ./RunInToolchain.dhall

let Size = ./Size.dhall

let step =
          \(dependsOn : List Command.TaggedKey.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "buildkite/scripts/tests/max-cost-zkapp-test.sh"
            , label = "Max-cost zkapp test"
            , key = "max-cost-zkapp-test"
            , target = Size.Large
            , depends_on = dependsOn
            }

in  { step = step }
