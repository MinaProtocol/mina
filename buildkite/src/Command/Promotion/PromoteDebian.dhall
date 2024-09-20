let B = ../../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Package = ../../Constants/DebianPackage.dhall

let Network = ../../Constants/Network.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Profiles = ../../Constants/Profiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Toolchain = ../../Constants/Toolchain.dhall

let Command = ../Base.dhall

let Size = ../Size.dhall

let PromoteDebianSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , package : Package.Type
          , version : Text
          , new_version : Text
          , architecture : Text
          , network : Network.Type
          , codename : DebianVersions.DebVersion
          , from_channel : DebianChannel.Type
          , to_channel : DebianChannel.Type
          , profile : Profiles.Type
          , remove_profile_from_name : Bool
          , step_key : Text
          , if : Optional B/If
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , package = Package.Type.LogProc
          , version = "\\\\\$MINA_DEB_VERSION"
          , new_version = "\\\\\$MINA_DEB_VERSION"
          , architecture = "amd64"
          , network = Network.Type.Berkeley
          , codename = DebianVersions.DebVersion.Bullseye
          , from_channel = DebianChannel.Type.Unstable
          , to_channel = DebianChannel.Type.NightlyCompatible
          , profile = Profiles.Type.Standard
          , remove_profile_from_name = False
          , step_key = "promote-debian-package"
          , if = None B/If
          }
      }

let promoteDebianStep =
          \(spec : PromoteDebianSpec.Type)
      ->  let package_name
              : Text
              = Package.debianName spec.package spec.profile spec.network

          let new_name =
                      if spec.remove_profile_from_name

                then  "--new-name ${Package.debianName
                                      spec.package
                                      Profiles.Type.Standard
                                      spec.network}"

                else  ""

          in  Command.build
                Command.Config::{
                , commands =
                    Toolchain.runner
                      DebianVersions.DebVersion.Bullseye
                      [ "AWS_ACCESS_KEY_ID"
                      , "AWS_SECRET_ACCESS_KEY"
                      , "FROM_VERSION_MANUAL"
                      ]
                      ". ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/debian/promote.sh --package ${package_name} --version ${spec.version}  --new-version ${spec.new_version}  --architecture ${spec.architecture}  --codename ${DebianVersions.lowerName
                                                                                                                                                                                                                                                         spec.codename}  --from-component ${DebianChannel.lowerName
                                                                                                                                                                                                                                                                                              spec.from_channel}  --to-component ${DebianChannel.lowerName
                                                                                                                                                                                                                                                                                                                                     spec.to_channel} ${new_name}"
                , label = "Debian: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.Small
                , depends_on = spec.deps
                , if = spec.if
                }

in  { PromoteDebianSpec = PromoteDebianSpec
    , promoteDebianStep = promoteDebianStep
    }
