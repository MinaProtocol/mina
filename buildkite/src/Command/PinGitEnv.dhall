-- Fix one git identity for a build, before any job that reads one runs.
--
-- Every job that sources export-git-env-vars.sh otherwise derives GITHASH,
-- GITTAG and GITBRANCH for itself, from its own checkout, at its own moment.
-- That is wrong twice over: the answer can change under a running build,
-- because find_most_recent_numeric_tag fetches tags on every call; and for a
-- build that compiles nothing it is an answer about the wrong commit, because
-- such a build wraps binaries an earlier build made. GITHASH_CONFIG is the
-- sharp end -- it names the genesis config the daemon auto-loads -- so getting
-- it from the wrong checkout produces a package holding a config its own
-- daemon will not look for.
--
-- Every pipeline entrypoint needs this, so it lives here rather than being
-- restated in each of them. Add it to an entrypoint's steps and make the step
-- that does the entrypoint's work depend on it, with `dependsOn`.
--
--     , steps =
--       [ PinGitEnv.step
--       , Command.build
--           Command.Config::{
--           , depends_on = PinGitEnv.dependsOn jobName
--           , ...
--
-- The depended-on step is always the one that uploads or runs everything else,
-- which is what makes this a barrier rather than an ordering to reason about:
-- nothing that could read the file exists until the pin has finished.
--
-- It runs on the agent, not in a container. The steps it usually sits beside
-- run in toolchainBase, and the buildkite docker plugin has no volumes option,
-- so /var/storagebox -- where the pin is written -- is not reachable from
-- inside one.
--
-- Which identity gets pinned is buildkite/scripts/git-env/pin.sh's decision,
-- not this file's. Nothing is passed here, so there is no environment to
-- escape and no way for an entrypoint to disagree with another about it.

let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Docker = ./Docker/Type.dhall

let Size = ./Size.dhall

let key = "pin-git-env"

let step
    : Command.Type
    = Command.build
        Command.Config::{
        , commands = [ Cmd.run "./buildkite/scripts/git-env/pin.sh" ]
        , label = "Pin the git environment"
        , key = key
        , target = Size.Small
        , docker = None Docker.Type
        }

let dependsOn
    : Text -> List Command.TaggedKey.Type
    = \(jobName : Text) -> [ Command.TaggedKey::{ name = jobName, key = key } ]

in  { key = key, step = step, dependsOn = dependsOn }
