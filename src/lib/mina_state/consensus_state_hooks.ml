include
  Consensus.Hooks.Make_state_hooks
    (Blockchain_state)
    (struct
      include Protocol_state

      let hash t = (hashes t).state_hash
    end)
    (Snark_transition)
