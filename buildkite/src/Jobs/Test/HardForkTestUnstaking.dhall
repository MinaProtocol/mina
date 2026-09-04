let HardforkTest = ../../Command/HardForkTest.dhall

in  HardforkTest.pipeline
      "HardForkTestUnstaking"
      "hard fork test - unstaking (legacy mode)"
      "hard-fork-test-unstaking"
      "--fork-from origin/release/mesa --fork-to origin/martyall/unstaking_consensus_v2_hf --slot-tx-end 30 --slot-chain-end 38 --allow-fork-method legacy --unstaking-test --num-lazy-whales 5 --best-chain-query-from 30"
