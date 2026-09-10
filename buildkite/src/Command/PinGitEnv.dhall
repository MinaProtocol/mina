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
--       [ PinGitEnv.step stage
--       , Command.build
--           Command.Config::{
--           , depends_on = PinGitEnv.dependsOn jobName stage
--           , ...
--
-- where `stage` is the discriminator described below.
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
-- not this file's. Nothing is passed to the script, so there is no environment
-- to escape and no way for an entrypoint to disagree with another about it.
--
-- The discriminator is the one thing a caller must supply. Buildkite step keys
-- are unique per BUILD, not per upload, and an entrypoint can be uploaded more
-- than once in one build: a release pipeline uploads Prepare.dhall for each of
-- its stages, and the second upload of a constant key is rejected with
--
--   422 The key "_prepare-pin-git-env" has already been used by another step
--
-- which fails the build rather than the step. So pass whatever already makes
-- that entrypoint's own step key unique -- for Prepare.dhall that is the
-- stage's selection, tag filter and scope -- and pass "" only where the
-- entrypoint really is uploaded once per build.
--
-- Running the pin once per stage costs nothing: pin.sh finds the identity the
-- first stage wrote and keeps it.

let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Docker = ./Docker/Type.dhall

let Size = ./Size.dhall

let keyFor
    : Text -> Text
    = \(discriminator : Text) -> "pin-git-env${discriminator}"

let step
    : Text -> Command.Type
    =     \(discriminator : Text)
      ->  Command.build
            Command.Config::{
            , commands = [ Cmd.run "./buildkite/scripts/git-env/pin.sh" ]
            , label = "Pin the git environment"
            , key = keyFor discriminator
            , target = Size.Small
            , docker = None Docker.Type
            }

let dependsOn
    : Text -> Text -> List Command.TaggedKey.Type
    =     \(jobName : Text)
      ->  \(discriminator : Text)
      ->  [ Command.TaggedKey::{ name = jobName, key = keyFor discriminator } ]

in  { keyFor = keyFor, step = step, dependsOn = dependsOn }
