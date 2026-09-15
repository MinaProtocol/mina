-- Docker plugin specific settings for commands
--
-- See https://github.com/buildkite-plugins/docker-buildkite-plugin for options
-- if you'd like to extend this definition for example
--
-- TODO: Move volume to something in the cloud or artifacts from gcloud storage
--
-- Default `environment` passes GITHUB_TOKEN + GIT_CONFIG_PARAMETERS through:
-- the agent exports a github.com-scoped git credential helper in
-- GIT_CONFIG_PARAMETERS (gitops-infrastructure buildkite-agents), so git inside
-- the container can answer GitHub's 401 on unauthenticated clones
-- (github.com/orgs/community/discussions/206581) instead of dying with
-- "could not read Username for 'https://github.com'".

{ Type =
    { image : Text
    , shell : Optional (List Text)
    , propagate-environment : Bool
    , mount-buildkite-agent : Bool
    , mount-workdir : Bool
    , privileged : Bool
    , environment : List Text
    , user : Optional Text
    }
, default =
    { shell = Some [ "/bin/sh", "-e", "-c" ]
    , propagate-environment = True
    , mount-buildkite-agent = False
    , mount-workdir = False
    , privileged = False
    , environment =
      [ "BUILDKITE_AGENT_ACCESS_TOKEN"
      , "GITHUB_TOKEN"
      , "GIT_CONFIG_PARAMETERS"
      ]
    , user = None Text
    }
}
