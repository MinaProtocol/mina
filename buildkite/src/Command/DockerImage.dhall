-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Command = ./Base.dhall

let Size = ./Size.dhall

let Profiles = ../Constants/Profiles.dhall

let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let ReleaseSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , network : Text
          , service : Text
          , version : Text
          , branch : Text
          , repo : Text
          , no_cache : Bool
          , deb_codename : Text
          , deb_release : Text
          , deb_version : Text
          , deb_profile : Profiles.Type
          , deb_repo : DebianRepo.Type
          , build_flags : BuildFlags.Type
          , step_key : Text
          , if : Optional B/If
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , network = "devnet"
          , version = "\\\${MINA_DOCKER_TAG}"
          , service = Artifacts.dockerName Artifacts.Type.Daemon
          , branch = "\\\${BUILDKITE_BRANCH}"
          , repo = "\\\${BUILDKITE_REPO}"
          , deb_codename = "bullseye"
          , deb_release = "\\\${MINA_DEB_RELEASE}"
          , deb_version = "\\\${MINA_DEB_VERSION}"
          , deb_profile = Profiles.Type.Standard
          , build_flags = BuildFlags.Type.None
          , deb_repo = DebianRepo.Type.PackagesO1Test
          , no_cache = False
          , step_key = "daemon-standard-docker-image"
          , if = None B/If
          }
      }

let generateStep =
          \(spec : ReleaseSpec.Type)
      ->  let exportMinaDebCmd = "export MINA_DEB_CODENAME=${spec.deb_codename}"

          let maybeCacheOption = if spec.no_cache then "--no-cache" else ""

          let buildDockerCmd =
                    "./scripts/docker/build.sh"
                ++  " --service ${spec.service}"
                ++  " --network ${spec.network}"
                ++  " --version ${spec.version}"
                ++  " --branch ${spec.branch}"
                ++  " ${maybeCacheOption} "
                ++  " --deb-codename ${spec.deb_codename}"
                ++  " --deb-repo ${DebianRepo.address spec.deb_repo}"
                ++  " --deb-release ${spec.deb_release}"
                ++  " --deb-version ${spec.deb_version}"
                ++  " --deb-profile ${Profiles.lowerName spec.deb_profile}"
                ++  " --deb-build-flags ${BuildFlags.lowerName
                                            spec.build_flags}"
                ++  " --repo ${spec.repo}"

          let releaseDockerCmd =
                    "./scripts/docker/release.sh"
                ++  " --service ${spec.service}"
                ++  " --version ${spec.version}"
                ++  " --network ${spec.network}"
                ++  " --deb-codename ${spec.deb_codename}"
                ++  " --deb-version ${spec.deb_version}"
                ++  " --deb-profile ${Profiles.lowerName spec.deb_profile}"
                ++  " --deb-build-flags ${BuildFlags.lowerName
                                            spec.build_flags}"

          let remoteRepoCmds =
                [ Cmd.run
                    (     exportMinaDebCmd
                      ++  " && source ./buildkite/scripts/export-git-env-vars.sh "
                      ++  " && "
                      ++  buildDockerCmd
                      ++  " && "
                      ++  releaseDockerCmd
                    )
                ]

          let commands =
                merge
                  { PackagesO1Test = remoteRepoCmds
                  , Unstable = remoteRepoCmds
                  , Nightly = remoteRepoCmds
                  , Local =
                    [ Cmd.run
                        (     exportMinaDebCmd
                          ++  " && apt update && apt install -y aptly"
                          ++  " && ./buildkite/scripts/debian/start_local_repo.sh"
                          ++  " && source ./buildkite/scripts/export-git-env-vars.sh "
                          ++  " && "
                          ++  buildDockerCmd
                          ++  " && "
                          ++  releaseDockerCmd
                          ++  " && ./scripts/debian/aptly.sh stop"
                        )
                    ]
                  }
                  spec.deb_repo

          in  Command.build
                Command.Config::{
                , commands = commands
                , label = "Docker: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.XLarge
                , docker_login = Some DockerLogin::{=}
                , depends_on = spec.deps
                , if = spec.if
                }

in  { generateStep = generateStep, ReleaseSpec = ReleaseSpec }
