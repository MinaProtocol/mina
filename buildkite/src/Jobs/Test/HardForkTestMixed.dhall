let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardForkTestMixed"
      "hard fork test - mixed mode"
      "hard-fork-test-mixed"
      "--fork-from origin/compatible --fork-into origin/release/mesa --allow-fork-method legacy --allow-fork-method advanced --allow-fork-method auto"
