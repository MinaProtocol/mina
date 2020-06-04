-- Defines info used for selecting a job to run
-- path is relative to `src/jobs/`
{
  Type = {
    path: Text,
    name: Text,
    dirtyWhen: Text
  },
  default = {
    path = "."
  }
}
