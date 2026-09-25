-- Fix one git identity for a build, before any job that reads one runs.
--
-- Otherwise every job derives GITHASH/GITTAG/GITBRANCH from its own checkout at
-- its own moment: a tag pushed mid-build splits a build's versions, and a job
-- that compiles nothing describes the wrong commit entirely. GITHASH_CONFIG
-- names the genesis config the daemon auto-loads, so that is a broken package,
-- not a mislabelled one.
--
-- Add `step` to an entrypoint's steps and hang the step that uploads or runs
-- everything else off `dependsOn`, making the pin a barrier: nothing able to
-- read the file exists until it has finished.
--
--     , steps =
--       [ PinGitEnv.step stage
--       , Command.build
--           Command.Config::{
--           , depends_on = PinGitEnv.dependsOn jobName stage
--           , ...
--
-- Runs on the agent: the docker plugin has no volumes option, so the pin's
-- /var/storagebox is unreachable from a container. Which identity is pinned is
-- pin.sh's decision, not a caller's -- nothing is passed to it.
--
-- The discriminator keeps the step key unique. Keys are unique per BUILD, and
-- an entrypoint can be uploaded more than once per build (a release pipeline
-- uploads Prepare.dhall per stage), where a constant key 422s and fails the
-- build. Pass whatever already discriminates that entrypoint's own step key,
-- "" only where it really is uploaded once. Repeat pins cost nothing: pin.sh
-- keeps the identity the first one wrote.

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
