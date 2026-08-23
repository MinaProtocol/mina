-- Refuse to release a commit that is not tagged.
--
-- A release version is read from the repository, never asserted. The check
-- is a job of its own, and scoped to Release, for three reasons:
--
--  * It fails in seconds. Discovering an untagged commit inside a packaging
--    job means discovering it forty minutes in, after the apps build.
--  * The policy is declared here rather than carried in an environment
--    variable that every job would have to be given. A pipeline either runs
--    this job or it does not.
--  * scripts/export-git-env-vars.sh stays a script about git facts and the
--    version derived from them. Enforcement lives with the pipeline that
--    wants it.
--
-- dirtyWhen is deliberately `everything`: this is not a reaction to a change
-- in some file, it is a precondition of the pipeline it belongs to. Scope
-- keeps it out of every other pipeline.

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "ReleaseCommit"
        , scope = [ PipelineScope.Type.Release ]
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Release ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = [ Cmd.run "./scripts/verify/release-commit.sh" ]
            , label = "Release: verify the commit is tagged"
            , key = "verify-release-commit"
            , target = Size.Small
            }
        ]
      }
