let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "src/lib/crypto/proof-systems"
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Lint/ProofSystemsAudit")
          ]
        , path = "Lint"
        , name = "ProofSystemsAudit"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Lint
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "cd src/lib/crypto/proof-systems ; export PATH=/home/opam/.cargo/bin:\$PATH ; cargo install cargo-audit --locked ; cargo audit"
            , label = "Rust proof system ; audit"
            , key = "proof-system-audit"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
