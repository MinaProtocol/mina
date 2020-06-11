let S = ../../../Lib/SelectFiles.dhall
let D = S.PathPattern

let JobSpec = ../../../Pipeline/JobSpec.dhall

in

JobSpec::{
  dirtyWhen = [
    S::{ dir = Some [D.Lit "src/nonconsensus", D.Any], exts = Some ["ml"] },
    S.contains "Makefile",
    S.exactly "scripts/link-coredumps" "sh"
  ],
  path = "Unit",
  name = "UnitTestNonconsensus"
}
