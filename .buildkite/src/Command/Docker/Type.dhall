{
  Type = {
     image: Text,
     `propagate-environment`: Bool,
     `mount-buildkite-agent`: Bool,
     environment: List Text
  },
  default = {
    `propagate-environment` = True,
    `mount-buildkite-agent` = False,
    environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
  }
}
