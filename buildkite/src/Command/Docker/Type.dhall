-- Docker plugin specific settings for commands
--
-- See https://github.com/buildkite-plugins/docker-buildkite-plugin for options
-- if you'd like to extend this definition for example
--
-- TODO: Move volume to something in the cloud or artifacts from gcloud storage

{
  Type = {
     image: Text,
     `propagate-environment`: Bool,
     `mount-buildkite-agent`: Bool,
     `mount-workdir`: Bool,
     environment: List Text
  },
  default = {
    `propagate-environment` = True,
    `mount-buildkite-agent` = False,
    `mount-workdir` = False,
    environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
  }
}
