let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardforkTestLegacy"
      "hard fork test - legacy mode"
      "hard-fork-test-legacy"
      "--fork-from origin/master"
