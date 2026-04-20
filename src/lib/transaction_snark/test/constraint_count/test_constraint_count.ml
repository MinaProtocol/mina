(** Test to verify the constraint counts, public input sizes, auxiliary
    input sizes, and digests of transaction SNARK circuits.

    Each circuit is tested by creating its constraint system once and
    checking all expected values.

    The transaction SNARK has 5 rules:
    1. Base ("transaction") - Single non-zkApp transaction
    2. Merge ("merge") - Combines two proofs
    3. ZkApp Opt_signed_opt_signed - 2 optional signatures
    4. ZkApp Opt_signed - 1 optional signature
    5. ZkApp Proved - Side-loaded proof

    In production, these 5 circuits are compiled together via [Pickles.compile]
    in [Transaction_snark.system]. The test helpers here use [Tick.constraint_system]
    to extract each circuit's constraint system individually, which produces the
    same constraints as the production compilation.

    This is useful for:
    - Tracking constraint count changes over time
    - Comparing with a Rust reimplementation
    - Performance analysis

    IMPORTANT: If these tests fail due to changed constraint counts, public
    input sizes, auxiliary input sizes, or digests, update the expected values
    below AND the table in [transaction_snark_intf.ml] to keep the documentation
    in sync.

    NOTE: Expected values vary by profile (dev, devnet, lightnet, mainnet) as
    constraint counts depend on configuration parameters like ledger depth. *)

open Core_kernel

(** Expected values for a single circuit *)
type circuit_stats =
  { constraints : int
  ; public_input_size : int
  ; auxiliary_input_size : int
  ; digest : string
  }

(** Expected values for all circuits in a profile *)
type profile_expected_values =
  { transaction_merge : circuit_stats
  ; transaction_base : circuit_stats
  ; zkapp_opt_signed_opt_signed : circuit_stats
  ; zkapp_opt_signed : circuit_stats
  ; zkapp_proved : circuit_stats
  }

let dev_expected_values =
  { transaction_merge =
      { constraints = 675
      ; public_input_size = 306
      ; auxiliary_input_size = 2308
      ; digest = "420ce313349d3c356d63ae6f5eba51b1"
      }
  ; transaction_base =
      { constraints = 12927
      ; public_input_size = 306
      ; auxiliary_input_size = 37996
      ; digest = "de2a8bc41f043ef6522b3134603cc528"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16354
      ; public_input_size = 306
      ; auxiliary_input_size = 73995
      ; digest = "6efa1681905a0542275dccbf0fadcafc"
      }
  ; zkapp_opt_signed =
      { constraints = 8959
      ; public_input_size = 306
      ; auxiliary_input_size = 41114
      ; digest = "6a968dc148e6800c1a75c3dd6c0c4c54"
      }
  ; zkapp_proved =
      { constraints = 5181
      ; public_input_size = 306
      ; auxiliary_input_size = 39680
      ; digest = "513c09bcc4bb341040c03966579b73ad"
      }
  }

let devnet_expected_values =
  { transaction_merge =
      { constraints = 675
      ; public_input_size = 306
      ; auxiliary_input_size = 2308
      ; digest = "420ce313349d3c356d63ae6f5eba51b1"
      }
  ; transaction_base =
      { constraints = 15397
      ; public_input_size = 306
      ; auxiliary_input_size = 64131
      ; digest = "4373faf136fe1e77edf3ca835ba004eb"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18011
      ; public_input_size = 306
      ; auxiliary_input_size = 91480
      ; digest = "7d3f388fe3d15c9d57c61011f1453262"
      }
  ; zkapp_opt_signed =
      { constraints = 9804
      ; public_input_size = 306
      ; auxiliary_input_size = 49949
      ; digest = "e7988713642a78bfc3906bf80925b02f"
      }
  ; zkapp_proved =
      { constraints = 6026
      ; public_input_size = 306
      ; auxiliary_input_size = 48515
      ; digest = "85551499fff6ba3010ad8b862d5878aa"
      }
  }

let lightnet_expected_values =
  { transaction_merge =
      { constraints = 675
      ; public_input_size = 306
      ; auxiliary_input_size = 2308
      ; digest = "420ce313349d3c356d63ae6f5eba51b1"
      }
  ; transaction_base =
      { constraints = 15397
      ; public_input_size = 306
      ; auxiliary_input_size = 64131
      ; digest = "4373faf136fe1e77edf3ca835ba004eb"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18011
      ; public_input_size = 306
      ; auxiliary_input_size = 91480
      ; digest = "7d3f388fe3d15c9d57c61011f1453262"
      }
  ; zkapp_opt_signed =
      { constraints = 9804
      ; public_input_size = 306
      ; auxiliary_input_size = 49949
      ; digest = "e7988713642a78bfc3906bf80925b02f"
      }
  ; zkapp_proved =
      { constraints = 6026
      ; public_input_size = 306
      ; auxiliary_input_size = 48515
      ; digest = "85551499fff6ba3010ad8b862d5878aa"
      }
  }

