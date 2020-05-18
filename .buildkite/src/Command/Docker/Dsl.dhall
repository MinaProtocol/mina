-- Docker plugin specific settings for commands
--
-- See https://github.com/buildkite-plugins/docker-buildkite-plugin for options
-- if you'd like to extend this definition for example
--
-- TODO: Move volume to something in the cloud or artifacts from gcloud storage

let Docker = ./Type.dhall

let Config = {
  Type = {
    image: Text
  },
  default = {=}
}

let build : Config.Type -> Docker.Type = \(c: Config.Type) ->
  Docker::{ image = c.image }

in

{Config = Config, build = build }

