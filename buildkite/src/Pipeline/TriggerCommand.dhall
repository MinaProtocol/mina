let Cmd = ../Lib/Cmds.dhall
in

(
  \(dhallPipelineRelativeToBuildKiteDir : Text) ->
      Cmd.quietly "dhall-to-yaml --quoted <<< '(./buildkite/${dhallPipelineRelativeToBuildKiteDir}).pipeline' | BUILDKITE_AGENT_META_DATA_size=small buildkite-agent pipeline upload"
) : Text -> Cmd.Type
