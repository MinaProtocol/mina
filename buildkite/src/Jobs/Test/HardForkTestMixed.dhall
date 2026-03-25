let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardForkTestMixed"
      "hard fork test - mixed mode"
      "hard-fork-test-mixed"
      "--fork-from origin/compatible --allow-fork-method legacy --allow-fork-method advanced"
