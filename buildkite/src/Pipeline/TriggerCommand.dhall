let Cmd = ../Lib/Cmds.dhall

in    (     \(dhallPipelineRelativeToBuildKiteDir : Text)
        ->  Cmd.quietly
              "dhall-to-yaml --quoted <<< '(./buildkite/${dhallPipelineRelativeToBuildKiteDir}).pipeline'"
      )
    : Text -> Cmd.Type
