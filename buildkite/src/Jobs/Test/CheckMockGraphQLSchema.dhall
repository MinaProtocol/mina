let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let CheckMockGraphQLSchema = ../../Command/CheckMockGraphQLSchema.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let dependsOn = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart
              (S.contains "src/test/daemon/graphql_mock")
          , S.exactly
              "buildkite/scripts/check-mock-graphql-schema"
              "sh"
          , S.exactly
              "scripts/check-mock-schema-subset"
              "py"
          , S.strictly (S.contains "Makefile")
          , S.strictly
              (S.contains
                 "src/lib/graphql/mina_graphql")
          ]
        , path = "Test"
        , name = "CheckMockGraphQLSchema"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ CheckMockGraphQLSchema.step dependsOn ]
      }
