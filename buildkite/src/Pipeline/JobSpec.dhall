let SelectFiles = ../Lib/SelectFiles.dhall
in

-- Defines info used for selecting a job to run
-- path is relative to `src/jobs/`
{
  Type = {
    path: Text,
    name: Text,
    dirtyWhen: List SelectFiles.Type
  },
  default = {
    path = "."
  }
}
