let S = ../Lib/SelectFiles.dhall

let testOnly =
    -- Folders holding only tests of CI/packaging scripts. Jobs whose dirtyWhen
    -- has a broad prefix over them (scripts/debian, scripts/docker, ...) put
    -- this in dirtyWhenExcept, so editing a script test runs only its own job.
      [ S.strictlyStart (S.contains "scripts/debian/tests")
      , S.strictlyStart (S.contains "scripts/debian/session/tests")
      , S.strictlyStart (S.contains "scripts/docker/tests")
      , S.strictlyStart (S.contains "scripts/hardfork/release/tests")
      , S.strictlyStart (S.contains "buildkite/scripts/docker/tests")
      , S.strictlyStart (S.contains "buildkite/scripts/cache/tests")
      , S.strictlyStart (S.contains "buildkite/scripts/pipeline/tests")
      , S.strictlyStart (S.contains "buildkite/scripts/tests/release-manager")
      ]

in  { testOnly = testOnly }
