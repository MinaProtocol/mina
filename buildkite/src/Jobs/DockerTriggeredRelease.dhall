let S = ../Lib/SelectFiles.dhall

let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ../Command/Size.dhall
let DockerArtifact = ../Command/DockerArtifact.dhall

in

Pipeline.build
  Pipeline.Config::{
      spec =
        JobSpec::{
            dirtyWhen = [
                S.strictlyStart (S.contains "buildkite/DOCKER_DEPLOY_ENV")
            ],
            name = "DockerTriggeredRelease"
        },
    steps = [
      -- TODO: add step to render DOCKER_DEPLOY_ENV locally or download artifact from triggered build
      DockerArtifact.step
    ]
  }
