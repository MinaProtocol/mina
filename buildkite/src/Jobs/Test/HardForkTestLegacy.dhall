let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardForkTestLegacy"
      "hard fork test - legacy mode"
      "hard-fork-test-legacy"
      "--fork-from origin/master --fork-into origin/release/mesa --allow-fork-method legacy"
