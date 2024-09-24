-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Command = ./Base.dhall

let Size = ./Size.dhall

let Profiles = ../Constants/Profiles.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Network = ../Constants/Network.dhall

let Artifacts = ../Constants/Artifacts.dhall

let ReleaseSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , network : Text
          , service : Artifacts.Type
          , version : Text
          , branch : Text
          , repo : Text
          , no_cache : Bool
          , deb_codename : DebianVersions.DebVersion
          , deb_release : Text
          , deb_version : Text
          , deb_profile : Profiles.Type
          , deb_repo : DebianRepo.Type
          , build_flags : BuildFlags.Type
          , step_key_suffix : Text
          , if : Optional B/If
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , network = "${Network.lowerName Network.Type.Devnet}"
          , version = "\\\${MINA_DOCKER_TAG}"
          , service = Artifacts.Type.Daemon
          , branch = "\\\${BUILDKITE_BRANCH}"
          , repo = "\\\${BUILDKITE_REPO}"
          , deb_codename = DebianVersions.DebVersion.Bullseye
          , deb_release = "\\\${MINA_DEB_RELEASE}"
          , deb_version = "\\\${MINA_DEB_VERSION}"
          , deb_profile = Profiles.Type.Standard
          , build_flags = BuildFlags.Type.None
          , deb_repo = DebianRepo.Type.PackagesO1Test
          , no_cache = False
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
                       spec.service} ${spec.network} ${DebianVersions.capitalName
                                                         spec.deb_codename} ${Profiles.toSuffixUppercase
                                                                                spec.deb_profile} ${BuildFlags.toSuffixUppercase
                                                                                                      spec.build_flags}"

let generateStep =
          \(spec : ReleaseSpec.Type)
      ->  let exportMinaDebCmd =
                "export MINA_DEB_CODENAME=${DebianVersions.lowerName
                                              spec.deb_codename}"

          let maybeCacheOption = if spec.no_cache then "--no-cache" else ""

          let buildDockerCmd =
                    "./scripts/docker/build.sh"
                ++  " --service ${Artifacts.dockerName spec.service}"
                ++  " --network ${spec.network}"
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
                    "./scripts/docker/release.sh"
                ++  " --service ${Artifacts.dockerName spec.service}"
                ++  " --version ${spec.version}"
                ++  " --network ${spec.network}"
                ++  " --deb-codename ${DebianVersions.lowerName
                                         spec.deb_codename}"
                ++  " --deb-version ${spec.deb_version}"
                ++  " --deb-profile ${Profiles.lowerName spec.deb_profile}"
                ++  " --deb-build-flags ${BuildFlags.lowerName
                                            spec.build_flags}"

          let commands =
                merge
                  { PackagesO1Test =
                    [ Cmd.run
                        (     exportMinaDebCmd
                          ++  " && source ./buildkite/scripts/export-git-env-vars.sh "
                          ++  " && "
                          ++  buildDockerCmd
                          ++  " && "
                          ++  releaseDockerCmd
                        )
                    ]
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
