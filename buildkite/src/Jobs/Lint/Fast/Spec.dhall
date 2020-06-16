let SelectFiles = ../../../Lib/SelectFiles.dhall

let JobSpec = ../../../Pipeline/JobSpec.dhall

in

JobSpec::{
  dirtyWhen = [ SelectFiles.everything ],
  path = "Lint",
  name = "Fast"
}
