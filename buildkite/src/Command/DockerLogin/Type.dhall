-- Docker Login plugin specific settings for commands
--
-- See https://github.com/buildkite-plugins/docker-login-buildkite-plugin for options
-- if you'd like to extend this definition for example

{
    Type = {
        username: Text,
        `password-env`: Text,
        server: Text
    },
    default = {
        username = "coda",
        `password-env` = "DOCKER_LOGIN_PASSWORD",
        server = ""
    }
}
