-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall


let defaultArtifactStep = { name = "Artifact", key = "build-artifact" }

let ReleaseSpec = {
  Type = {
    deps : List Command.TaggedKey.Type,
    deploy_env_file : Text,
    service: Text,
    version: Text,
    commit: Text,
    build_rosetta_override: Bool,
    extra_args: Text,
    step_key: Text
  },
  default = {
    deps = [] : List Command.TaggedKey.Type,
    deploy_env_file = "DOCKER_DEPLOY_ENV",
    network = "devnet",
    service = "\\\${MINA_SERVICE}",
    version = "\\\${MINA_VERSION}-${spec.network}",
    commit = "\\\${MINA_GIT_HASH}",
    deb_codename = "\\\${MINA_DEB_CODENAME}",
    deb_release = "\\\${MINA_DEB_RELEASE}",
    deb_version = "\\\${MINA_DEB_VERSION}",
    build_rosetta_override = False,
    extra_args = "",
    step_key = "${spec.network}-docker-image"
  }
}

let generateStep = \(spec : ReleaseSpec.Type) ->
    -- assume head or first dependency specified by spec represents the primary artifact dependency step
    let artifactUploadScope = Prelude.Optional.default Command.TaggedKey.Type defaultArtifactStep (List/head Command.TaggedKey.Type spec.deps) 

    let commands : List Cmd.Type =
    [
        Cmd.run (
          "if [ ! -f ${spec.deploy_env_file} ]; then " ++
              "buildkite-agent artifact download --build \\\$BUILDKITE_BUILD_ID --include-retried-jobs --step _${artifactUploadScope.name}-${artifactUploadScope.key} ${spec.deploy_env_file} .; " ++
          "fi"
        ),
        Cmd.run (
          "source ${spec.deploy_env_file} && ./scripts/release-docker.sh ${if spec.build_rosetta_override then "--build-rosetta " else ""} " ++
              "--service ${spec.service} --version ${spec.version} --commit ${spec.commit} --network ${spec.network} --deb-codename ${spec.deb_codename} --deb-release ${spec.deb_release} --deb-version ${spec.deb_version} --extra-args \\\"${spec.extra_args}\\\""
        )
    ]

    in

    Command.build
      Command.Config::{
        commands  = commands,
        label = "Build and release Docker images: ${spec.step_key}",
        key = spec.step_key,
        target = Size.XLarge,
        docker_login = Some DockerLogin::{=},
        depends_on = spec.deps
      }

in

{ generateStep = generateStep, ReleaseSpec = ReleaseSpec }
