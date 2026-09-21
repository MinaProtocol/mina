-- Submodule credentials plugin settings for commands
--
-- The plugin sets BUILDKITE_GIT_SUBMODULE_CLONE_CONFIG in an environment hook,
-- so that the agent can clone submodules that live in a private GitHub
-- organization. Buildkite agent 3.133.0 and later refuse that variable when a
-- pipeline sets it directly.
--
-- The plugin holds no token. It reads one from the variable named by token-env.
--
-- See https://github.com/MinaProtocol/submodule-credentials-buildkite-plugin

{ Type = { org : Text, token-env : Text }
, default = { org = "o1-labs", token-env = "GH_SUBMODULE_TOKEN" }
}
