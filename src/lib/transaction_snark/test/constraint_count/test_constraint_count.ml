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
    below for every profile. The actual values are logged by each test, and
    CI runs the devnet and mainnet profiles via
    [buildkite/scripts/profile-dependent-tests.sh].

    NOTE: Expected values vary by profile (dev, devnet, lightnet, mainnet) as
    constraint counts depend on configuration parameters like ledger depth. *)

open Core

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
      { constraints = 634
      ; public_input_size = 300
      ; auxiliary_input_size = 1899
      ; digest = "d71089b3a1669535999e8f181cd59afc"
      }
  ; transaction_base =
      { constraints = 12879
      ; public_input_size = 300
      ; auxiliary_input_size = 37508
      ; digest = "1dfb98ac348b112fd877a935e93de981"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16324
      ; public_input_size = 300
      ; auxiliary_input_size = 73519
      ; digest = "d9e8966a3a605b2011f669a2d6ee4836"
      }
  ; zkapp_opt_signed =
      { constraints = 8920
      ; public_input_size = 300
      ; auxiliary_input_size = 40632
      ; digest = "93113e36b8e9153aae70da22e957a6fd"
      }
  ; zkapp_proved =
      { constraints = 5142
      ; public_input_size = 300
      ; auxiliary_input_size = 39198
      ; digest = "f5b4de07d8b8fdd2f5ec9f730138b2aa"
      }
  }

let devnet_expected_values =
  { transaction_merge =
      { constraints = 634
      ; public_input_size = 300
      ; auxiliary_input_size = 1899
      ; digest = "d71089b3a1669535999e8f181cd59afc"
      }
  ; transaction_base =
      { constraints = 15361
      ; public_input_size = 300
      ; auxiliary_input_size = 63812
      ; digest = "d333a8775f3933ee95a8479ada9a4c6d"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17993
      ; public_input_size = 300
      ; auxiliary_input_size = 91173
      ; digest = "0e6e81faab4ed4f4777671066d3740a3"
      }
  ; zkapp_opt_signed =
      { constraints = 9777
      ; public_input_size = 300
      ; auxiliary_input_size = 49636
      ; digest = "35639f0d40887d49bdc02f995ef76f58"
      }
  ; zkapp_proved =
      { constraints = 5999
      ; public_input_size = 300
      ; auxiliary_input_size = 48202
      ; digest = "03d75c911e20c6203a3a37f54b6f3cba"
      }
  }

let lightnet_expected_values =
  { transaction_merge =
      { constraints = 634
      ; public_input_size = 300
      ; auxiliary_input_size = 1899
      ; digest = "d71089b3a1669535999e8f181cd59afc"
      }
  ; transaction_base =
      { constraints = 15361
      ; public_input_size = 300
      ; auxiliary_input_size = 63812
      ; digest = "d333a8775f3933ee95a8479ada9a4c6d"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17993
      ; public_input_size = 300
      ; auxiliary_input_size = 91173
      ; digest = "0e6e81faab4ed4f4777671066d3740a3"
      }
  ; zkapp_opt_signed =
      { constraints = 9777
      ; public_input_size = 300
      ; auxiliary_input_size = 49636
      ; digest = "35639f0d40887d49bdc02f995ef76f58"
      }
  ; zkapp_proved =
      { constraints = 5999
      ; public_input_size = 300
      ; auxiliary_input_size = 48202
      ; digest = "03d75c911e20c6203a3a37f54b6f3cba"
      }
  }

let mainnet_expected_values =
  { transaction_merge =
      { constraints = 634
      ; public_input_size = 300
      ; auxiliary_input_size = 1899
      ; digest = "d71089b3a1669535999e8f181cd59afc"
      }
  ; transaction_base =
      { constraints = 15361
      ; public_input_size = 300
      ; auxiliary_input_size = 63812
      ; digest = "73c5b4e21f6175030826168835add14f"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17993
      ; public_input_size = 300
      ; auxiliary_input_size = 91173
      ; digest = "ffae4f687a4531bb0518732f3331759d"
      }
  ; zkapp_opt_signed =
      { constraints = 9777
      ; public_input_size = 300
      ; auxiliary_input_size = 49636
      ; digest = "358da7db5ba29ce6a60661ce9b780477"
      }
  ; zkapp_proved =
      { constraints = 5999
      ; public_input_size = 300
      ; auxiliary_input_size = 48202
      ; digest = "df4d8b9d39314226692d92eacd8cbe8f"
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
  (* Always log the actual values: on failure Alcotest shows this captured
     output, so all four values can be updated from a single run. *)
  Printf.eprintf
    "%s: constraints=%d public_input_size=%d auxiliary_input_size=%d digest=%s\n\
     %!"
    name actual_constraints actual_public_input_size actual_auxiliary_input_size
    actual_digest ;
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
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.base_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"transaction-base"
    ~expected:expected_values.transaction_base cs

(** Test zkapp-opt_signed-opt_signed circuit *)
let test_zkapp_opt_signed_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_opt_signed_constraint_system
      ~signature_kind ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed-opt_signed"
    ~expected:expected_values.zkapp_opt_signed_opt_signed cs

(** Test zkapp-opt_signed circuit *)
let test_zkapp_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed"
    ~expected:expected_values.zkapp_opt_signed cs

(** Test zkapp-proved circuit *)
let test_zkapp_proved () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in

  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
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
