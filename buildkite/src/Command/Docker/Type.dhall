-- Docker plugin specific settings for commands
--
-- See https://github.com/buildkite-plugins/docker-buildkite-plugin for options
-- if you'd like to extend this definition for example
--
-- TODO: Move volume to something in the cloud or artifacts from gcloud storage

{
  Type = {
     image: Text,
     shell: Optional (List Text),
     `propagate-environment`: Bool,
     `mount-buildkite-agent`: Bool,
     `mount-workdir`: Bool,
     privileged: Bool,
     environment: List Text
  },
  default = {
    shell = Some ["/bin/sh", "-e", "-c"],
    `propagate-environment` = True,
    `mount-buildkite-agent` = False,
    `mount-workdir` = False,
    privileged = False,
    environment = [ "BUILDKITE_AGENT_ACCESS_TOKEN" ]
  }
}