let mainnet_expected_values =
  { transaction_merge =
      { constraints = 675
      ; public_input_size = 306
      ; auxiliary_input_size = 2308
      ; digest = "420ce313349d3c356d63ae6f5eba51b1"
      }
  ; transaction_base =
      { constraints = 15397
      ; public_input_size = 306
      ; auxiliary_input_size = 64131
      ; digest = "a31ad13ac2e1cff79eeed393aa72ac0b"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18011
      ; public_input_size = 306
      ; auxiliary_input_size = 91480
      ; digest = "616bd439347bbbb0e095396b1ffa2a18"
      }
  ; zkapp_opt_signed =
      { constraints = 9804
      ; public_input_size = 306
      ; auxiliary_input_size = 49949
      ; digest = "80b1a205bb4a3b96b35be91a3980b287"
      }
  ; zkapp_proved =
      { constraints = 6026
      ; public_input_size = 306
      ; auxiliary_input_size = 48515
      ; digest = "a45643d7a6a98a78fea05870a7de696a"
      }
  }

let expected_values =
  match Node_config.profile with
  | "dev" ->
      dev_expected_values
  | "devnet" ->
      devnet_expected_values
  | "lightnet" ->
      lightnet_expected_values
  | "mainnet" ->
      mainnet_expected_values
  | p ->
      failwithf "Unknown profile: %s" p ()

(** Helper to check all circuit stats at once *)
let check_circuit_stats ~name ~expected cs =
  let actual_constraints =
    Snark_params.Tick.R1CS_constraint_system.get_rows_len cs
  in
  let actual_public_input_size =
    Set_once.get_exn
      (Snark_params.Tick.R1CS_constraint_system.get_public_input_size cs)
      [%here]
  in
  let actual_auxiliary_input_size =
    Set_once.get_exn
      (Snark_params.Tick.R1CS_constraint_system.get_auxiliary_input_size cs)
      [%here]
  in
  let actual_digest =
    Md5_lib.to_hex (Snark_params.Tick.R1CS_constraint_system.digest cs)
  in
  Alcotest.(check int)
    (Printf.sprintf "%s constraint count" name)
    expected.constraints actual_constraints ;
  Alcotest.(check int)
    (Printf.sprintf "%s public input size" name)
    expected.public_input_size actual_public_input_size ;
  Alcotest.(check int)
    (Printf.sprintf "%s auxiliary input size" name)
    expected.auxiliary_input_size actual_auxiliary_input_size ;
  Alcotest.(check string)
    (Printf.sprintf "%s digest" name)
    expected.digest actual_digest

(** Test transaction-merge circuit *)
let test_transaction_merge () =
  let cs = Transaction_snark.merge_constraint_system () in
  check_circuit_stats ~name:"transaction-merge"
    ~expected:expected_values.transaction_merge cs

(** Test transaction-base circuit *)
let test_transaction_base () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.base_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"transaction-base"
    ~expected:expected_values.transaction_base cs

(** Test zkapp-opt_signed-opt_signed circuit *)
let test_zkapp_opt_signed_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_opt_signed_constraint_system
      ~signature_kind ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed-opt_signed"
    ~expected:expected_values.zkapp_opt_signed_opt_signed cs

(** Test zkapp-opt_signed circuit *)
let test_zkapp_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed"
    ~expected:expected_values.zkapp_opt_signed cs

(** Test zkapp-proved circuit *)
let test_zkapp_proved () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.zkapp_proved_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-proved"
    ~expected:expected_values.zkapp_proved cs

let () =
  let open Alcotest in
  run "Transaction Snark Circuit Stats"
    [ ("transaction-merge", [ test_case "stats" `Slow test_transaction_merge ])
    ; ("transaction-base", [ test_case "stats" `Slow test_transaction_base ])
    ; ( "zkapp-opt_signed-opt_signed"
      , [ test_case "stats" `Slow test_zkapp_opt_signed_opt_signed ] )
    ; ("zkapp-opt_signed", [ test_case "stats" `Slow test_zkapp_opt_signed ])
    ; ("zkapp-proved", [ test_case "stats" `Slow test_zkapp_proved ])
    ]
