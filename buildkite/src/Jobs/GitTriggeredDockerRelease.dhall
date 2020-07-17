let S = ../Lib/SelectFiles.dhall

let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

let Cmd = ../Lib/Cmds.dhall

let Command = ../Command/Base.dhall
let Size = ../Command/Size.dhall
let DockerArtifact = ../Command/DockerArtifact.dhall

let uploadDeployEnv =
  Command.build
    Command.Config::{
      commands = [ Cmd.run "cd buildkite && buildkite-agent artifact upload DOCKER_DEPLOY_ENV" ],
      label = "Upload deploy environment",
      key = "artifact-upload",
      target = Size.Small
    }

let dependsOn = [ { name = "GitTriggeredDockerRelease", key = "artifact-upload" } ]

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
          dirtyWhen = [
              S.strictlyStart (S.contains "buildkite/DOCKER_DEPLOY_ENV")
          ],
          name = "GitTriggeredDockerRelease"
      },
    steps = [
      uploadDeployEnv,
      DockerArtifact.generateStep dependsOn
    ]
  }
