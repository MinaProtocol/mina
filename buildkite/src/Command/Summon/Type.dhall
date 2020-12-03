-- Summon plugin specific settings for commands
--
-- See https://github.com/angaza/summon-buildkite-plugin for options
-- if you'd like to extend this definition for example

{
  Type = {
    `secrets-file`: Text,
    provider: Text,
    environment: Text,
    substitutions: List Text
  },
  default = {
    `secrets-file` = "./secrets.yml",
    provider = "summon-aws-secrets",
    environment = "",
    substitutions = [] : List Text
  }
}
