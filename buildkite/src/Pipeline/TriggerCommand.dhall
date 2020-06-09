(
  \(dhallPipelineRelativeToBuildKiteDir : Text) ->
      "dhall-to-yaml --quoted <<< './buildkite/${dhallPipelineRelativeToBuildKiteDir}' | buildkite-agent pipeline upload"
) : Text -> Text
