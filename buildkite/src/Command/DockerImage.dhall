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

let DebianVersions = ../Constants/DebianVersions.dhall

let Network = ../Constants/Network.dhall

let DockerPublish = ../Constants/DockerPublish.dhall

let ReleaseSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , network : Network.Type
          , service : Artifacts.Type
          , version : Text
          , branch : Text
          , repo : Text
          , no_cache : Bool
          , no_debian : Bool
          , deb_codename : DebianVersions.DebVersion
          , deb_release : Text
          , deb_version : Text
          , deb_profile : Profiles.Type
          , deb_repo : DebianRepo.Type
          , build_flags : BuildFlags.Type
          , step_key_suffix : Text
          , docker_publish : DockerPublish.Type
          , if : Optional B/If
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , network = Network.Type.Berkeley
          , version = "\\\${MINA_DOCKER_TAG}"
          , service = Artifacts.Type.Daemon
          , branch = "\\\${BUILDKITE_BRANCH}"
          , repo = "\\\${BUILDKITE_REPO}"
          , deb_codename = DebianVersions.DebVersion.Bullseye
          , deb_release = "\\\${MINA_DEB_RELEASE}"
          , deb_version = "\\\${MINA_DEB_VERSION}"
          , deb_profile = Profiles.Type.Standard
          , build_flags = BuildFlags.Type.None
          , deb_repo = DebianRepo.Type.Local
          , docker_publish = DockerPublish.Type.Essential
          , no_cache = False
          , no_debian = False
          , step_key_suffix = "-docker-image"
          , if = None B/If
          }
      }

let stepKey =
          \(spec : ReleaseSpec.Type)
      ->  "${Artifacts.lowerName
               spec.service}${Profiles.toLabelSegment
                                spec.deb_profile}${BuildFlags.toLabelSegment
                                                     spec.build_flags}${spec.step_key_suffix}"

let stepLabel =
          \(spec : ReleaseSpec.Type)
      ->  "Docker: ${Artifacts.capitalName
                       spec.service} ${Network.capitalName
                                         spec.network} ${DebianVersions.capitalName
                                                           spec.deb_codename} ${Profiles.toSuffixUppercase
                                                                                  spec.deb_profile} ${BuildFlags.toSuffixUppercase
                                                                                                        spec.build_flags}"

let generateStep =
          \(spec : ReleaseSpec.Type)
      ->  let exportMinaDebCmd =
                "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                              spec.deb_codename}"

          let maybeCacheOption = if spec.no_cache then "--no-cache" else ""

          let maybeStartDebianRepo =
                      if spec.no_debian

                then  " && echo Skipping local debian repo setup "

                else      " && apt update && apt install -y aptly"
                      ++  " && ./buildkite/scripts/debian/start_local_repo.sh"

          let maybeStopDebianRepo =
                      if spec.no_debian

                then  " && echo Skipping local debian repo teardown "

                else  " && ./scripts/debian/aptly.sh stop"

          let buildDockerCmd =
                    "./scripts/docker/build.sh"
                ++  " --service ${Artifacts.dockerName spec.service}"
                ++  " --network ${Network.lowerName spec.network}"
                ++  " --version ${spec.version}"
                ++  " --branch ${spec.branch}"
                ++  " ${maybeCacheOption} "
                ++  " --deb-codename ${DebianVersions.lowerName
                                         spec.deb_codename}"
                ++  " --deb-repo ${DebianRepo.address spec.deb_repo}"
                ++  " --deb-release ${spec.deb_release}"
                ++  " --deb-version ${spec.deb_version}"
                ++  " --deb-profile ${Profiles.lowerName spec.deb_profile}"
                ++  " --deb-build-flags ${BuildFlags.lowerName
                                            spec.build_flags}"
                ++  " --repo ${spec.repo}"

          let releaseDockerCmd =
                      if DockerPublish.shouldPublish
                           spec.docker_publish
                           spec.service

                then      "./scripts/docker/release.sh"
                      ++  " --service ${Artifacts.dockerName spec.service}"
                      ++  " --version ${spec.version}"
                      ++  " --network ${Network.lowerName spec.network}"
                      ++  " --deb-codename ${DebianVersions.lowerName
                                               spec.deb_codename}"
                      ++  " --deb-version ${spec.deb_version}"
                      ++  " --deb-profile ${Profiles.lowerName
                                              spec.deb_profile}"
                      ++  " --deb-build-flags ${BuildFlags.lowerName
                                                  spec.build_flags}"

                else  " echo In order to ensure storage optimization, skipping publishing docker as this is not essential one or publishing is disabled . Docker publish setting is set to  ${DockerPublish.show
                                                                                                                                                                                                spec.docker_publish}."

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
                  { Unstable = remoteRepoCmds
                  , Nightly = remoteRepoCmds
                  , Stable = remoteRepoCmds
                  , Local =
                    [ Cmd.run
                        (     exportMinaDebCmd
                          ++  maybeStartDebianRepo
                          ++  " && source ./buildkite/scripts/export-git-env-vars.sh "
                          ++  " && "
                          ++  buildDockerCmd
                          ++  " && "
                          ++  releaseDockerCmd
                          ++  maybeStopDebianRepo
                        )
                    ]
                  }
                  spec.deb_repo

          in  Command.build
                Command.Config::{
                , commands = commands
                , label = "${stepLabel spec}"
                , key = "${stepKey spec}"
                , target = Size.XLarge
                , docker_login = Some DockerLogin::{=}
                , depends_on = spec.deps
                , if = spec.if
                }

in  { generateStep = generateStep
    , ReleaseSpec = ReleaseSpec
    , stepKey = stepKey
    , stepLabel = stepLabel
    }
