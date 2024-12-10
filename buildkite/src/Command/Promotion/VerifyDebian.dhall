let Package = ../../Constants/DebianPackage.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let Profiles = ../../Constants/Profiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Command = ../Base.dhall

let Size = ../Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let PromoteDebian = ./PromoteDebian.dhall

let promoteDebianVerificationStep =
          \(spec : PromoteDebian.PromoteDebianSpec.Type)
      ->  let name =
                      if spec.remove_profile_from_name

                then  "${Package.debianName
                           spec.package
                           Profiles.Type.Standard
                           spec.network}"

                else  Package.debianName spec.package spec.profile spec.network

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      "source buildkite/scripts/export-git-env-vars.sh && ./scripts/debian/verify.sh --bucket ${DebianRepo.bucket_or_default
                                                                                                                  spec.target_repo}--package ${name} --version ${spec.new_version} --codename ${DebianVersions.lowerName
                                                                                                                                                                                                  spec.codename}  --channel ${DebianChannel.lowerName
                                                                                                                                                                                                                                spec.to_channel}"
                  ]
                , label = "Debian: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.Small
                , depends_on = spec.deps
                , if = spec.if
                }

in  { promoteDebianVerificationStep = promoteDebianVerificationStep }
