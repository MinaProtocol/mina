let B = ../../External/Buildkite.dhall
let Prelude = ../../External/Prelude.dhall
let List/map = Prelude.List.map

let PromotePackage = ../../Command/PromotePackage.dhall
let Package =  ../../Constants/DebianPackage.dhall
let Artifact =  ../../Constants/Artifacts.dhall
let DebianChannel = ../../Constants/DebianChannel.dhall
let DebianVersions = ../../Constants/DebianVersions.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall

let promote_artifacts = 
  \(debians: List Package.Type) ->
  \(dockers: List Artifact.Type) ->
  \(version: Text ) ->
  \(architecture: Text ) ->
  \(codename: DebianVersions.DebVersion ) ->
  \(from_channel: DebianChannel.Type ) ->
  \(to_channel: DebianChannel.Type ) ->
  \(tag: Text ) ->

  let debians_spec =
      List/map 
      Package.Type
      PromotePackage.PromoteDebianSpec.Type
      (\(debian: Package.Type) -> PromotePackage.PromoteDebianSpec::{
            , package = debian
            , version = version
            , architecture = architecture
            , codename = codename
            , from_channel = from_channel
            , to_channel = to_channel
            , step_key = "promote-debian-${Package.lowerName debian}-from-${DebianChannel.lowerName from_channel}-to-${DebianChannel.lowerName to_channel}"
      })   
      debians
  in
  let dockers_spec = 
      List/map 
      Artifact.Type
      PromotePackage.PromoteDockerSpec.Type
        (\(docker: Artifact.Type) -> PromotePackage.PromoteDockerSpec::{
          , name = docker
          , version = version
          , new_tag = tag
          , step_key = "add-tag-${tag}-to-${Artifact.lowerName docker}-docker"
        })
      dockers
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