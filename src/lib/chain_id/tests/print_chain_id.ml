(** Print a chain ID for the current profile.

    This is used to generate reference chain ID files for each profile. The
    constants and circuits are those of the profile, and the genesis ledger is
    the fixed unit test ledger, so this is not the chain ID of a real network.
    It still changes whenever the circuits, the constants or the protocol
    version do. *)

open Core_kernel

let () =
  Format.eprintf "Profile: %s@." Node_config.profile ;
  let (module G) = Genesis_constants.profiled () in
  let constraint_system_digests =
    Genesis_proof.constraint_system_digests
      ~signature_kind:Mina_signature_kind.t_DEPRECATED
      ~constraint_constants:G.constraint_constants
      ~proof_level:Genesis_constants.Proof_level.Full
  in
  Chain_id.make ~genesis_constants:G.genesis_constants
    ~constraint_constants:G.constraint_constants
    ~genesis_ledger:
      (Consensus.Genesis_data.Ledger.to_hashed Genesis_ledger.for_unit_tests)
    ~genesis_epoch_data:
      (Consensus.Genesis_data.Epoch.to_hashed
         Consensus.Genesis_data.Epoch.for_unit_tests )
    ~constraint_system_digests
  |> Lazy.force |> Chain_id.to_string |> print_endline
