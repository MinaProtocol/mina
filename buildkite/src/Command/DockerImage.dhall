-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall


let ReleaseSpec = {
  Type = {
    deps : List Command.TaggedKey.Type,
    network: Text,
    service: Text,
    version: Text,
    branch: Text,
    deb_codename: Text,
    deb_release: Text,
    deb_version: Text,
    extra_args: List Text,
    step_key: Text
  },
  default = {
    deps = [] : List Command.TaggedKey.Type,
    network = "devnet",
    version = "\\\${MINA_DOCKER_TAG}",
    service = "\\\${MINA_SERVICE}",
    branch = "\\\${BUILDKITE_BRANCH}",
    deb_codename = "stretch",
    deb_release = "\\\${MINA_DEB_RELEASE}",
    deb_version = "\\\${MINA_DEB_VERSION}",
    extra_args = [] : List Text,
    step_key = "daemon-devnet-docker-image"
  }
}

let generateStep = \(spec : ReleaseSpec.Type) ->

    let commands : List Cmd.Type =
    [
        Cmd.run (
          "export MINA_DEB_CODENAME=${spec.deb_codename} && source ./buildkite/scripts/export-git-env-vars.sh && ./scripts/release-docker.sh " ++
              "--service ${spec.service} --version ${spec.version} --network ${spec.network} --branch ${spec.branch} --deb-codename ${spec.deb_codename} --deb-release ${spec.deb_release} --deb-version ${spec.deb_version}"
              ++ Prelude.Text.concatSep "" (Prelude.List.map Text Text (\(arg : Text) -> " --extra-arg ${arg}") spec.extra_args)
        )
    ]

    in

    Command.build
      Command.Config::{
        commands  = commands,
        label = "Docker: ${spec.step_key}",
        key = spec.step_key,
        target = Size.XLarge,
        docker_login = Some DockerLogin::{=},
        depends_on = spec.deps
      }

in

{ generateStep = generateStep, ReleaseSpec = ReleaseSpec }
