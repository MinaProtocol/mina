-- let Prelude = ../../External/Prelude.dhall

-- CI step is being disabled, as it is not functional and can allow broken chart pushes
-- the connected helm-ci.sh script does not test chart/node functionality

-- let S = ../../Lib/SelectFiles.dhall
-- let Cmd = ../../Lib/Cmds.dhall

-- let Pipeline = ../../Pipeline/Dsl.dhall
-- let JobSpec = ../../Pipeline/JobSpec.dhall

-- let Command = ../../Command/Base.dhall
-- let Docker = ../../Command/Docker/Type.dhall
-- let Size = ../../Command/Size.dhall

-- in

-- Pipeline.build
--   Pipeline.Config::{
--     spec = JobSpec::{
--       dirtyWhen = [
--         S.strictlyEnd (S.contains "Chart.yaml"),
--         S.strictlyStart (S.contains "buildkite/src/Jobs/Release/HelmRelease"),
--         S.exactly "buildkite/scripts/helm-ci" "sh"
--       ],
--       path = "Release",
--       name = "HelmRelease"
--     },
--     steps = [
--       Command.build
--         Command.Config::{
--           commands = [ Cmd.run "HELM_RELEASE=true AUTO_DEPLOY=true buildkite/scripts/helm-ci.sh" ]
--           , label = "Helm chart release"
--           , key = "release-helm-chart"
--           , target = Size.Medium
--           , docker = None Docker.Type
--           , artifact_paths = [ S.contains "updates/*" ]
--           , depends_on = [ { name = "HelmChart", key = "lint-helm-chart" } ]
--         }
--     ]
--   }
