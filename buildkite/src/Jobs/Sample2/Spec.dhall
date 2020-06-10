let SelectFiles = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = [ SelectFiles.contains "src/lib" ],
  name = "Sample2"
}
