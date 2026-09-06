let Prelude = ../../External/Prelude.dhall

let Extensions = ../../Lib/Extensions.dhall

let join = Extensions.join

let Docker = ../../Constants/Docker/Package.dhall

let Network = ../../Constants/Network.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Arch = ../../Constants/Arch.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Profiles = ../../Constants/Profiles.dhall

let DockerRepo = ../../Constants/DockerRepo.dhall

let Spec =
      { Type =
          { artifacts : List Docker.Type
          , networks : List Network.Type
          , version : Text
          , codenames : List DebianVersions.DebVersion
          , published_to_docker_io : Bool
          , profile : Profiles.Type
          , archs : List Arch.Type
          , buildFlag : BuildFlags.Type
          , repo : DockerRepo.Type
          , generic : Bool
          }
      , default =
          { artifacts = [] : List Docker.Type
          , networks = [ Network.Type.Mainnet, Network.Type.Devnet ]
          , codenames =
            [ DebianVersions.DebVersion.Focal
            , DebianVersions.DebVersion.Bullseye
            ]
          , published_to_docker_io = False
          , profile = Profiles.Type.Devnet
          , buildFlag = BuildFlags.Type.None
          , archs = [ Arch.Type.Amd64 ]
          , repo = DockerRepo.Type.InternalEurope
          , generic = False
          }
      }

let joinArtifacts
    : Spec.Type -> Text
    = \(spec : Spec.Type) -> join "," (Docker.dockerNames spec.artifacts)

let joinNetworks
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  join
            ","
            ( Prelude.List.map
                Network.Type
                Text
                (\(network : Network.Type) -> Network.debianSuffix network)
                spec.networks
            )

let joinCodenames
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  join
            ","
            ( Prelude.List.map
                DebianVersions.DebVersion
                Text
                (     \(debian : DebianVersions.DebVersion)
                  ->  DebianVersions.lowerName debian
                )
                spec.codenames
            )

let joinArchitectures
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  join
            ","
            ( Prelude.List.map
                Arch.Type
                Text
                (\(arch : Arch.Type) -> Arch.lowerName arch)
                spec.archs
            )

let verify
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  let archFlag = "--archs " ++ joinArchitectures spec ++ " "

          let profileFlag = "--profile ${Profiles.lowerName spec.profile} "

          let buildFlag =
                merge
                  { None = ""
                  , Instrumented =
                      "--build-flag ${BuildFlags.lowerName spec.buildFlag} "
                  }
                  spec.buildFlag

          let genericFlag = if spec.generic then " --generic " else ""

          in      ". ./buildkite/scripts/export-git-env-vars.sh && "
              ++  "./buildkite/scripts/release/manager.sh verify "
              ++  "--artifacts ${joinArtifacts spec} "
              ++  "--networks ${joinNetworks spec} "
              ++  "--version ${spec.version} "
              ++  "--codenames ${joinCodenames spec} "
              ++  "--docker-repo ${DockerRepo.show spec.repo} "
              ++  profileFlag
              ++  archFlag
              ++  buildFlag
              ++  genericFlag
              ++  "--only-dockers "

in  { verify = verify, Spec = Spec }
