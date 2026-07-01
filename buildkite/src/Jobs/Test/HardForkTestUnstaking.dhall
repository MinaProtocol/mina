let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardForkTestUnstaking"
      "hard fork test - unstaking (legacy mode)"
      "hard-fork-test-unstaking"
      "--fork-from origin/restake-prefork-patch --fork-to origin/lyh/restake-postfork-feat --allow-fork-method legacy --unstaking-test --inactive-stake-portion 0.5 --num-dormant-whales 3"
