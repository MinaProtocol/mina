let Cmd = ../Lib/Cmds.dhall
in

(
  \(dhallPipelineRelativeToBuildKiteDir : Text) ->
      Cmd.quietly "dhall-to-yaml --quoted <<< './buildkite/${dhallPipelineRelativeToBuildKiteDir}' | buildkite-agent pipeline upload"
) : Text -> Cmd.Type
