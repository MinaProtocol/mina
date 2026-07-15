let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardForkTestLegacy"
      "hard fork test - legacy mode"
      "hard-fork-test-legacy"
      "--fork-from origin/master --fork-into lyh/runtime-genesis-ledger-restore-hf-slot --allow-fork-method legacy"
