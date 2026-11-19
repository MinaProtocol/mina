-- The folder segment that keeps one build variant's artifacts apart from
-- another's in the CI cache: empty for a standard amd64 build, else
-- "instrumented", "arm64" or "instrumented-arm64".

let BuildFlags = ./BuildFlags.dhall

let Arch = ./Arch.dhall

let segment
    : BuildFlags.Type -> Arch.Type -> Text
    =     \(buildFlags : BuildFlags.Type)
      ->  \(arch : Arch.Type)
      ->  merge
            { None = merge { Amd64 = "", Arm64 = "arm64" } arch
            , Instrumented =
                merge
                  { Amd64 = "instrumented", Arm64 = "instrumented-arm64" }
                  arch
            }
            buildFlags

let test_standard = assert : "" === segment BuildFlags.Type.None Arch.Type.Amd64

let test_arm64 =
      assert : "arm64" === segment BuildFlags.Type.None Arch.Type.Arm64

let test_instrumented =
        assert
      : "instrumented" === segment BuildFlags.Type.Instrumented Arch.Type.Amd64

let test_instrumented_arm64 =
        assert
      :     "instrumented-arm64"
        ===  segment BuildFlags.Type.Instrumented Arch.Type.Arm64

in  { segment = segment }
