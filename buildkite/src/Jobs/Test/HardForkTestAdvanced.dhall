let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardforkTestAdvanced"
      "hard fork test - advanced mode"
      "hard-fork-test-advanced"
      "--fork-from origin/compatible --fork-method advanced"
