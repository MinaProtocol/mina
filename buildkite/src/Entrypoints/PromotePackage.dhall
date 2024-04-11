let B = ../External/Buildkite.dhall
let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let PromotePackage = ../Command/PromotePackage.dhall
let Package =  ../Constants/DebianPackage.dhall
let Profile =  ../Constants/Profiles.dhall
let Artifact =  ../Constants/Artifacts.dhall
let DebianChannel = ../Constants/DebianChannel.dhall
let DebianVersions = ../Constants/DebianVersions.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let PipelineMode = ../Pipeline/Mode.dhall

let promote_artifacts = 
  \(debians: List Package.Type) ->
  \(dockers: List Artifact.Type) ->
  \(version: Text ) ->
  \(new_version: Text ) ->
  \(architecture: Text ) ->
  \(profile: Profile.Type) ->
  \(codenames: List DebianVersions.DebVersion ) ->
  \(from_channel: DebianChannel.Type ) ->
  \(to_channel: DebianChannel.Type ) ->
  \(tag: Text ) ->

  let debians_spec =
      List/map 
      Package.Type
      (List PromotePackage.PromoteDebianSpec.Type)
      (\(debian: Package.Type) -> 
        List/map
        DebianVersions.DebVersion
        PromotePackage.PromoteDebianSpec.Type
        (\(codename: DebianVersions.DebVersion) -> 
          PromotePackage.PromoteDebianSpec::{
            profile = profile
            , package = debian
            , version = version
            , new_version = new_version
            , architecture = architecture
            , codename = codename
            , from_channel = from_channel
            , to_channel = to_channel
            , step_key = "promote-debian-${Package.lowerName debian}-from-${DebianChannel.lowerName from_channel}-to-${DebianChannel.lowerName to_channel}"
          }
        )
        codenames
        
      )
      debians
  in 

  let debians_spec = 
      Prelude.List.fold
        (List PromotePackage.PromoteDebianSpec.Type)
        debians_spec
        (List PromotePackage.PromoteDebianSpec.Type)
        (\(a : List PromotePackage.PromoteDebianSpec.Type) -> \(b : List PromotePackage.PromoteDebianSpec.Type) -> a # b)
        ([] : List PromotePackage.PromoteDebianSpec.Type)

  in

  let dockers_spec = 
      List/map 
      Artifact.Type
      (List PromotePackage.PromoteDockerSpec.Type)
      (\(docker: Artifact.Type) -> 
        List/map
        DebianVersions.DebVersion
        PromotePackage.PromoteDockerSpec.Type
        (\(codename: DebianVersions.DebVersion) -> 
          PromotePackage.PromoteDockerSpec::{
              profile = profile
              , name = docker
              , version = version
              , codename = codename
              , new_tag = new_version
              , step_key = "add-tag-to-${Artifact.lowerName docker}-docker"
          }
        )
        codenames
      )
      dockers

  in

  let dockers_spec = 
      Prelude.List.fold
        (List PromotePackage.PromoteDockerSpec.Type)
        dockers_spec
        (List PromotePackage.PromoteDockerSpec.Type)
        (\(a : List PromotePackage.PromoteDockerSpec.Type) -> \(b : List PromotePackage.PromoteDockerSpec.Type) -> a # b)
        ([] : List PromotePackage.PromoteDockerSpec.Type)

  in

  let pipelineType = Pipeline.build 
    (
      PromotePackage.pipeline 
          (debians_spec)
          (dockers_spec)
          (DebianVersions.DebVersion.Bullseye)
          (PipelineMode.Type.Stable)
    )
  in pipelineType.pipeline

in {
  promote_artifacts = promote_artifacts
}